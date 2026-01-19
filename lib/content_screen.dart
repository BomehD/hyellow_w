import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/post_widget.dart';
import 'dart:async';
import 'package:hyellow_w/edit_post_screen.dart';

class ContentScreen extends StatefulWidget {
  final String userId; // The ID of the user whose content is being displayed

  const ContentScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _ContentScreenState createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  Map<String, dynamic> userProfileData = {};
  String? profileImageUrl;
  Set<String> likedPostIds = {};
  Set<String> _followingIds = {};
  bool _isDataLoading = true;

  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _profileSubscription;
  StreamSubscription<DocumentSnapshot>? _friendsSubscription;
  StreamSubscription<QuerySnapshot>? _likedPostsSubscription;
  StreamSubscription<QuerySnapshot>? _postsSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeStreams();
  }

  void _setupRealtimeStreams() {
    _cleanupSubscriptions();

    setState(() => _isDataLoading = true);

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
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
        .doc(widget.userId)
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

    if (_currentUserId != null) {
      _friendsSubscription = FirebaseFirestore.instance
          .collection('Friends')
          .doc(_currentUserId)
          .snapshots()
          .listen((friendsDoc) {
        final Map<String, dynamic> followingMetadata = friendsDoc.exists
            ? (friendsDoc.data()?['followingMetadata'] ?? {})
            : {};
        final newFollowingIds = followingMetadata.keys.toSet();
        if (!_setEquals(_followingIds, newFollowingIds) && mounted) {
          setState(() {
            _followingIds = newFollowingIds;
          });
        }
      });

      _likedPostsSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('likes')
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          final newLikedPostIds = snapshot.docs.map((doc) => doc.id).toSet();
          setState(() {
            likedPostIds = newLikedPostIds;
          });
        }
      });
    }

    _postsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('authorId', isEqualTo: widget.userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
      }
    });
  }

  bool _setEquals<T>(Set<T> set1, Set<T> set2) {
    if (set1.length != set2.length) return false;
    for (var item in set1) {
      if (!set2.contains(item)) return false;
    }
    return true;
  }

  void _cleanupSubscriptions() {
    _userSubscription?.cancel();
    _profileSubscription?.cancel();
    _friendsSubscription?.cancel();
    _likedPostsSubscription?.cancel();
    _postsSubscription?.cancel();
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

  // FIX: Update function signature to accept imageUrls
  void _navigateToEditPost(
      String postId,
      String content,
      String? imageUrl,
      String? videoUrl,
      List<String>? imageUrls, // FIX: New parameter
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(
          postId: postId,
          initialContent: content,
          initialImageUrl: imageUrl,
          initialVideoUrl: videoUrl,
          initialImageUrls: imageUrls, // FIX: Pass the imageUrls list
        ),
      ),
    );
  }

  void _handlePostAction() {
    print("🔄 Post action detected - streams will handle updates");
  }

  @override
  Widget build(BuildContext context) {
    final bool isViewingOwnProfile = (_currentUserId != null && _currentUserId == widget.userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Posts',
          style: TextStyle(
            color: Color(0xFF106C70),
            fontSize: 13,
          ),
        ),
      ),
      body: _isDataLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('authorId', isEqualTo: widget.userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts available.'));
          }

          final List<DocumentSnapshot> allPosts = snapshot.data!.docs;
          final List<DocumentSnapshot> filteredPosts = [];

          for (var postDoc in allPosts) {
            final postData = postDoc.data() as Map<String, dynamic>;
            final String visibility = postData['visibility'] ?? 'public';
            final String authorId = postData['authorId'] as String;

            bool shouldShow = false;
            if (isViewingOwnProfile) {
              shouldShow = true;
            } else {
              if (visibility == 'public') {
                shouldShow = true;
              } else if (visibility == 'followers') {
                if (_currentUserId != null && _followingIds.contains(authorId)) {
                  shouldShow = true;
                }
              }
            }

            if (shouldShow) {
              filteredPosts.add(postDoc);
            }
          }

          if (filteredPosts.isEmpty) {
            return const Center(child: Text('No public or accessible posts available.'));
          }

          return ListView.builder(
            itemCount: filteredPosts.length,
            itemBuilder: (context, index) {
              final postDoc = filteredPosts[index];
              final postData = postDoc.data() as Map<String, dynamic>;
              final postId = postDoc.id;

              final List<String>? imageUrls = (postData['imageUrls'] as List<dynamic>?)
                  ?.map((item) => item.toString())
                  .toList();

              return PostWidget(
                key: ValueKey(postId),
                postId: postId,
                authorId: postData['authorId'] ?? '',
                userId: _currentUserId ?? '',
                postContent: postData['content'] ?? '',
                imageUrl: postData['imageUrl'],
                imageUrls: imageUrls,
                videoUrl: postData['videoUrl'],
                interest: postData['interest'] ?? 'General',
                timestamp: postData['timestamp'] ?? Timestamp.now(),
                authorName: userProfileData['name'] ?? 'Unknown',
                profileImageUrl: profileImageUrl,
                likeCount: postData['likeCount'] ?? 0,
                commentCount: postData['commentCount'] ?? 0,
                initiallyLiked: likedPostIds.contains(postId),
                postVisibility: postData['visibility'] ?? 'public',
                areCommentsEnabled: postData['commentsEnabled'] ?? true,
                authorAbout: userProfileData['about'] ?? '',
                authorTitle: userProfileData['title'] ?? '',
                authorPhone: userProfileData['phone'] ?? '',
                authorEmail: userProfileData['email'] ?? '',
                // Pass the delete callback ONLY if viewing their own profile
                onDelete: isViewingOwnProfile ? _deletePost : null,
                onPostEdited: _handlePostAction,
                onPostHidden: _handlePostAction,
                onUserMuted: _handlePostAction,
                onUserBlocked: _handlePostAction,
                // FIX: Only provide the onEditPost callback if it's the current user's post
                onEditPost: isViewingOwnProfile
                    ? () => _navigateToEditPost(
                  postId,
                  postData['content'] as String? ?? '',
                  postData['imageUrl'] as String?,
                  postData['videoUrl'] as String?,
                  imageUrls,
                )
                    : null,
                isBlockedByAuthor: false,
              );
            },
          );
        },
      ),
    );
  }
}