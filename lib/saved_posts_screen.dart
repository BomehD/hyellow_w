import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/post_widget.dart';
import 'package:hyellow_w/edit_post_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({Key? key}) : super(key: key);

  @override
  _SavedPostsScreenState createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Set<String> _usersWhoBlockedMe = {};
  bool _isLoadingBlockedUsers = true;

  @override
  void initState() {
    super.initState();
    if (currentUserId != null) {
      _loadUsersWhoBlockedMe();
    }
  }

  Future<void> _loadUsersWhoBlockedMe() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final querySnapshot =
      await FirebaseFirestore.instance.collection('Blocks').get();

      final newBlockedMeSet = <String>{};
      for (var doc in querySnapshot.docs) {
        final blockedIds = (doc.data()['blocked'] as List<dynamic>?);
        if (blockedIds != null && blockedIds.contains(currentUserId)) {
          newBlockedMeSet.add(doc.id);
        }
      }

      if (mounted) {
        setState(() {
          _usersWhoBlockedMe = newBlockedMeSet;
          _isLoadingBlockedUsers = false;
        });
        print("🚫 Users who blocked me loaded: $_usersWhoBlockedMe");
      }
    } catch (e) {
      print("Error loading users who blocked me: $e");
      if (mounted) {
        setState(() {
          _isLoadingBlockedUsers = false;
        });
      }
    }
  }

  void _navigateToEditPost(
      String postId,
      String content,
      String? imageUrl,
      String? videoUrl,
      List<String>? imageUrls,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(
          postId: postId,
          initialContent: content,
          initialImageUrl: imageUrl,
          initialVideoUrl: videoUrl,
          initialImageUrls: imageUrls,
        ),
      ),
    );
  }

  double _getContentWidth(double screenWidth) {
    if (screenWidth >= 1200) {
      return 600;
    } else if (screenWidth >= 800) {
      return screenWidth * 0.65;
    } else {
      return screenWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor:
          Theme.of(context).appBarTheme.backgroundColor ?? colors.surface,
          title: Text(
            "Saved Posts",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : colors.primary,
            ),
          ),
        ),
        body: Center(
          child: Text(
            "Please log in to view your saved posts.",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      );
    }

    if (_isLoadingBlockedUsers) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor:
          Theme.of(context).appBarTheme.backgroundColor ?? colors.surface,
          title: Text(
            "Saved Posts",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : colors.primary,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
        Theme.of(context).appBarTheme.backgroundColor ?? colors.surface,
        title: Text(
          "Saved Posts",
          style: TextStyle(
            color: Color(0xFF106C70),
            fontSize: 13,
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .collection('bookmarks')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border_outlined,
                        size: 60,
                        color: colors.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No saved posts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save posts you like to view them here later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final savedBookmarks = snapshot.data!.docs;

              return ListView.builder(
                itemCount: savedBookmarks.length,
                itemBuilder: (context, index) {
                  final bookmarkDoc = savedBookmarks[index];
                  final postId = bookmarkDoc.id;

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .snapshots(),
                    builder: (context, postSnapshot) {
                      if (postSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }

                      if (!postSnapshot.hasData ||
                          !postSnapshot.data!.exists) {
                        Future.microtask(() async {
                          if (mounted) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUserId)
                                  .collection('bookmarks')
                                  .doc(postId)
                                  .delete();
                              print(
                                  'Cleaned up orphaned bookmark for post: $postId');
                            } catch (e) {
                              print(
                                  'Error cleaning up bookmark for post $postId: $e');
                            }
                          }
                        });
                        return const SizedBox.shrink();
                      }

                      final postData =
                      postSnapshot.data!.data() as Map<String, dynamic>;
                      final authorId = postData['authorId'] as String;

                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(authorId)
                            .snapshots(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting ||
                              !userSnapshot.hasData ||
                              !userSnapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }

                          final userData = userSnapshot.data!.data()
                          as Map<String, dynamic>?;
                          final authorName = userData?['name'] ?? 'Unknown';
                          final authorInterest =
                              userData?['interest'] ?? 'General';

                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('profiles')
                                .doc(authorId)
                                .snapshots(),
                            builder: (context, profileSnapshot) {
                              if (profileSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }

                              final profileData = profileSnapshot.data?.data()
                              as Map<String, dynamic>?;
                              final profileImageUrl =
                              profileData?['profileImage'];
                              final authorAbout = profileData?['about'] ?? '';
                              final authorTitle = profileData?['title'] ?? '';
                              final authorPhone = profileData?['phone'] ?? '';
                              final authorEmail = profileData?['email'] ?? '';

                              final isBlockedByAuthor =
                              _usersWhoBlockedMe.contains(authorId);
                              final List<String>? imageUrls =
                              (postData['imageUrls'] as List<dynamic>?)
                                  ?.cast<String>();

                              return PostWidget(
                                key: ValueKey(postId),
                                postId: postId,
                                authorId: authorId,
                                userId: currentUserId!,
                                postContent: postData['content'] ?? '',
                                imageUrl: postData['imageUrl'],
                                imageUrls: imageUrls,
                                videoUrl: postData['videoUrl'],
                                interest: authorInterest,
                                timestamp:
                                postData['timestamp'] ?? Timestamp.now(),
                                authorName: authorName,
                                profileImageUrl: profileImageUrl,
                                likeCount: postData['likeCount'] ?? 0,
                                commentCount: postData['commentCount'] ?? 0,
                                initiallyLiked: false,
                                initiallyBookmarked: true,
                                postVisibility:
                                postData['visibility'] ?? 'public',
                                areCommentsEnabled:
                                postData['commentsEnabled'] ?? true,
                                authorAbout: authorAbout,
                                authorTitle: authorTitle,
                                authorPhone: authorPhone,
                                authorEmail: authorEmail,
                                onDelete: (deletedPostId) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Post deleted successfully.')),
                                  );
                                },
                                onPostEdited: () {},
                                onPostHidden: () {},
                                onUserMuted: () {},
                                onUserBlocked: () {},
                                onEditPost: () => _navigateToEditPost(
                                  postId,
                                  postData['content'] as String? ?? '',
                                  postData['imageUrl'] as String?,
                                  postData['videoUrl'] as String?,
                                  imageUrls,
                                ),
                                isBlockedByAuthor: isBlockedByAuthor,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
