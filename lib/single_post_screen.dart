import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'post_widget.dart';
import 'package:hyellow_w/edit_post_screen.dart';

class SinglePostScreen extends StatefulWidget {
  final String postId;
  final String authorId;
  final String postContent;
  final String interest;
  final String? imageUrl;
  final List<String>? imageUrls; // FIX: Add this new parameter
  final String? videoUrl;
  final Timestamp timestamp;
  final String authorName;
  final String? profileImageUrl;
  final int likeCount;
  final int commentCount;
  final String postVisibility;
  final bool areCommentsEnabled;
  final String authorAbout;
  final String authorTitle;
  final String authorPhone;
  final String authorEmail;

  const SinglePostScreen({
    super.key,
    required this.postId,
    required this.authorId,
    required this.postContent,
    required this.interest,
    this.imageUrl,
    this.imageUrls,
    this.videoUrl,
    required this.timestamp,
    required this.authorName,
    this.profileImageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.postVisibility,
    required this.areCommentsEnabled,
    required this.authorAbout,
    required this.authorTitle,
    required this.authorPhone,
    required this.authorEmail,
  });

  @override
  State<SinglePostScreen> createState() => _SinglePostScreenState();
}

class _SinglePostScreenState extends State<SinglePostScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;

  late int _currentLikeCount;
  late int _currentCommentCount;
  bool _isLiked = false;

  // NEW: State for blocking information
  Set<String> _usersWhoBlockedMe = {};
  bool _isLoadingBlockedUsers = true;

  StreamSubscription<DocumentSnapshot>? _postSubscription;
  StreamSubscription<DocumentSnapshot>? _likeSubscription;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;

    _currentLikeCount = widget.likeCount;
    _currentCommentCount = widget.commentCount;

    if (_currentUserId != null) {
      _setupRealtimeStreams();
      // NEW: Load the list of users who have blocked the current user
      _loadUsersWhoBlockedMe();
    } else {
      // If no user, we are done loading
      _isLoadingBlockedUsers = false;
    }
  }

  // NEW: Function to load users who have blocked the current user.
  Future<void> _loadUsersWhoBlockedMe() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Blocks')
          .get();

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
        print("🚫 Users who blocked me loaded for single post screen: $_usersWhoBlockedMe");
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

  void _setupRealtimeStreams() {
    _postSubscription = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .snapshots()
        .listen((postDoc) {
      if (postDoc.exists && mounted) {
        final data = postDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentLikeCount = data['likeCount'] ?? 0;
          _currentCommentCount = data['commentCount'] ?? 0;
        });
      }
    });

    _likeSubscription = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('likes')
        .doc(_currentUserId)
        .snapshots()
        .listen((likeDoc) {
      if (mounted) {
        setState(() {
          _isLiked = likeDoc.exists;
        });
      }
    });
  }

  @override
  void dispose() {
    _postSubscription?.cancel();
    _likeSubscription?.cancel();
    super.dispose();
  }

  void _deletePostAndPop(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
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
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post Details')),
        body: const Center(child: Text('Please log in to view post details.')),
      );
    }

    // NEW: Show a loading indicator while fetching the blocked users list
    if (_isLoadingBlockedUsers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // NEW: Check if the author of the post has blocked the current user
    final bool isBlockedByAuthor = _usersWhoBlockedMe.contains(widget.authorId);
    final bool isViewingOwnPost = (_currentUserId != null && _currentUserId == widget.authorId);


    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Post Details',
          style: TextStyle(
            color: Color(0xFF106C70),
            fontSize: 13,
          ),
        ),
      ),



      body: SingleChildScrollView(
        child: PostWidget(
          postId: widget.postId,
          authorId: widget.authorId,
          userId: _currentUserId!,
          postContent: widget.postContent,
          interest: widget.interest,
          imageUrl: widget.imageUrl,
          imageUrls: widget.imageUrls, // FIX: Pass the imageUrls from the widget property
          videoUrl: widget.videoUrl,
          timestamp: widget.timestamp,
          authorName: widget.authorName,
          profileImageUrl: widget.profileImageUrl,
          likeCount: _currentLikeCount,
          commentCount: _currentCommentCount,
          initiallyLiked: _isLiked,
          // FIX: Pass the postId to the onDelete callback
          onDelete: isViewingOwnPost ? _deletePostAndPop : null,
          areCommentsEnabled: widget.areCommentsEnabled,
          postVisibility: widget.postVisibility,
          authorAbout: widget.authorAbout,
          authorTitle: widget.authorTitle,
          authorPhone: widget.authorPhone,
          authorEmail: widget.authorEmail,
          onPostEdited: _handlePostAction,
          onPostHidden: _handlePostAction,
          onUserMuted: _handlePostAction,
          onUserBlocked: _handlePostAction,
          // FIX: Only provide the onEditPost callback if it's the current user's post
          onEditPost: isViewingOwnPost
              ? () => _navigateToEditPost(
            widget.postId,
            widget.postContent,
            widget.imageUrl,
            widget.videoUrl,
            widget.imageUrls,
          )
              : null,
          isBlockedByAuthor: isBlockedByAuthor,
        ),
      ),
    );
  }
}