// lib/services/chat_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

class ChatService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String formatLastSeen(Timestamp? lastSeen) {
    if (lastSeen == null) return 'Offline';
    final now = DateTime.now();
    final lastSeenDate = lastSeen.toDate();
    final difference = now.difference(lastSeenDate);

    if (difference.inMinutes < 5) {
      return 'Online';
    } else if (difference.inHours < 24) {
      return 'Last seen today at ${DateFormat('HH:mm').format(lastSeenDate)}';
    } else if (difference.inHours < 48) {
      return 'Last seen yesterday at ${DateFormat('HH:mm').format(lastSeenDate)}';
    } else {
      return 'Last seen on ${DateFormat('MMM d, y').format(lastSeenDate)}';
    }
  }

  String formatMessageTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final messageDate = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(messageDate.year, messageDate.month, messageDate.day);

    if (messageDay.isAtSameMomentAs(today)) {
      return DateFormat('HH:mm').format(messageDate);
    } else {
      return DateFormat('MMM d, HH:mm').format(messageDate);
    }
  }

  Future<String?> getExistingChatId(String friendId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    String currentUserId = currentUser.uid;
    List<String> users = [currentUserId, friendId];
    users.sort();

    QuerySnapshot querySnapshot = await _firestore
        .collection('chats')
        .where('users', isEqualTo: users)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    } else {
      return null;
    }
  }

  // NEW: A helper function to check if the recipient has blocked the current user.
  Future<bool> isBlockedByRecipient(String recipientId, String currentUserId) async {
    try {
      final blockDoc = await _firestore.collection('Blocks').doc(recipientId).get();
      List<dynamic> blockedUsers = blockDoc.data()?['blocked'] ?? [];
      return blockedUsers.contains(currentUserId);
    } catch (e) {
      debugPrint('Error checking blocked status: $e');
      return false;
    }
  }


  Future<String?> createChatAndSendMessage(
      String message,
      String receiverId, {
        String? replyToMessageId,
        String? replyToSenderName,
        String? replyToContent,
        String? mediaUrl,
        String? mediaType,
      }) async {
    final currentUserId = _auth.currentUser!.uid;

    // NEW: Check if the recipient has blocked the current user before creating a chat.
    if (await isBlockedByRecipient(receiverId, currentUserId)) {
      debugPrint('Message sending failed: Recipient has blocked the sender.');
      return null;
    }

    List<String> users = [currentUserId, receiverId];
    users.sort();

    String lastMessageContent = message.isNotEmpty
        ? message
        : mediaType != null
        ? '[${mediaType.toUpperCase()}]'
        : 'New Message';

    DocumentReference chatDoc = await _firestore.collection('chats').add({
      'users': users,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': lastMessageContent,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
      'lastMessageReadBy': {currentUserId: Timestamp.now()},
      'deletedBy': [],
      'unreadCount': {
        currentUserId: 0,
        receiverId: 1,
      },
      'mutedBy': [],
      'pinnedBy': [],
      'participants': users,
    });

    await chatDoc.collection('messages').add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'content': message,
      'timestamp': FieldValue.serverTimestamp(),
      'replyToMessageId': replyToMessageId,
      'replyToSenderName': replyToSenderName,
      'replyToContent': replyToContent,
      'readBy': {currentUserId: Timestamp.now()},
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
    });

    return chatDoc.id;
  }

  Future<void> sendMessage(String chatId, String message, String receiverId,
      {String? replyToMessageId,
        String? replyToSenderName,
        String? replyToContent,
        String? mediaUrl,
        String? mediaType,
      }) async {
    final currentUserId = _auth.currentUser!.uid;

    // NEW: Check if the recipient has blocked the current user before sending a message.
    if (await isBlockedByRecipient(receiverId, currentUserId)) {
      debugPrint('Message sending failed: Recipient has blocked the sender.');
      return;
    }

    final chatDocRef = _firestore.collection('chats').doc(chatId);

    final chatDoc = await chatDocRef.get();
    if (chatDoc.exists) {
      final deletedBy = (chatDoc.data()?['deletedBy'] as List<dynamic>?)?.cast<String>() ?? [];
      if (deletedBy.contains(currentUserId)) {
        await chatDocRef.update({
          'deletedBy': FieldValue.arrayRemove([currentUserId]),
        });
        debugPrint('Un-archived chat with $receiverId on sending a new message.');
      }
    }

    await chatDocRef.collection('messages').add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'content': message,
      'timestamp': FieldValue.serverTimestamp(),
      'replyToMessageId': replyToMessageId,
      'replyToSenderName': replyToSenderName,
      'replyToContent': replyToContent,
      'readBy': {currentUserId: Timestamp.now()},
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
    });

    String lastMessageContent = message.isNotEmpty
        ? message
        : mediaType != null
        ? '[${mediaType.toUpperCase()}]'
        : 'New Message';

    await chatDocRef.update({
      'lastMessage': lastMessageContent,
      'lastMessageSenderId': currentUserId,
      'lastMessageAt': FieldValue.serverTimestamp(), // Use server timestamp for consistency
      'lastMessageReadBy': {currentUserId: Timestamp.now()},
      'participants': FieldValue.arrayUnion([currentUserId, receiverId]),
      'unreadCount.$receiverId': FieldValue.increment(1),
    });
  }

  Future<void> markMessagesAsRead(String chatId, String friendId) async {
    final currentUserId = _auth.currentUser!.uid;
    debugPrint('markMessagesAsRead called for user: $currentUserId in chat: $chatId with friendId: $friendId');

    final messagesRef = _firestore.collection('chats').doc(chatId).collection('messages');
    final chatDocRef = _firestore.collection('chats').doc(chatId);
    final batch = _firestore.batch();

    final allMessagesFromFriendSnapshot = await messagesRef
        .where('senderId', isEqualTo: friendId)
        .get();

    int unreadCount = 0;

    for (var doc in allMessagesFromFriendSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final readBy = data['readBy'] as Map<String, dynamic>? ?? {};

      if (!readBy.containsKey(currentUserId)) {
        batch.update(doc.reference, {
          'readBy.$currentUserId': FieldValue.serverTimestamp(),
        });
        unreadCount++;
      }
    }

    if (unreadCount > 0) {
      debugPrint('Found and marked $unreadCount messages from friend as read.');
    } else {
      debugPrint('No new unread messages from friend to mark as read.');
    }

    debugPrint('Adding unreadCount reset for $currentUserId to 0 in chat batch.');
    batch.update(chatDocRef, {
      'unreadCount.$currentUserId': 0,
    });

    try {
      await batch.commit();
      debugPrint('Batch commit successful!');
    } catch (e) {
      debugPrint('ERROR: Batch commit failed with error: $e');
    }
  }

  Future<void> deleteMessage(BuildContext context, String chatId, String messageId) async {
    try {
      final chatRef = _firestore.collection('chats').doc(chatId);
      final messageRef = chatRef.collection('messages').doc(messageId);
      final chatDoc = await chatRef.get();
      final lastMessageAt = chatDoc.data()?['lastMessageAt'] as Timestamp?;
      final deletedMessageSnapshot = await messageRef.get();
      final deletedMessageData = deletedMessageSnapshot.data();
      final deletedMessageTimestamp = deletedMessageData?['timestamp'] as Timestamp?;

      await messageRef.delete();

      // Check if the deleted message was the latest one
      if (lastMessageAt != null && deletedMessageTimestamp != null && lastMessageAt.toDate().isAtSameMomentAs(deletedMessageTimestamp.toDate())) {
        // Query for the new latest message after the deletion
        final messagesSnapshot = await chatRef
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (messagesSnapshot.docs.isNotEmpty) {
          final newLastMessageDoc = messagesSnapshot.docs.first;
          final newLastMessageData = newLastMessageDoc.data();
          String newLastMessageContent = newLastMessageData['content'] ?? (newLastMessageData['mediaType'] != null ? '[${newLastMessageData['mediaType'].toUpperCase()}]' : 'Message deleted');

          await chatRef.update({
            'lastMessage': newLastMessageContent,
            'lastMessageAt': newLastMessageData['timestamp'],
            'lastMessageSenderId': newLastMessageData['senderId'],
          });
        } else {
          // No messages are left, so clear the last message fields
          await chatRef.update({
            'lastMessage': '',
            'lastMessageAt': null,
            'lastMessageSenderId': null,
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $e')),
      );
      debugPrint('Error deleting message: $e');
    }
  }

  Future<void> editMessage(BuildContext context, String chatId, String messageId, String newContent) async {
    try {
      final chatRef = _firestore.collection('chats').doc(chatId);
      final messageRef = chatRef.collection('messages').doc(messageId);

      await messageRef.update({
        'content': newContent,
        'editedAt': FieldValue.serverTimestamp(),
      });

      // Check if the edited message was the last one
      final messageSnapshot = await messageRef.get();
      final messageData = messageSnapshot.data();
      final messageTimestamp = messageData?['timestamp'] as Timestamp?;

      final chatDoc = await chatRef.get();
      final lastMessageAt = chatDoc.data()?['lastMessageAt'] as Timestamp?;

      // Compare DateTime objects to ensure consistency
      if (messageTimestamp != null && lastMessageAt != null && messageTimestamp.toDate().isAtSameMomentAs(lastMessageAt.toDate())) {
        // Update the last message in the parent chat document with the new content
        await chatRef.update({
          'lastMessage': newContent,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message edited.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit message: $e')),
      );
    }
  }

  Future<void> clearChat(BuildContext context, String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Clear Chat"),
          content: const Text("Are you sure you want to clear all messages in this chat? This cannot be undone."),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("CANCEL")),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("CLEAR")),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        WriteBatch batch = _firestore.batch();
        var messagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .get();

        for (var doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        await _firestore.collection('chats').doc(chatId).update({
          'lastMessage': '',
          'lastMessageAt': null, // Changed from serverTimestamp() to null
          'unreadCount.${currentUser.uid}': 0,
          'lastMessageSenderId': null, // Added to clear the sender as well
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat cleared.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear chat: $e')),
        );
      }
    }
  }

  Future<void> deleteChat(BuildContext context, String chatId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Chat"),
          content: const Text("Are you sure you want to permanently delete this chat? This cannot be undone."),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("CANCEL")),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("DELETE")),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        WriteBatch batch = _firestore.batch();
        var messagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .get();

        for (var doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        await _firestore.collection('chats').doc(chatId).delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat permanently deleted.')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chat: $e')),
        );
      }
    }
  }

  Future<void> toggleMuteChat(BuildContext context, String chatId, bool isMuted) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    try {
      if (isMuted) {
        await _firestore.collection('chats').doc(chatId).update({
          'mutedBy': FieldValue.arrayRemove([currentUserId]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat unmuted.')),
        );
      } else {
        await _firestore.collection('chats').doc(chatId).update({
          'mutedBy': FieldValue.arrayUnion([currentUserId]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat muted.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change mute status: $e')),
      );
    }
  }

  Future<void> togglePinChat(BuildContext context, String chatId, bool isPinned) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    try {
      if (isPinned) {
        await _firestore.collection('chats').doc(chatId).update({
          'pinnedBy': FieldValue.arrayRemove([currentUserId]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat unpinned.')),
        );
      } else {
        await _firestore.collection('chats').doc(chatId).update({
          'pinnedBy': FieldValue.arrayUnion([currentUserId]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat pinned.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change pin status: $e')),
      );
    }
  }

  Future<void> blockUser(String friendId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore.collection('Blocks').doc(currentUserId).set({
        'blocked': FieldValue.arrayUnion([friendId]),
      }, SetOptions(merge: true));
      debugPrint('User $friendId blocked successfully.');
    } catch (e) {
      debugPrint('Error blocking user: $e');
    }
  }

  Future<void> unblockUser(String friendId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore.collection('Blocks').doc(currentUserId).update({
        'blocked': FieldValue.arrayRemove([friendId]),
      });
      debugPrint('User $friendId unblocked successfully.');
    } catch (e) {
      debugPrint('Error unblocking user: $e');
    }
  }

  Future<bool> isBlocked(String currentUserId, String otherUserId) async {
    try {
      final doc = await _firestore.collection('Blocks').doc(currentUserId).get();
      if (doc.exists) {
        final blockedList = doc.data()?['blocked'] as List<dynamic>?;
        return blockedList?.contains(otherUserId) ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking blocked status: $e');
      return false;
    }
  }

}