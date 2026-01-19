import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';


class AiAssistantLogic {
  final String _functionName = 'generateAiResponse';
  final List<Map<String, dynamic>> _messages;
  final Function(VoidCallback) _setState;

  String? _currentChatId;

  AiAssistantLogic(this._messages, this._setState);

  Future<List<String>> searchUsers(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('users')
        .where('handle', isGreaterThanOrEqualTo: query)
        .where('handle', isLessThan: query + 'z')
        .limit(5)
        .get();

    return snapshot.docs.map((doc) => doc.get('handle') as String).toList();
  }

  Future<void> deleteChat(String chatId) async {
    final firestore = FirebaseFirestore.instance;
    final chatRef = firestore.collection('ai_chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    // Delete all messages in the subcollection using a batch write
    final batch = firestore.batch();
    final messagesSnapshot = await messagesRef.get();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Now delete the chat document itself
    await chatRef.delete();

    // Check if the deleted chat was the current one, and if so, start a new chat
    if (_currentChatId == chatId) {
      startNewChat();
    }
  }

  Future<String?> _getUserIdByHandle(String handle) async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('users')
        .where('handle', isEqualTo: handle)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    }
    return null;
  }

  Future<Map<String, dynamic>> _fetchContextualData({
    required String userId,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userProfile = (await firestore.collection('profiles').doc(userId).get()).data() ?? {};
    final userPosts = (await firestore.collection('posts').where('authorId', isEqualTo: userId).orderBy('timestamp', descending: true).limit(5).get()).docs.map((doc) => doc.data()).toList();

    return {
      'profile': userProfile,
      'posts': userPosts,
    };
  }

  String _formatPrompt({
    required Map<String, dynamic> currentUserContext,
    required Map<String, dynamic> targetedUserContext,
    required bool hasConsent,
    required bool isPersonalQuery,
  }) {
    // If user has not given consent, or the query is not personal, use a general prompt with identity info available when asked
    if (!hasConsent || !isPersonalQuery) {
      return "You are a friendly and helpful AI assistant named CoSense. Your purpose is to act as a knowledgeable guide and conversational partner. You can use your general knowledge to answer questions. If asked about yourself or the platform: You are CoSense, an AI assistant on CoPal, a social media platform for shared interests that was founded by Dunstan Bomeh in 2025 and launched in Accra, Ghana. You must be friendly and personable in all your responses.";
    }

    // Otherwise, use the detailed contextual prompt
    String prompt = "You are a friendly and helpful AI assistant named CoSense. Your purpose is to act as a knowledgeable guide and conversational partner for users on CoPal, a social media platform for shared interests. CoPal was founded by Dunstan Bomeh in 2025 and was launched in Accra, Ghana. You must be friendly and personable in all your responses. When responding to personal queries, you MUST only use the following context. If the information isn't provided in the context, state that you don't have access to it.\n\n";

    final hasUserContext = currentUserContext['profile'] != null && currentUserContext['profile'].isNotEmpty;
    final hasTargetedContext = targetedUserContext['profile'] != null && targetedUserContext['profile'].isNotEmpty;

    // Add current user's context if available and hasConsent is true.
    if (hasUserContext) {
      final currentUserProfile = currentUserContext['profile'];
      prompt += "### Context about You (the current user):\n";
      prompt += "Profile: (Name: ${currentUserProfile['name'] ?? 'N/A'}, Interests: ${currentUserProfile['interest'] ?? 'N/A'}, About: ${currentUserProfile['about'] ?? 'N/A'})\n\n";
    }

    if (currentUserContext['posts'] != null && currentUserContext['posts'].isNotEmpty) {
      final currentUserPosts = currentUserContext['posts'];
      prompt += "Recent Posts:\n";
      for (final p in currentUserPosts) {
        prompt += "Content: ${p['content'] ?? 'N/A'}\nInterests: ${p['interest'] ?? 'N/A'}\n\n";
      }
    }

    // Add targeted user's context if a mention was found.
    if (hasTargetedContext) {
      final targetedProfile = targetedUserContext['profile'];
      final targetedPosts = targetedUserContext['posts'];
      prompt += "### Context about the Targeted User:\n";
      prompt += "Profile: (Name: ${targetedProfile['name'] ?? 'N/A'}, Interests: ${targetedProfile['interest'] ?? 'N/A'}, About: ${targetedProfile['about'] ?? 'N/A'})\n\n";
      if (targetedPosts != null && targetedPosts.isNotEmpty) {
        prompt += "Recent Posts:\n";
        for (final p in targetedPosts) {
          prompt += "Content: ${p['content'] ?? 'N/A'}\nInterests: ${p['interest'] ?? 'N/A'}\n\n";
        }
      }
    }

    return prompt;
  }

  Future<void> sendMessage(String messageText) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("No user is currently signed in.");
    }

    _setState(() => _messages.add({'text': messageText, 'isUser': true}));

    final typingIndicator = {'text': '', 'isUser': false, 'isTyping': true};
    _setState(() => _messages.add(typingIndicator));

    try {
      final firestore = FirebaseFirestore.instance;

      if (_currentChatId == null) {
        final newChatRef = firestore.collection('ai_chats').doc();
        _currentChatId = newChatRef.id;

        await newChatRef.set({
          'userId': user.uid,
          'title': messageText.substring(0, messageText.length > 50 ? 50 : messageText.length),
          'lastMessage': messageText,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await firestore.collection('ai_chats').doc(_currentChatId).update({
          'lastMessage': messageText,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final userMessageData = {
        'senderId': user.uid,
        'text': messageText,
        'createdAt': FieldValue.serverTimestamp(),
        'isUser': true,
      };
      await firestore.collection('ai_chats').doc(_currentChatId).collection('messages').add(userMessageData);

      final userProfileDoc = await firestore.collection('profiles').doc(user.uid).get();
      final hasConsent = userProfileDoc.data()?['aiDataConsent'] ?? true;

      Map<String, dynamic> currentUserContext = {};
      Map<String, dynamic> targetedUserContext = {};
      final originalUserRequest = messageText;

      final mentionMatches = RegExp(r'@(\S+)').allMatches(messageText);

      // --- NEW LOGIC: Determine if this is a personal query
      final isPersonalQuery = messageText.contains('my ') ||
          messageText.contains('I ') ||
          messageText.contains('me') ||
          mentionMatches.isNotEmpty;

      // 1. Fetch data only if the query is a personal one and consent is given
      if (isPersonalQuery && hasConsent) {
        currentUserContext = await _fetchContextualData(userId: user.uid);
      }

      // 2. Fetch targeted user's data if a mention is present
      if (mentionMatches.isNotEmpty) {
        String? lastMentionedHandle = mentionMatches.last.group(1);
        if (lastMentionedHandle != null) {
          final targetUserId = await _getUserIdByHandle(lastMentionedHandle);
          if (targetUserId != null) {
            targetedUserContext = await _fetchContextualData(userId: targetUserId);
          }
        }
      }

      // 3. Pass all relevant info to the formatting function
      final contextPrompt = _formatPrompt(
        currentUserContext: currentUserContext,
        targetedUserContext: targetedUserContext,
        hasConsent: hasConsent,
        isPersonalQuery: isPersonalQuery,
      );

      final historyToPass = _messages
          .where((msg) => msg['isTyping'] != true)
          .map((msg) => {
        'text': msg['text'],
        'isUser': msg['isUser'],
      })
          .toList();

      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(_functionName);
      final HttpsCallableResult<dynamic> result = await callable.call<dynamic>({
        'context': contextPrompt,
        'messages': historyToPass,
        'userRequest': originalUserRequest,
      });

      final aiText = result.data['response'];

      final typingIndex = _messages.indexWhere((element) => element['isTyping'] == true);
      if (typingIndex != -1) {
        _setState(() {
          _messages[typingIndex] = {
            'text': aiText ?? 'I could not generate a response.',
            'isUser': false,
            'isTyping': false,
          };
        });
      }

      final aiMessageData = {
        'senderId': 'coSense',
        'text': aiText ?? 'I could not generate a response.',
        'createdAt': FieldValue.serverTimestamp(),
        'isUser': false,
      };
      await firestore.collection('ai_chats').doc(_currentChatId).collection('messages').add(aiMessageData);

      await firestore.collection('ai_chats').doc(_currentChatId).update({
        'lastMessage': aiText,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error calling Cloud Function: $e');
      }
      final typingIndex = _messages.indexWhere((element) => element['isTyping'] == true);
      if (typingIndex != -1) {
        _setState(() {
          _messages[typingIndex] = {
            'text': 'Sorry, something went wrong. Please try again.',
            'isUser': false,
            'isTyping': false,
          };
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentChats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }

    final chatsSnapshot = await FirebaseFirestore.instance
        .collection('ai_chats')
        .where('userId', isEqualTo: user.uid)
        .orderBy('updatedAt', descending: true)
        .get();

    return chatsSnapshot.docs.map((doc) => {...doc.data(), 'chatId': doc.id}).toList();
  }

  Future<void> loadChat(String chatId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _setState(() {
      _messages.clear();
      _currentChatId = chatId;
    });

    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('ai_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .get();

    final history = messagesSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    _setState(() => _messages.addAll(history));
  }

  Future<void> startNewChat() async {
    _setState(() {
      _messages.clear();
      _currentChatId = null;
    });
  }
}