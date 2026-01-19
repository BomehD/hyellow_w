// File: PostDetailScreen.dart
// Note: This implementation assumes Firestore persistence is enabled in your main.dart file.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;

  const PostDetailScreen({required this.postId, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    return Scaffold(
      appBar: AppBar(title: Text('Post')),
      body: FutureBuilder<DocumentSnapshot>(
        future: postRef.get(const GetOptions(source: Source.serverAndCache)), // Use server and cache
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Post not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['content'] ?? 'No content', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text('Posted by: ${data['authorName'] ?? 'Unknown'}'),
              ],
            ),
          );
        },
      ),
    );
  }
}