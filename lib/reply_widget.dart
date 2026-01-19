import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/profile_navigator.dart' as ProfileNavigator;
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter/gestures.dart';

class ReplyWidget extends StatefulWidget {
  final String postId;
  final String parentPath;
  final bool isVisible;
  final bool isPostAuthorBlocked;
  final Function(String parentPath, String parentAuthorHandle, String authorId, String parentText) onReplySelected;

  const ReplyWidget({
    super.key,
    required this.postId,
    required this.parentPath,
    required this.isVisible,
    required this.onReplySelected,
    required this.isPostAuthorBlocked,
  });

  @override
  State<ReplyWidget> createState() => _ReplyWidgetState();
}

class _ReplyWidgetState extends State<ReplyWidget> {
  final Map<String, bool> _nestedReplyVisibility = {};
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, bool> _localLikedOverride = {};
  final Map<String, int> _localLikeCountOverride = {};
  final Set<String> _pendingLikeOps = {};
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  // Helper to build clickable text with mentions - consistent with CommentInteractions
  Widget _buildClickableText(BuildContext context, String text) {
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
                  try {
                    final userSnap = await FirebaseFirestore.instance
                        .collection('users')
                        .where('handle', isEqualTo: handle)
                        .limit(1)
                        .get();
                    if (userSnap.docs.isNotEmpty) {
                      final mentionedUserId = userSnap.docs.first.id;
                      ProfileNavigator.navigateToProfile(context, mentionedUserId);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User not found.')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error finding user.')),
                    );
                  }
                }
              },
          ),
        );
        return '';
      },
      onNonMatch: (nm) {
        spans.add(TextSpan(text: nm, style: const TextStyle(color: Colors.black)));
        return '';
      },
    );

    return RichText(text: TextSpan(children: spans));
  }

  // Improved user data fetching with caching
  Future<Map<String, dynamic>> _fetchCombinedUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final userDocFuture = FirebaseFirestore.instance.collection('users').doc(userId).get();
      final profileDocFuture = FirebaseFirestore.instance.collection('profiles').doc(userId).get();

      final List<DocumentSnapshot> results = await Future.wait([userDocFuture, profileDocFuture]);

      final userDoc = results[0];
      final profileDoc = results[1];

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final profileData = profileDoc.data() as Map<String, dynamic>? ?? {};

      final combinedData = {
        'name': userData['name'] ?? 'Unknown',
        'handle': userData['handle'] ?? 'unknown_handle',
        'profileImage': profileData['profileImage'] ?? 'https://via.placeholder.com/150',
      };

      _userCache[userId] = combinedData;
      return combinedData;
    } catch (e) {
      final fallbackData = {
        'name': 'Unknown',
        'handle': 'unknown_handle',
        'profileImage': 'https://via.placeholder.com/150',
      };
      _userCache[userId] = fallbackData;
      return fallbackData;
    }
  }

  // Improved like toggle with optimistic updates and error handling
  Future<void> _toggleReplyLike({
    required String replyPath,
    required String replyId,
    required bool currentlyLiked,
    required int currentLikeCount,
  }) async {
    final userId = _currentUser?.uid;
    if (userId == null || widget.isPostAuthorBlocked) return;

    if (_pendingLikeOps.contains(replyId)) return;

    setState(() {
      _pendingLikeOps.add(replyId);
      _localLikedOverride[replyId] = !currentlyLiked;
      _localLikeCountOverride[replyId] = currentLikeCount + (currentlyLiked ? -1 : 1);
    });

    try {
      final DocumentReference replyRef = FirebaseFirestore.instance.doc(replyPath);

      if (currentlyLiked) {
        await replyRef.update({
          'likes': FieldValue.arrayRemove([userId]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await replyRef.update({
          'likes': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _localLikedOverride[replyId] = currentlyLiked;
          _localLikeCountOverride[replyId] = currentLikeCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingLikeOps.remove(replyId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .doc(widget.parentPath)
          .collection('replies')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error loading replies: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final replies = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: replies.length,
          itemBuilder: (context, index) {
            final doc = replies[index];
            final data = doc.data() as Map<String, dynamic>;
            final text = data['text'] ?? '';
            final authorId = data['authorId'] ?? '';
            final timestamp = data['timestamp']?.toDate() ?? DateTime.now();
            final serverLikes = List<String>.from(data['likes'] ?? []);
            final serverLikeCount = data['likeCount'] ?? serverLikes.length;
            final currentReplyNestedCount = data['replyCount'] ?? 0;
            final replyId = doc.id;
            final replyPath = '${widget.parentPath}/replies/$replyId';

            // Check server like status
            final serverIsLiked = _currentUser != null && serverLikes.contains(_currentUser!.uid);

            // Apply local overrides for optimistic updates
            final displayedIsLiked = _localLikedOverride.containsKey(replyId)
                ? _localLikedOverride[replyId]!
                : serverIsLiked;
            final displayedLikeCount = _localLikeCountOverride.containsKey(replyId)
                ? _localLikeCountOverride[replyId]!
                : serverLikeCount;

            _nestedReplyVisibility.putIfAbsent(replyId, () => false);

            return FutureBuilder<Map<String, dynamic>>(
              future: _fetchCombinedUserData(authorId),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final combinedUserData = userSnapshot.data!;
                final profileImage = combinedUserData['profileImage'];
                final authorName = combinedUserData['name'];
                final authorHandle = combinedUserData['handle'];

                return Column(
                  key: ValueKey('reply_$replyId'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _nestedReplyVisibility[replyId] = !(_nestedReplyVisibility[replyId] ?? false);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: NetworkImage(profileImage),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => ProfileNavigator.navigateToProfile(context, authorId),
                                    child: Text(
                                      authorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  _buildClickableText(context, text),
                                  const SizedBox(height: 6),
                                  Text(
                                    timeago.format(timestamp),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: widget.isPostAuthorBlocked || _pendingLikeOps.contains(replyId)
                                            ? null
                                            : () {
                                          _toggleReplyLike(
                                            replyPath: replyPath,
                                            replyId: replyId,
                                            currentlyLiked: displayedIsLiked,
                                            currentLikeCount: displayedLikeCount,
                                          );
                                        },
                                        child: Row(
                                          children: [
                                            Icon(
                                              displayedIsLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                              size: 14,
                                              color: displayedIsLiked ? Colors.blue : Colors.grey,
                                            ),
                                            if (displayedLikeCount > 0) ...[
                                              const SizedBox(width: 4),
                                              Text('$displayedLikeCount', style: const TextStyle(fontSize: 12)),
                                            ]
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      if (_currentUser != null)
                                        GestureDetector(
                                          onTap: widget.isPostAuthorBlocked ? null : () {
                                            widget.onReplySelected(
                                              replyPath,
                                              authorHandle,
                                              authorId,
                                              text,
                                            );

                                            setState(() {
                                              _nestedReplyVisibility[replyId] = true;
                                            });
                                          },
                                          child: Row(
                                            children: [
                                              const Icon(Icons.reply, size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              const Text('Reply', style: TextStyle(fontSize: 12)),
                                              if (currentReplyNestedCount > 0) ...[
                                                const SizedBox(width: 4),
                                                Text('($currentReplyNestedCount)',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                                              ]
                                            ],
                                          ),
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
                    // Nested replies with proper indentation
                    if (_nestedReplyVisibility[replyId] ?? false)
                      ReplyWidget(
                        postId: widget.postId,
                        parentPath: replyPath,
                        isVisible: _nestedReplyVisibility[replyId] ?? false,
                        onReplySelected: widget.onReplySelected,
                        isPostAuthorBlocked: widget.isPostAuthorBlocked,
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
