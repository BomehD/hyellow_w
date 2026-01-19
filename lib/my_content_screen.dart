import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/post_widget.dart';
import 'dart:async';
import 'package:hyellow_w/edit_post_screen.dart';

class MyContentScreen extends StatefulWidget {
  @override
  _MyContentScreenState createState() => _MyContentScreenState();
}

class _MyContentScreenState extends State<MyContentScreen> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic> userProfileData = {};
  String? profileImageUrl;
  bool isLoading = true;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    if (userId != null) {
      _setupRealtimeStreams();
    } else {
      setState(() => isLoading = false);
    }
  }

  void _setupRealtimeStreams() {
    _cleanupSubscriptions();

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists && mounted) {
        setState(() {
          userProfileData.addAll(userDoc.data() as Map<String, dynamic>);
        });
      }
    });

    _profileSubscription = FirebaseFirestore.instance
        .collection('profiles')
        .doc(userId)
        .snapshots()
        .listen((profileDoc) {
      if (profileDoc.exists && mounted) {
        setState(() {
          profileImageUrl = profileDoc.data()?['profileImage'];
          userProfileData['about'] = profileDoc.data()?['about'] ?? '';
          userProfileData['title'] = profileDoc.data()?['title'] ?? '';
          userProfileData['phone'] = profileDoc.data()?['phone'] ?? '';
          userProfileData['email'] = profileDoc.data()?['email'] ?? '';
        });
      }
    });

    setState(() => isLoading = false);
  }

  void _cleanupSubscriptions() {
    _userSubscription?.cancel();
    _profileSubscription?.cancel();
  }

  @override
  void dispose() {
    _cleanupSubscriptions();
    super.dispose();
  }

  void _deletePost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $e')),
      );
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

  void _handlePostAction() {
    print("🔄 Post action detected - streams will handle updates");
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Activity',
          style: TextStyle(
            color: Color(0xFF106C70),
            fontSize: 13,
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('authorId', isEqualTo: userId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No posts available.'));
              }

              final posts = snapshot.data!.docs;

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final postDoc = posts[index];
                  final post =
                  postDoc.data() as Map<String, dynamic>;
                  final postId = postDoc.id;

                  final List<String>? imageUrls =
                  (post['imageUrls'] as List<dynamic>?)
                      ?.map((item) => item.toString())
                      .toList();

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .collection('likes')
                        .doc(userId)
                        .get(),
                    builder: (context, likeSnapshot) {
                      final hasLiked =
                          likeSnapshot.data?.exists ?? false;

                      return PostWidget(
                        key: ValueKey(postId),
                        postId: postId,
                        authorId: post['authorId'] ?? '',
                        userId: userId!,
                        postContent: post['content'] ?? '',
                        imageUrl: post['imageUrl'],
                        imageUrls: imageUrls,
                        videoUrl: post['videoUrl'],
                        interest: post['interest'] ?? 'General',
                        timestamp:
                        post['timestamp'] ?? Timestamp.now(),
                        authorName:
                        userProfileData['name'] ?? 'Unknown',
                        profileImageUrl: profileImageUrl,
                        likeCount: post['likeCount'] ?? 0,
                        commentCount: post['commentCount'] ?? 0,
                        initiallyLiked: hasLiked,
                        postVisibility:
                        post['visibility'] ?? 'public',
                        areCommentsEnabled:
                        post['commentsEnabled'] ?? true,
                        authorAbout:
                        userProfileData['about'] ?? '',
                        authorTitle:
                        userProfileData['title'] ?? '',
                        authorPhone:
                        userProfileData['phone'] ?? '',
                        authorEmail:
                        userProfileData['email'] ?? '',
                        onDelete: _deletePost,
                        onPostEdited: _handlePostAction,
                        onPostHidden: _handlePostAction,
                        onUserMuted: _handlePostAction,
                        onUserBlocked: _handlePostAction,
                        onEditPost: () => _navigateToEditPost(
                          postId,
                          post['content'] as String? ?? '',
                          post['imageUrl'] as String?,
                          post['videoUrl'] as String?,
                          imageUrls,
                        ),
                        isBlockedByAuthor: false,
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
