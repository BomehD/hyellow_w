// like_interactions.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LikeInteractions {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  static Future<bool> checkIfLiked(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    final doc = await _firestore.collection('posts').doc(postId).collection('likes').doc(userId).get();
    return doc.exists;
  }

  static Future<void> toggleLike({
    required String postId,
    required String postAuthorId,
    required String postContent,
    required ValueNotifier<bool> isLikedNotifier,
    required ValueNotifier<int> likeCountNotifier,
    // NEW: Add a parameter to check if the current user is blocked by the post's author
    required bool isPostAuthorBlocked,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      // Return early if the user is not authenticated
      return;
    }

    // NEW: Guard clause to prevent a blocked user from liking the blocker's post
    if (isPostAuthorBlocked) {
      // Fail silently, as if the user doesn't have permission to interact
      return;
    }

    final postRef = _firestore.collection('posts').doc(postId);
    final likeDocRef = postRef.collection('likes').doc(userId);

    final currentlyLiked = isLikedNotifier.value;

    // Optimistic UI update
    isLikedNotifier.value = !currentlyLiked;
    likeCountNotifier.value += currentlyLiked ? -1 : 1;

    try {
      await _firestore.runTransaction((transaction) async {
        final postSnap = await transaction.get(postRef);
        if (!postSnap.exists) {
          throw Exception('Post not found');
        }
        final int currentLikeCountInDb = (postSnap.data()?['likeCount'] ?? 0) as int;

        if (currentlyLiked) {
          // User is unliking: delete like doc and decrement count
          transaction.delete(likeDocRef);
          transaction.update(postRef, {'likeCount': currentLikeCountInDb > 0 ? currentLikeCountInDb - 1 : 0});
        } else {
          // User is liking: set like doc and increment count
          transaction.set(likeDocRef, {'likedAt': FieldValue.serverTimestamp()});
          transaction.update(postRef, {'likeCount': currentLikeCountInDb + 1});
        }
      });

      // Notifications: create after transaction succeeds
      if (!currentlyLiked && userId != postAuthorId) {
        try {
          final likerUserDoc = await _firestore.collection('users').doc(userId).get();
          final likerProfileDoc = await _firestore.collection('profiles').doc(userId).get();

          final likerName = likerUserDoc.data()?['name'] ?? 'Someone';
          final likerProfileImage = likerProfileDoc.data()?['profileImage'];

          await _firestore.collection('notifications').add({
            'recipientId': postAuthorId,
            'senderId': userId,
            'type': 'like',
            'message': '$likerName liked your post: "${postContent.length > 50 ? '${postContent.substring(0, 50)}...' : postContent}"',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'postId': postId,
            'imageUrl': likerProfileImage,
          });
        } catch (_) {
          // ignore notification errors
        }
      }
    } catch (e) {
      // Revert optimistic update if transaction fails
      isLikedNotifier.value = currentlyLiked;
      likeCountNotifier.value += currentlyLiked ? 1 : -1;
      rethrow;
    }
  }
}