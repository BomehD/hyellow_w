/* eslint-disable max-len */
import {onCall} from "firebase-functions/v2/https";
import {initializeApp} from "firebase-admin/app";
import {GoogleGenerativeAI, Content, Part} from "@google/generative-ai";
import axios from "axios";
import * as functions from "firebase-functions"; // Import the functions library

initializeApp();

// Ensure the API key is correctly set as a Cloud Function environment variable
const GEMINI_API_KEY = process.env.GEMINI_API_KEY as string;

// The onCall function does not need secrets since we are using the older config system
export const generateAiResponse = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("UNAUTHENTICATED");
  }

  const {context, messages, userRequest} = request.data as {
    context: string;
    messages: { text: string; isUser: boolean; }[];
    userRequest: string;
  };

  if (!context || !messages || !userRequest) {
    throw new Error("Invalid arguments, 'context', 'messages', and 'userRequest' are required.");
  }

  // Define an interface for the expected data structure from the SerpApi response
  interface SerpApiResponse {
    knowledge_graph?: {
      title: string;
      description: string;
    };
    organic_results?: {
      snippet: string;
    }[];
  }

  let liveFact = "";

  try {
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({model: "gemini-3-flash-preview"});

    // --- STEP 1: Use the AI to classify the user's intent with generateContent ---
    const classificationPrompt = `Analyze the user's query and determine if it requires a real-time search for up-to-date information (e.g., current events, weather, a person's current status). Respond with only "YES" or "NO". Do not add any other text.
    Query: ${userRequest}`;

    const classificationResult = await model.generateContent(classificationPrompt);
    const requiresSearch = classificationResult.response.text().trim().toUpperCase() === "YES";

    // --- STEP 2: Conditionally perform the search and get a dynamic search query ---
    if (requiresSearch) {
      const queryGenerationPrompt = `Generate the single best search query for the following user request. Only provide the search query, with no other text.
      User's query: ${userRequest}`;

      const queryGenerationResult = await model.generateContent(queryGenerationPrompt);
      const searchQuery = queryGenerationResult.response.text().trim();

      try {
        const serpApiKey = functions.config().serpapi.key; // The correct way to read the key from the old system
        if (!serpApiKey) {
          console.error("SerpApi key is not configured.");
        } else {
          const response = await axios.get("https://serpapi.com/search.json", {
            params: {
              engine: "google_search",
              q: searchQuery,
              api_key: serpApiKey,
            },
          });

          const data = response.data as SerpApiResponse;

          const knowledgeGraph = data.knowledge_graph;
          if (knowledgeGraph && knowledgeGraph.title && knowledgeGraph.description) {
            liveFact = `\n\nHere is an up-to-date fact from a search: ${knowledgeGraph.title}, as stated in the following summary: "${knowledgeGraph.description}".`;
          } else if (data.organic_results && data.organic_results.length > 0) {
            const firstResult = data.organic_results[0];
            liveFact = `\n\nHere is an up-to-date fact from a recent search: "${firstResult.snippet}".`;
          }
        }
      } catch (error) {
        console.error("Failed to fetch live data:", error);
      }
    }

    // --- STEP 3: Combine everything and send to the AI for the final response ---
    const fullPrompt = `${context}${liveFact}\n\nUser Request: ${userRequest}`;

    const history: Content[] = messages.map((msg) => ({
      role: msg.isUser ? "user" : "model",
      parts: [{text: msg.text} as Part],
    }));

    const chat = model.startChat({
      history: history,
      generationConfig: {
        responseMimeType: "text/plain",
      },
    });

    const result = await chat.sendMessage(fullPrompt);
    const apiResponse = result.response;
    const text = apiResponse.text();

    return {response: text};
  } catch (error) {
    console.error("Error generating content:", error);
    if (error instanceof Error) {
      throw new Error(`An error occurred: ${error.message}`);
    }
    throw new Error("An unknown error occurred while generating content.");
  }
});
