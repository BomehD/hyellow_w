/* eslint-disable max-len */
import {onCall, HttpsError} from "firebase-functions/v2/https"; // Added HttpsError
import {defineSecret} from "firebase-functions/params"; // Added Secret Manager support
import {initializeApp} from "firebase-admin/app";
import {GoogleGenerativeAI, Content, Part} from "@google/generative-ai";
import axios from "axios";
import * as functions from "firebase-functions";

initializeApp();

// 1. Properly define the Secret reference
// Change the variable name to something unique like 'GEMINI_SECRET'
const GEMINI_SECRET = defineSecret("GEMINI_API_KEY");

export const generateAiResponse = onCall({
  secrets: [GEMINI_SECRET], // Use the new variable name here
  region: "us-central1",
}, async (request) => {
  const apiKey = GEMINI_SECRET.value();
  // Use HttpsError so Flutter gets a clean error code
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be signed in.");
  }

  const {context, messages, userRequest} = request.data as {
    context: string;
    messages: { text: string; isUser: boolean; }[];
    userRequest: string;
  };

  if (!context || !messages || !userRequest) {
    throw new HttpsError("invalid-argument", "Missing context, messages, or userRequest.");
  }

  interface SerpApiResponse {
    knowledge_graph?: { title: string; description: string; };
    organic_results?: { snippet: string; }[];
  }

  let liveFact = "";

  try {
    // 3. Access the secret value inside the handler
    const apiKey = GEMINI_API_KEY.value();
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({model: "gemini-3-flash-preview"});

    // --- STEP 1: Classification ---
    const classificationPrompt = `Analyze the user's query and determine if it requires a real-time search... Query: ${userRequest}`;
    const classificationResult = await model.generateContent(classificationPrompt);
    const requiresSearch = classificationResult.response.text().trim().toUpperCase() === "YES";

    // --- STEP 2: Search ---
    if (requiresSearch) {
      const queryGenerationPrompt = `Generate the single best search query... User's query: ${userRequest}`;
      const queryGenerationResult = await model.generateContent(queryGenerationPrompt);
      const searchQuery = queryGenerationResult.response.text().trim();

      try {
        const serpApiKey = functions.config().serpapi.key;
        if (serpApiKey) {
          const response = await axios.get("https://serpapi.com/search.json", {
            params: {
              engine: "google_search",
              q: searchQuery,
              api_key: serpApiKey,
            },
          });

          const data = response.data as SerpApiResponse;
          const knowledgeGraph = data.knowledge_graph;
          if (knowledgeGraph?.title && knowledgeGraph?.description) {
            liveFact = `\n\nSearch context: ${knowledgeGraph.title}: ${knowledgeGraph.description}`;
          } else if (data.organic_results && data.organic_results.length > 0) {
            liveFact = `\n\nSearch context: ${data.organic_results[0].snippet}`;
          }
        }
      } catch (error) {
        console.error("SerpApi error:", error);
      }
    }

    // --- STEP 3: Final Response ---
    const fullPrompt = `${context}${liveFact}\n\nUser Request: ${userRequest}`;

    const history: Content[] = messages.map((msg) => ({
      role: msg.isUser ? "user" : "model",
      parts: [{text: msg.text} as Part],
    }));

    const chat = model.startChat({
      history: history,
      generationConfig: { responseMimeType: "text/plain" },
    });

    const result = await chat.sendMessage(fullPrompt);
    return {response: result.response.text()};

  } catch (error: any) {
    console.error("AI Error:", error);
    // Explicitly pass the error message back to Flutter
    throw new HttpsError("internal", error.message || "Unknown AI error.");
  }
});