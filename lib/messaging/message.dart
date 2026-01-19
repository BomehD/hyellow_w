// lib/models/message.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String content;
  final Timestamp? timestamp;
  final String? replyToMessageId;
  final String? replyToSenderName;
  final String? replyToContent;
  final Map<String, Timestamp> readBy; // Field to track who read the message and when
  final String? mediaUrl; // NEW: Media URL field
  final String? mediaType; // NEW: Media Type field (e.g., 'image', 'video', 'document')

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    this.timestamp,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToContent,
    required this.readBy,
    this.mediaUrl, // Ensure this is in the constructor
    this.mediaType, // Ensure this is in the constructor
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Handle readBy conversion from Map<dynamic, dynamic> to Map<String, Timestamp>
    Map<String, Timestamp> parsedReadBy = {};
    if (data['readBy'] != null) {
      (data['readBy'] as Map<dynamic, dynamic>).forEach((key, value) {
        if (key is String && value is Timestamp) {
          parsedReadBy[key] = value;
        }
      });
    }

    return Message(
      id: doc.id,
      senderId: data['senderId'] as String,
      content: data['content'] as String,
      timestamp: data['timestamp'] as Timestamp?,
      replyToMessageId: data['replyToMessageId'] as String?,
      replyToSenderName: data['replyToSenderName'] as String?,
      replyToContent: data['replyToContent'] as String?,
      readBy: parsedReadBy,
      mediaUrl: data['mediaUrl'] as String?, // <--- CRITICAL FIX: Extract mediaUrl from data
      mediaType: data['mediaType'] as String?, // <--- CRITICAL FIX: Extract mediaType from data
    );
  }
}