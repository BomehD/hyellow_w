import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hyellow_w/main.dart';

class PostInteractions {

  /// Mutes a user, preventing their posts from showing up in the current user's feed.
  /// This function adds the [targetUserId] to the current user's 'mutedUsers'
  /// subcollection. The feed should then be filtered to exclude posts from
  /// muted users.
  static Future<void> muteUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('You must be logged in to mute a user.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('mutedUsers')
          .doc(targetUserId)
          .set({'timestamp': FieldValue.serverTimestamp()});
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('User has been muted.')),
      );
    } catch (e) {
      print('Error muting user: $e');
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Failed to mute user. Please try again.')),
      );
    }
  }

  /// Blocks a user, preventing them from seeing the current user's profile and posts.
  ///
  /// This function now uses the top-level 'Blocks' collection to ensure consistency
  /// across the entire application. It also handles unfollowing and deleting
  /// follower notifications to complete the block action.
  static Future<void> blockUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('You must be logged in to block a user.')),
      );
      return;
    }

    try {
      // 1. Add the user to the current user's 'blocked' array in the 'Blocks' collection.
      await FirebaseFirestore.instance.collection('Blocks').doc(currentUserId).set({
        'blocked': FieldValue.arrayUnion([targetUserId])
      }, SetOptions(merge: true));

      // 2. Remove the blocked user from the current user's followers list.
      await FirebaseFirestore.instance.collection('Friends').doc(currentUserId).update({
        'followersMetadata.$targetUserId': FieldValue.delete()
      });

      // 3. Remove the current user from the blocked user's following list.
      await FirebaseFirestore.instance.collection('Friends').doc(targetUserId).update({
        'followingMetadata.$currentUserId': FieldValue.delete()
      });

      // 4. Delete any follower notifications related to this user.
      final notificationQuery = await FirebaseFirestore.instance.collection('notifications')
          .where('recipientId', isEqualTo: currentUserId)
          .where('senderId', isEqualTo: targetUserId)
          .where('type', isEqualTo: 'new_follower')
          .get();

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (final doc in notificationQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('User has been blocked.')),
      );
    } catch (e) {
      print('Error blocking user: $e');
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Failed to block user. Please try again.')),
      );
    }
  }

  /// Unblocks a user, allowing them to follow and interact again.
  ///
  /// This function removes the [targetUserId] from the current user's 'blocked'
  /// array in the top-level 'Blocks' collection.
  static Future<void> unblockUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('You must be logged in to unblock a user.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('Blocks').doc(currentUserId).update({
        'blocked': FieldValue.arrayRemove([targetUserId])
      });

      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('User has been unblocked.')),
      );
    } catch (e) {
      print('Error unblocking user: $e');
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Failed to unblock user. Please try again.')),
      );
    }
  }

  /// Hides a specific post for the current user.
  ///
  /// This function adds the [postId] to the current user's 'hiddenPosts'
  /// subcollection. The feed should then be filtered to exclude this post.
  static Future<void> hidePost(String postId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('You must be logged in to hide a post.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('hiddenPosts')
          .doc(postId)
          .set({'timestamp': FieldValue.serverTimestamp()});
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Post has been hidden.')),
      );
    } catch (e) {
      print('Error hiding post: $e');
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Failed to hide post. Please try again.')),
      );
    }
  }

  /// Reports a post for moderation review.
  ///
  /// This function creates a new document in a top-level 'reports' collection,
  /// containing the [postId], the ID of the reporting user, and the reason.
  static Future<void> reportPost(String postId, String reason) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('You must be logged in to report a post.')),
      );
      return;
    }
    if (reason.trim().isEmpty) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Please provide a reason for the report.')),
      );
      return;
    }

    try {
      snackbarKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(width: 16),
              const Text('Submitting report...'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blueAccent,
        ),
      );

      await FirebaseFirestore.instance.collection('postReports').add({
        'postId': postId,
        'reporterId': currentUserId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      snackbarKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Post reported for review. Thank you!'),
          backgroundColor: Colors.blueAccent,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('Error reporting post: $e');
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Failed to report post. Please try again later.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}
