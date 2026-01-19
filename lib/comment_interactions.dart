import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/profile_navigator.dart' as ProfileNavigator;
import 'package:timeago/timeago.dart' as timeago;
import 'reply_widget.dart';
import 'package:flutter/gestures.dart';

class CommentInteractions {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Map<String, Map<String, dynamic>>> _fetchUsersBatch(List<String> userIds) async {
    final Map<String, Map<String, dynamic>> results = {};
    if (userIds.isEmpty) return results;

    const int chunkSize = 10;
    for (var i = 0; i < userIds.length; i += chunkSize) {
      final chunk = userIds.sublist(i, (i + chunkSize) > userIds.length ? userIds.length : i + chunkSize);

      final usersSnap = await _firestore.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      final profilesSnap = await _firestore.collection('profiles').where(FieldPath.documentId, whereIn: chunk).get();

      final Map<String, Map<String, dynamic>> usersMap = {
        for (var d in usersSnap.docs) d.id: (d.data() as Map<String, dynamic>)
      };
      final Map<String, Map<String, dynamic>> profilesMap = {
        for (var d in profilesSnap.docs) d.id: (d.data() as Map<String, dynamic>)
      };

      for (final id in chunk) {
        final user = usersMap[id];
        final profile = profilesMap[id];
        final name = user != null ? (user['name'] ?? 'Unknown User') : 'Unknown User';
        final handle = user != null ? (user['handle'] ?? 'unknown_handle') : 'unknown_handle';
        final profileImage = profile != null ? (profile['profileImage'] ?? 'https://via.placeholder.com/150') : 'https://via.placeholder.com/150';

        results[id] = {
          'name': name,
          'handle': handle,
          'profileImage': profileImage,
        };
      }
    }

    return results;
  }

  static Future<void> _toggleCommentLike(String postId, String commentId, bool currentlyLiked) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final commentRef = _firestore.collection('posts').doc(postId).collection('comments').doc(commentId);

    try {
      if (currentlyLiked) {
        await commentRef.update({
          'likes': FieldValue.arrayRemove([currentUser.uid]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await commentRef.update({
          'likes': FieldValue.arrayUnion([currentUser.uid]),
          'likeCount': FieldValue.increment(1),
        });

        final commentSnapshot = await commentRef.get();
        final parentAuthorId = commentSnapshot.data()?['authorId'];
        if (parentAuthorId != null && parentAuthorId != currentUser.uid) {
          final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
          final profileDoc = await _firestore.collection('profiles').doc(currentUser.uid).get();
          final likerName = userDoc.data()?['name'] ?? 'Someone';
          final likerProfileImage = profileDoc.data()?['profileImage'] ?? '';

          await _firestore.collection('notifications').add({
            'recipientId': parentAuthorId,
            'senderId': currentUser.uid,
            'type': 'comment_like',
            'message': '$likerName liked your comment',
            'postId': postId,
            'commentId': commentId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'imageUrl': likerProfileImage,
          });
        }
      }
    } catch (e) {
      // swallow - UI handles revert via local override maps
    }
  }

  static Widget _buildClickableText(BuildContext context, String text) {
    final List<TextSpan> spans = [];
    final RegExp mentionRegExp = RegExp(r'@(\w+)');

    text.splitMapJoin(
      mentionRegExp,
      onMatch: (m) {
        final String? handle = m.group(1);
        spans.add(
          TextSpan(
            text: m.group(0),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                if (handle != null) {
                  final userSnap = await _firestore.collection('users').where('handle', isEqualTo: handle).limit(1).get();
                  if (userSnap.docs.isNotEmpty) {
                    final mentionedUserId = userSnap.docs.first.id;
                    ProfileNavigator.navigateToProfile(context, mentionedUserId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User not found.')),
                    );
                  }
                }
              },
          ),
        );
        return '';
      },
      onNonMatch: (nm) {
        spans.add(
          TextSpan(
            text: nm,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11, // Adjust this to your preferred size
              fontWeight: FontWeight.w500, // Optional: adjust weight if needed
            ),
          ),
        );

        return '';
      },
    );

    return RichText(text: TextSpan(children: spans));
  }

  static Future<void> _addComment(String text, String postId, String postAuthorId, String postContent, ValueNotifier<int> commentCountNotifier) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final commentText = text.trim();
    if (commentText.isEmpty) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final newCommentRef = postRef.collection('comments').doc();

    final batch = _firestore.batch();

    batch.set(newCommentRef, {
      'authorId': currentUser.uid,
      'text': commentText,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
      'replyCount': 0,
      'likeCount': 0,
    });

    batch.update(postRef, {
      'commentCount': FieldValue.increment(1),
    });

    try {
      await batch.commit();

      // Only update the notifier after successful commit
      commentCountNotifier.value++;

      if (currentUser.uid != postAuthorId) {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        final profileDoc = await _firestore.collection('profiles').doc(currentUser.uid).get();
        final senderName = userDoc.data()?['name'] ?? 'Someone';
        final senderProfileImage = profileDoc.data()?['profileImage'] ?? '';

        await _firestore.collection('notifications').add({
          'recipientId': postAuthorId,
          'senderId': currentUser.uid,
          'type': 'comment',
          'message': '$senderName commented on your post: "${commentText.length > 50 ? commentText.substring(0, 50) + '...' : commentText}"',
          'postId': postId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'imageUrl': senderProfileImage,
        });
      }
    } catch (e) {
      // Don't update commentCountNotifier since the operation failed
      rethrow;
    }
  }

  static Future<void> _addReplyToParent(String text, String parentPath, String postId, String parentAuthorId, String parentText, String topLevelCommentId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final replyText = text.trim();
    if (replyText.isEmpty) return;

    final parentDocRef = _firestore.doc(parentPath);
    final topLevelCommentRef = _firestore.collection('posts').doc(postId).collection('comments').doc(topLevelCommentId);

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Read the parent document and top-level comment within the transaction.
        final parentSnapshot = await transaction.get(parentDocRef);
        final topLevelSnapshot = await transaction.get(topLevelCommentRef);

        // CRITICAL CHECK: Ensure the parent document exists.
        if (!parentSnapshot.exists) {
          throw Exception("Parent comment or reply does not exist!");
        }

        // 2. Create the data for the new reply.
        final newReplyData = {
          'authorId': currentUser.uid,
          'text': replyText,
          'timestamp': FieldValue.serverTimestamp(),
          'likes': [],
          'likeCount': 0,
          'replyCount': 0, // Replies can have their own nested replies
        };

        // 3. Create the new reply document.
        final newReplyRef = parentDocRef.collection('replies').doc();
        transaction.set(newReplyRef, newReplyData);

        // 4. Update the parent's reply count.
        transaction.update(parentDocRef, {
          'replyCount': FieldValue.increment(1),
        });

        // 5. Update the top-level comment's reply count if it's different.
        // Also check if the document exists before attempting to update.
        if (topLevelSnapshot.exists && topLevelCommentRef.path != parentDocRef.path) {
          transaction.update(topLevelCommentRef, {
            'replyCount': FieldValue.increment(1),
          });
        }
      });

      // After a successful transaction, send the notification.
      if (currentUser.uid != parentAuthorId && parentAuthorId.isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        final profileDoc = await _firestore.collection('profiles').doc(currentUser.uid).get();
        final senderName = userDoc.data()?['name'] ?? 'Someone';
        final senderProfileImage = profileDoc.data()?['profileImage'] ?? '';

        String notificationMessage;
        final parentPathSegments = parentPath.split('/');
        final isTopLevel = parentPathSegments.contains('comments') && parentPathSegments.length == 4;
        if (isTopLevel) {
          notificationMessage = '$senderName replied to your comment: "${parentText.length > 50 ? parentText.substring(0, 50) + '...' : parentText}"';
        } else {
          notificationMessage = '$senderName replied to your reply: "${parentText.length > 50 ? parentText.substring(0, 50) + '...' : parentText}"';
        }

        await _firestore.collection('notifications').add({
          'recipientId': parentAuthorId,
          'senderId': currentUser.uid,
          'type': 'reply',
          'message': notificationMessage,
          'postId': postId,
          'parentPath': parentPath,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'imageUrl': senderProfileImage,
        });
      }
    } catch (e) {
      // Catch transaction-specific errors, like the document not existing.
      print('Transaction failed: $e');
      rethrow;
    }
  }
  static Future<bool> _areCommentsEnabled(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return false;
      final postData = postDoc.data() as Map<String, dynamic>?;
      return postData?['commentsEnabled'] ?? true;
    } catch (e) {
      return true; // Default to enabled on error
    }
  }

  static void showCommentsDialog(
      BuildContext context,
      String postId,
      String postAuthorId,
      String postContent,
      ValueNotifier<int> commentCountNotifier, {
        Function()? onCommentDeleted,
        required bool isPostAuthorBlocked,
      }) {
    final currentUser = _auth.currentUser;
    final ValueNotifier<Map<String, String>?> currentReplyTarget = ValueNotifier(null);
    final TextEditingController mainCommentController = TextEditingController();
    final FocusNode mainCommentFocusNode = FocusNode();

    final Map<String, Map<String, dynamic>> authorCache = {};
    final Map<String, bool> commentReplySectionVisibility = {};
    final Map<String, bool> localCommentLikedOverride = {};
    final Map<String, int> localCommentLikeCountOverride = {};
    final Set<String> pendingLikeOps = {};
    final Set<String> pendingAddCommentIds = {};

    void setReplyTarget(String parentPath, String parentAuthorHandle, String parentAuthorId, String parentText) {
      currentReplyTarget.value = {
        'path': parentPath,
        'author': parentAuthorHandle,
        'authorId': parentAuthorId,
        'text': parentText,
      };
      mainCommentController.text = '@$parentAuthorHandle ';
      mainCommentController.selection = TextSelection.fromPosition(
        TextPosition(offset: mainCommentController.text.length),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mainCommentFocusNode.requestFocus();
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            Future<void> _ensureAuthorsCached(List<QueryDocumentSnapshot> comments) async {
              final missing = <String>{};
              for (final d in comments) {
                final authorId = (d.data() as Map<String, dynamic>)['authorId'] ?? '';
                if (authorId.isNotEmpty && !authorCache.containsKey(authorId)) {
                  missing.add(authorId);
                }
              }
              if (missing.isEmpty) return;
              final fetched = await _fetchUsersBatch(missing.toList());
              authorCache.addAll(fetched);
              setStateInDialog(() {});
            }

            return AlertDialog(
              title: const Text('Comments', style: TextStyle(color: Colors.grey)),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (isPostAuthorBlocked)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.block, size: 60, color: Colors.redAccent),
                          const SizedBox(height: 20),
                          Text(
                            'You cannot comment on this post because the author has blocked you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 20),
                        ],
                      )
                    else
                      StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection('posts').doc(postId).snapshots(),
                        builder: (context, postSnapshot) {
                          if (postSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (postSnapshot.hasError) {
                            return Center(child: Text('Error loading post settings: ${postSnapshot.error}'));
                          }
                          if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
                            return const Center(child: Text('Post not found.'));
                          }

                          final postData = postSnapshot.data!.data() as Map<String, dynamic>?;
                          final bool commentsAreEnabled = postData?['commentsEnabled'] ?? true;

                          if (!commentsAreEnabled) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.comments_disabled, size: 60, color: Colors.grey),
                                const SizedBox(height: 20),
                                Text(
                                  'Comments are currently disabled for this post by the author.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 20),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('posts')
                            .doc(postId)
                            .collection('comments')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final comments = snapshot.data!.docs;

                          if (comments.isEmpty) {
                            return const Center(
                              child: Text(
                                'No comments yet. Be the first to comment!',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          _ensureAuthorsCached(comments);

                          return ListView.builder(
                            key: ValueKey('comments_list_$postId'),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final commentDoc = comments[index];
                              final data = commentDoc.data() as Map<String, dynamic>;
                              final commentId = commentDoc.id;
                              final authorId = data['authorId'] ?? '';
                              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                              final serverLikes = List<String>.from(data['likes'] ?? []);
                              final serverLikeCount = data['likeCount'] ?? serverLikes.length;
                              final commentReplyCount = data['replyCount'] ?? 0;
                              final isAuthor = currentUser?.uid == authorId;
                              final serverIsLiked = serverLikes.contains(currentUser?.uid);
                              final commentText = data['text'] ?? '';

                              commentReplySectionVisibility.putIfAbsent(commentId, () => false);

                              final bool displayedIsLiked = localCommentLikedOverride.containsKey(commentId)
                                  ? localCommentLikedOverride[commentId]!
                                  : serverIsLiked;
                              final int displayedLikeCount = localCommentLikeCountOverride.containsKey(commentId)
                                  ? localCommentLikeCountOverride[commentId]!
                                  : serverLikeCount;

                              final authorData = authorCache[authorId];
                              final profileImage = authorData != null ? authorData['profileImage'] : 'https://via.placeholder.com/150';
                              final authorName = authorData != null ? authorData['name'] : (authorId == currentUser?.uid ? 'You' : 'Loading...');
                              final authorHandle = authorData != null ? authorData['handle'] : '';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setStateInDialog(() {
                                        commentReplySectionVisibility[commentId] =
                                        !(commentReplySectionVisibility[commentId] ?? false);
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      padding: const EdgeInsets.only(bottom: 8),
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.3)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundImage: NetworkImage(profileImage),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                GestureDetector(
                                                  onTap: () => ProfileNavigator.navigateToProfile(context, authorId),
                                                  child: Text(
                                                    authorName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                _buildClickableText(context, commentText),
                                                const SizedBox(height: 6),
                                                Text(
                                                  timeago.format(timestamp),
                                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () {
                                                        if (pendingLikeOps.contains(commentId) || isPostAuthorBlocked) return;
                                                        final wasLiked = displayedIsLiked;
                                                        setStateInDialog(() {
                                                          pendingLikeOps.add(commentId);
                                                          localCommentLikedOverride[commentId] = !wasLiked;
                                                          localCommentLikeCountOverride[commentId] = displayedLikeCount + (wasLiked ? -1 : 1);
                                                        });

                                                        _toggleCommentLike(postId, commentId, wasLiked).whenComplete(() {
                                                          setStateInDialog(() {
                                                            pendingLikeOps.remove(commentId);
                                                          });
                                                        }).catchError((_) {
                                                          setStateInDialog(() {
                                                            localCommentLikedOverride[commentId] = wasLiked;
                                                            localCommentLikeCountOverride[commentId] = displayedLikeCount;
                                                            pendingLikeOps.remove(commentId);
                                                          });
                                                        });
                                                      },
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            displayedIsLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                                            size: 14,
                                                            color: displayedIsLiked ? Colors.blue : Colors.grey,
                                                          ),
                                                          Padding(
                                                            padding: const EdgeInsets.only(left: 4.0),
                                                            child: Text('$displayedLikeCount', style: const TextStyle(fontSize: 12)),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    GestureDetector(
                                                      onTap: () {
                                                        if (isPostAuthorBlocked) return;
                                                        setReplyTarget('posts/$postId/comments/$commentId', authorHandle, authorId, commentText);
                                                        setStateInDialog(() {
                                                          commentReplySectionVisibility[commentId] = true;
                                                        });
                                                      },
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.reply, size: 14, color: Colors.grey),
                                                          const SizedBox(width: 4),
                                                          const Text('Reply', style: TextStyle(fontSize: 12)),
                                                          if (commentReplyCount > 0) ...[
                                                            const SizedBox(width: 4),
                                                            Text('($commentReplyCount)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                          ]
                                                        ],
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    PopupMenuButton<String>(
                                                      onSelected: (value) async {
                                                        if (value == 'edit') {
                                                          final TextEditingController editController =
                                                          TextEditingController(text: data['text']);
                                                          final result = await showDialog<String>(
                                                            context: context,
                                                            builder: (context) {
                                                              return AlertDialog(
                                                                title: const Text('Edit Comment'),
                                                                content: TextField(
                                                                  controller: editController,
                                                                  maxLines: 3,
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () => Navigator.pop(context),
                                                                    child: const Text('Cancel'),
                                                                  ),
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(context, editController.text.trim()),
                                                                    child: const Text('Save'),
                                                                  ),
                                                                ],
                                                              );
                                                            },
                                                          );
                                                          if (result != null && result.isNotEmpty) {
                                                            await _firestore
                                                                .collection('posts')
                                                                .doc(postId)
                                                                .collection('comments')
                                                                .doc(commentId)
                                                                .update({'text': result});
                                                          }
                                                        } else if (value == 'report') {
                                                          final TextEditingController reportReason = TextEditingController();
                                                          final reason = await showDialog<String>(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              title: const Text('Report Comment'),
                                                              content: TextField(
                                                                controller: reportReason,
                                                                maxLines: 3,
                                                                decoration: const InputDecoration(
                                                                  hintText: 'Why are you reporting this comment?',
                                                                ),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context),
                                                                  child: const Text('Cancel'),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context, reportReason.text),
                                                                  child: const Text('Report'),
                                                                ),
                                                              ],
                                                            ),
                                                          );

                                                          if (reason != null && reason.isNotEmpty) {
                                                            try {
                                                              // Show loading feedback
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(
                                                                  content: Row(
                                                                    children: [
                                                                      CircularProgressIndicator(color: Colors.white),
                                                                      SizedBox(width: 16),
                                                                      Text('Submitting report...'),
                                                                    ],
                                                                  ),
                                                                  duration: Duration(seconds: 2),
                                                                  backgroundColor: Colors.blueAccent,
                                                                ),
                                                              );

                                                              await _firestore.collection('CommentReports').add({
                                                                'postId': postId,
                                                                'commentId': commentId,
                                                                'reporterId': currentUser?.uid,
                                                                'reason': reason,
                                                                'timestamp': FieldValue.serverTimestamp(),
                                                                'status': 'pending',
                                                              });

                                                              // Close dialog first, then show success confirmation
                                                              Navigator.of(context).pop();
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text('Comment reported for review. Thank you!'),
                                                                  backgroundColor: Colors.green,
                                                                  duration: Duration(seconds: 4),
                                                                ),
                                                              );
                                                            } catch (e) {
                                                              print('Error reporting comment: $e');
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text('Failed to report comment. Please try again later.'),
                                                                  backgroundColor: Colors.red,
                                                                  duration: Duration(seconds: 5),
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        }else if (value == 'delete') {
                                                          final confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              title: const Text('Confirm Deletion'),
                                                              content: const Text('Are you sure you want to delete this comment?'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context, false),
                                                                  child: const Text('Cancel'),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context, true),
                                                                  child: const Text('Delete'),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          if (confirm == true) {
                                                            try {
                                                              // Delete the comment document
                                                              await _firestore
                                                                  .collection('posts')
                                                                  .doc(postId)
                                                                  .collection('comments')
                                                                  .doc(commentId)
                                                                  .delete();

                                                              // Update the post's comment count
                                                              await _firestore
                                                                  .collection('posts')
                                                                  .doc(postId)
                                                                  .update({'commentCount': FieldValue.increment(-1)});

                                                              // Update local counter
                                                              commentCountNotifier.value =
                                                              (commentCountNotifier.value - 1) >= 0 ?
                                                              commentCountNotifier.value - 1 : 0;

                                                              if (onCommentDeleted != null) {
                                                                onCommentDeleted();
                                                              }
                                                            } catch (e) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Failed to delete comment: $e')),
                                                              );
                                                            }
                                                          }
                                                          // Replace the existing placeholder implementations in your popup menu onSelected callback:

                                                        } else if (value == 'hide') {
                                                          try {
                                                            await hideComment(postId, commentId);
                                                            Navigator.of(context).pop(); // Close dialog first
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(
                                                                content: Text('Comment has been hidden.'),
                                                                backgroundColor: Colors.green,
                                                              ),
                                                            );
                                                          } catch (e) {
                                                            Navigator.of(context).pop(); // Close dialog first
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(
                                                                content: Text('Failed to hide comment. Please try again.'),
                                                                backgroundColor: Colors.red,
                                                              ),
                                                            );
                                                          }
                                                        } else if (value == 'mute') {
                                                          final confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              title: const Text('Mute User'),
                                                              content: Text('Are you sure you want to mute $authorName? You won\'t see their comments anymore.'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context, false),
                                                                  child: const Text('Cancel'),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context, true),
                                                                  child: const Text('Mute'),
                                                                ),
                                                              ],
                                                            ),
                                                          );

                                                          if (confirm == true) {
                                                            try {
                                                              await muteUserFromComment(authorId);
                                                              Navigator.of(context).pop(); // Close comments dialog first
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text('$authorName has been muted.'),
                                                                  backgroundColor: Colors.orange,
                                                                ),
                                                              );
                                                            } catch (e) {
                                                              Navigator.of(context).pop(); // Close comments dialog first
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text('Failed to mute user. Please try again.'),
                                                                  backgroundColor: Colors.red,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        } else if (value == 'block') {
                                                          final confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              title: const Text('Block User'),
                                                              content: Text('Are you sure you want to block $authorName? They won\'t be able to follow you or see your posts.'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context, false),
                                                                  child: const Text('Cancel'),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context, true),
                                                                  child: const Text('Block'),
                                                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                                ),
                                                              ],
                                                            ),
                                                          );

                                                          if (confirm == true) {
                                                            try {
                                                              await blockUserFromComment(authorId);
                                                              Navigator.of(context).pop(); // Close comments dialog first
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text('$authorName has been blocked.'),
                                                                  backgroundColor: Colors.red,
                                                                ),
                                                              );
                                                            } catch (e) {
                                                              Navigator.of(context).pop(); // Close comments dialog first
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text('Failed to block user. Please try again.'),
                                                                  backgroundColor: Colors.red,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        }
                                                      },
                                                      itemBuilder: (context) {
                                                        final isOwnComment = authorId == currentUser?.uid;
                                                        return [
                                                          if (isOwnComment)
                                                            const PopupMenuItem(
                                                              value: 'edit',
                                                              child: Text('Edit'),
                                                            ),
                                                          if (isOwnComment)
                                                            const PopupMenuItem(
                                                              value: 'delete',
                                                              child: Text('Delete'),
                                                            ),
                                                          if (!isOwnComment)
                                                            const PopupMenuItem(
                                                              value: 'report',
                                                              child: Text('Report'),
                                                            ),
                                                          if (!isOwnComment)
                                                            const PopupMenuItem(
                                                              value: 'hide',
                                                              child: Text('Hide Comment'),
                                                            ),
                                                          if (!isOwnComment)
                                                            const PopupMenuItem(
                                                              value: 'mute',
                                                              child: Text('Mute User'),
                                                            ),
                                                          if (!isOwnComment)
                                                            const PopupMenuItem(
                                                              value: 'block',
                                                              child: Text('Block User'),
                                                            ),
                                                        ];
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (commentReplySectionVisibility[commentId] ?? false)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 20.0),
                                      child: ReplyWidget(
                                        parentPath: 'posts/$postId/comments/$commentId',
                                        postId: postId,
                                        isVisible: commentReplySectionVisibility[commentId] ?? false,
                                        onReplySelected: setReplyTarget,
                                        isPostAuthorBlocked: isPostAuthorBlocked,
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (isPostAuthorBlocked)
                      const SizedBox.shrink()
                    else
                      StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection('posts').doc(postId).snapshots(),
                        builder: (context, postSnapshot) {
                          if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }

                          final postData = postSnapshot.data!.data() as Map<String, dynamic>?;
                          final bool commentsAreEnabled = postData?['commentsEnabled'] ?? true;

                          if (!commentsAreEnabled) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: mainCommentController,
                                    focusNode: mainCommentFocusNode,
                                    decoration: InputDecoration(
                                      hintText: 'Add a comment...', // This line is simplified
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    keyboardType: TextInputType.multiline,
                                    minLines: 1,
                                    maxLines: 5,
                                    textCapitalization: TextCapitalization.sentences,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send),
                                  color: Colors.blue,
                                  onPressed: () async {
                                    final text = mainCommentController.text;
                                    final replyTarget = currentReplyTarget.value;

                                    if (text.trim().isNotEmpty) {
                                      // Check if comments are still enabled before submitting
                                      final commentsEnabled = await _areCommentsEnabled(postId);
                                      if (!commentsEnabled) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Comments are disabled for this post.')),
                                        );
                                        return;
                                      }

                                      try {
                                        if (replyTarget == null) {
                                          await _addComment(text, postId, postAuthorId, postContent, commentCountNotifier);
                                        } else {
                                          await _addReplyToParent(
                                            text.replaceFirst('@${replyTarget['author']} ', '').trim(),
                                            replyTarget['path']!,
                                            postId,
                                            replyTarget['authorId']!,
                                            replyTarget['text']!,
                                            replyTarget['path']!.split('/').last,
                                          );
                                        }
                                        mainCommentController.clear();
                                        currentReplyTarget.value = null;
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to add comment: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      mainCommentFocusNode.dispose();
      currentReplyTarget.dispose();
      mainCommentController.dispose();
    });
  }

// Add these static methods to your CommentInteractions class

  /// Hides a specific comment for the current user.
  /// This function adds the [commentId] to the current user's 'hiddenComments' subcollection.
  static Future<void> hideComment(String postId, String commentId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('hiddenComments')
          .doc('${postId}_$commentId')
          .set({
        'postId': postId,
        'commentId': commentId,
        'timestamp': FieldValue.serverTimestamp()
      });
    } catch (e) {
      print('Error hiding comment: $e');
      rethrow;
    }
  }

  /// Mutes a user from comments, preventing their comments from showing up.
  /// This function adds the [targetUserId] to the current user's 'mutedUsers' subcollection.
  static Future<void> muteUserFromComment(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('mutedUsers')
          .doc(targetUserId)
          .set({'timestamp': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error muting user: $e');
      rethrow;
    }
  }

  /// Blocks a user, preventing them from seeing the current user's profile and posts.
  /// Uses the same top-level 'Blocks' collection strategy as PostInteractions.
  static Future<void> blockUserFromComment(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // 1. Add the user to the current user's 'blocked' array in the 'Blocks' collection.
      await _firestore.collection('Blocks').doc(currentUser.uid).set({
        'blocked': FieldValue.arrayUnion([targetUserId])
      }, SetOptions(merge: true));

      // 2. Remove the blocked user from the current user's followers list.
      await _firestore.collection('Friends').doc(currentUser.uid).update({
        'followersMetadata.$targetUserId': FieldValue.delete()
      });

      // 3. Remove the current user from the blocked user's following list.
      await _firestore.collection('Friends').doc(targetUserId).update({
        'followingMetadata.${currentUser.uid}': FieldValue.delete()
      });

      // 4. Delete any follower notifications related to this user.
      final notificationQuery = await _firestore.collection('notifications')
          .where('recipientId', isEqualTo: currentUser.uid)
          .where('senderId', isEqualTo: targetUserId)
          .where('type', isEqualTo: 'new_follower')
          .get();

      final WriteBatch batch = _firestore.batch();
      for (final doc in notificationQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error blocking user: $e');
      rethrow;
    }
  }
}