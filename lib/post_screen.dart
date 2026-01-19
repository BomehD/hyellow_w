// File: post_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';

import 'create_post_screen.dart';
import 'post_widget.dart';
import 'edit_post_screen.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  List<QueryDocumentSnapshot> posts = [];
  Map<String, Map<String, dynamic>> authorData = {};
  bool isLoading = true;

  Set<String> _followingIds = {};
  Set<String> _hiddenPostIds = {};
  Set<String> _mutedUserIds = {};
  Set<String> _blockedUserIds = {};
  User? _currentUser;

  // NEW: Store blocked status of other users towards the current user
  Map<String, bool> _blockedByAuthors = {};

  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<QuerySnapshot>? _ownPostsSubscription;
  StreamSubscription<QuerySnapshot>? _publicPostsSubscription;
  List<StreamSubscription<QuerySnapshot>> _followingPostsSubscriptions = [];
  StreamSubscription<DocumentSnapshot>? _friendsSubscription;
  StreamSubscription<QuerySnapshot>? _hiddenPostsSubscription;
  StreamSubscription<QuerySnapshot>? _mutedUsersSubscription;
  StreamSubscription<DocumentSnapshot>? _blockedUsersSubscription;
  StreamSubscription<QuerySnapshot>? _authorBlockedSubscription; // NEW

  // Helper method to determine if we're on desktop
  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 800;
  }

  // Helper method to get the appropriate content width
  double _getContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1200) {
      return 600; // Fixed width for large screens
    } else if (screenWidth >= 800) {
      return screenWidth * 0.6; // 60% of screen width for medium screens
    } else {
      return screenWidth; // Full width for mobile
    }
  }

  @override
  void initState() {
    super.initState();
    print('🔄 [PostScreenState] initState called.');
    _setupAuthListener();
  }

  void _setupAuthListener() {
    print('🚀 [PostScreenState] Setting up auth listener.');
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        if (user != null) {
          _setupRealtimeStreams(user.uid);
        } else {
          _cleanupSubscriptions();
          setState(() {
            posts = [];
            authorData = {};
            isLoading = false;
          });
        }
      }
    });

    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _setupRealtimeStreams(_currentUser!.uid);
    } else {
      setState(() => isLoading = false);
    }
  }

  void _setupRealtimeStreams(String currentUserId) {
    print('📡 [PostScreenState] Setting up all real-time Firestore streams.');
    _cleanupSubscriptions();
    setState(() => isLoading = true);

    _friendsSubscription = FirebaseFirestore.instance
        .collection('Friends')
        .doc(currentUserId)
        .snapshots()
        .listen(_onFriendsChanged);

    _hiddenPostsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('hiddenPosts')
        .snapshots()
        .listen(_onHiddenPostsChanged);

    _mutedUsersSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('mutedUsers')
        .snapshots()
        .listen(_onMutedUsersChanged);

    _blockedUsersSubscription = FirebaseFirestore.instance
        .collection('Blocks')
        .doc(currentUserId)
        .snapshots()
        .listen(_onBlockedUsersChanged);

    _ownPostsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('authorId', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(_onPostsChanged);

    _publicPostsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(_onPostsChanged);
  }

  void _onFriendsChanged(DocumentSnapshot friendsDoc) {
    print('👥 [PostScreenState] Friends data changed.');
    Map<String, dynamic> followingMetadata = {};
    if (friendsDoc.exists && friendsDoc.data() != null) {
      final data = friendsDoc.data() as Map<String, dynamic>;
      if (data.containsKey('followingMetadata')) {
        followingMetadata = data['followingMetadata'] as Map<String, dynamic>;
      }
    }

    final newFollowingIds = followingMetadata.keys.toSet();

    if (!_setEquals(_followingIds, newFollowingIds)) {
      _followingIds = newFollowingIds;
      _setupFollowingPostsStreams();
      print("✅ [PostScreenState] Following IDs updated: $_followingIds");
    }
  }

  void _setupFollowingPostsStreams() {
    print('➡️ [PostScreenState] Setting up streams for followers-only posts.');
    for (var subscription in _followingPostsSubscriptions) {
      subscription.cancel();
    }
    _followingPostsSubscriptions.clear();

    if (_followingIds.isEmpty) return;

    final followingList = _followingIds.toList();
    const int chunkSize = 10;

    for (int i = 0; i < followingList.length; i += chunkSize) {
      final chunk = followingList.sublist(
        i,
        i + chunkSize > followingList.length ? followingList.length : i + chunkSize,
      );

      final subscription = FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', whereIn: chunk)
          .where('visibility', isEqualTo: 'followers')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(_onPostsChanged);

      _followingPostsSubscriptions.add(subscription);
    }
  }

  void _onHiddenPostsChanged(QuerySnapshot snapshot) {
    print('🙈 [PostScreenState] Hidden posts data changed.');
    final newHiddenPostIds = snapshot.docs.map((doc) => doc.id).toSet();
    if (!_setEquals(_hiddenPostIds, newHiddenPostIds)) {
      _hiddenPostIds = newHiddenPostIds;
      _refreshFilteredPosts();
      print("🙈 [PostScreenState] Hidden posts updated: $_hiddenPostIds");
    }
  }

  void _onMutedUsersChanged(QuerySnapshot snapshot) {
    print('🔇 [PostScreenState] Muted users data changed.');
    final newMutedUserIds = snapshot.docs.map((doc) => doc.id).toSet();
    if (!_setEquals(_mutedUserIds, newMutedUserIds)) {
      _mutedUserIds = newMutedUserIds;
      _refreshFilteredPosts();
      print("🔇 [PostScreenState] Muted users updated: $_mutedUserIds");
    }
  }

  void _onBlockedUsersChanged(DocumentSnapshot snapshot) {
    print('🚫 [PostScreenState] Blocked users data changed.');
    final newBlockedUserIds = (snapshot.data() as Map<String, dynamic>?)?['blocked']?.cast<String>() ?? [];
    final newSet = newBlockedUserIds.toSet();
    if (!_setEquals(_blockedUserIds, newSet)) {
      _blockedUserIds = newSet;
      _refreshFilteredPosts();
      print("🚫 [PostScreenState] Blocked users updated: $_blockedUserIds");
    }
  }

  void _onPostsChanged(QuerySnapshot snapshot) {
    print("📝 [PostScreenState] A post stream changed. Refreshing all filtered posts.");
    _refreshFilteredPosts();
  }

  void _refreshFilteredPosts() {
    if (!mounted) return;
    print('🔄 [PostScreenState] Calling _fetchAndFilterPosts().');
    _fetchAndFilterPosts();
  }

  Future<void> _fetchAndFilterPosts() async {
    if (!mounted || _currentUser == null) return;
    print('🔍 [PostScreenState] Fetching and filtering posts...');

    try {
      List<QueryDocumentSnapshot> allPosts = [];

      final ownPostsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: _currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .get();
      allPosts.addAll(ownPostsSnap.docs);

      final blockedList = _blockedUserIds.toList();
      const int chunkSize = 10;

      if (blockedList.isNotEmpty) {
        for (int i = 0; i < blockedList.length; i += chunkSize) {
          final chunk = blockedList.sublist(
            i,
            i + chunkSize > blockedList.length ? blockedList.length : i + chunkSize,
          );

          final publicPostsSnap = await FirebaseFirestore.instance
              .collection('posts')
              .where('visibility', isEqualTo: 'public')
              .where('authorId', whereNotIn: chunk)
              .orderBy('timestamp', descending: true)
              .get();
          allPosts.addAll(publicPostsSnap.docs);
        }
      } else {
        final publicPostsSnap = await FirebaseFirestore.instance
            .collection('posts')
            .where('visibility', isEqualTo: 'public')
            .orderBy('timestamp', descending: true)
            .get();
        allPosts.addAll(publicPostsSnap.docs);
      }

      if (_followingIds.isNotEmpty) {
        final followingList = _followingIds.toList();
        const int followingChunkSize = 10;
        for (int i = 0; i < followingList.length; i += followingChunkSize) {
          final chunk = followingList.sublist(
            i,
            i + followingChunkSize > followingList.length ? followingList.length : i + followingChunkSize,
          );

          final followersPostsSnap = await FirebaseFirestore.instance
              .collection('posts')
              .where('authorId', whereIn: chunk)
              .where('visibility', isEqualTo: 'followers')
              .orderBy('timestamp', descending: true)
              .get();

          allPosts.addAll(followersPostsSnap.docs);
        }
      }

      final uniquePosts = <String, QueryDocumentSnapshot>{};
      for (var post in allPosts) {
        uniquePosts[post.id] = post;
      }
      allPosts = uniquePosts.values.toList();

      allPosts = allPosts.where((doc) {
        final postId = doc.id;
        final authorId = doc['authorId'] as String? ?? '';
        return !_hiddenPostIds.contains(postId) && !_mutedUserIds.contains(authorId);
      }).toList();

      allPosts.sort((a, b) {
        final tsA = a['timestamp'] as Timestamp?;
        final tsB = b['timestamp'] as Timestamp?;
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });

      final authorIds = allPosts.map((p) => p['authorId'] as String).toSet();
      final newAuthorData = await _getAuthorMetadata(authorIds);

      // NEW: Fetch blocked status for all post authors
      final blockedByAuthors = await _checkIfAuthorsBlockedMe(authorIds);

      if (mounted) {
        setState(() {
          posts = allPosts;
          authorData = newAuthorData;
          _blockedByAuthors = blockedByAuthors;
          isLoading = false;
        });
      }

      print("✅ [PostScreenState] Posts refreshed: ${allPosts.length} posts displayed");
    } catch (e, stack) {
      print("❌ [PostScreenState] Error refreshing posts: $e\n$stack");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // NEW: Function to check if authors have blocked the current user
  Future<Map<String, bool>> _checkIfAuthorsBlockedMe(Set<String> authorIds) async {
    final Map<String, bool> blockedStatus = {};
    if (authorIds.isEmpty || _currentUser == null) return blockedStatus;

    // Use a list to check for multiple documents in one go
    final authorIdList = authorIds.toList();

    try {
      final blockedDocs = await FirebaseFirestore.instance
          .collection('Blocks')
          .where(FieldPath.documentId, whereIn: authorIdList)
          .get();

      final blockedData = {
        for (var doc in blockedDocs.docs)
          doc.id: (doc.data()['blocked'] as List<dynamic>).cast<String>()
      };

      for (final authorId in authorIdList) {
        if (blockedData.containsKey(authorId)) {
          if (blockedData[authorId]!.contains(_currentUser!.uid)) {
            blockedStatus[authorId] = true;
          } else {
            blockedStatus[authorId] = false;
          }
        } else {
          blockedStatus[authorId] = false;
        }
      }
    } catch (e) {
      print("❌ Error checking if authors blocked me: $e");
      for (final authorId in authorIdList) {
        blockedStatus[authorId] = false;
      }
    }
    return blockedStatus;
  }

  Future<Map<String, Map<String, dynamic>>> _getAuthorMetadata(Set<String> userIds) async {
    final Map<String, Map<String, dynamic>> userDataMap = {};
    if (userIds.isEmpty) return userDataMap;
    final userIdsList = userIds.toList();

    try {
      final userSnapshots = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIdsList)
          .get();

      final profileSnapshots = await FirebaseFirestore.instance
          .collection('profiles')
          .where(FieldPath.documentId, whereIn: userIdsList)
          .get();

      final Map<String, DocumentSnapshot> userDocs = {for (var doc in userSnapshots.docs) doc.id: doc};
      final Map<String, DocumentSnapshot> profileDocs = {for (var doc in profileSnapshots.docs) doc.id: doc};

      for (final userId in userIdsList) {
        String name = 'Unknown';
        String? profileImage;
        String about = '';
        String title = '';
        String phone = '';
        String email = '';
        String interest = 'General';

        if (userDocs.containsKey(userId)) {
          final data = userDocs[userId]!.data() as Map<String, dynamic>?;
          name = data?['name'] ?? name;
          final userInterest = data?['interest'] as String?;
          if (userInterest != null && userInterest.isNotEmpty) {
            interest = userInterest;
          }
        }
        if (profileDocs.containsKey(userId)) {
          final profileData = profileDocs[userId]!.data() as Map<String, dynamic>?;
          profileImage = profileData?['profileImage'];
          about = profileData?['about'] ?? about;
          title = profileData?['title'] ?? title;
          phone = profileData?['phone'] ?? phone;
          email = profileData?['email'] ?? email;
        }

        userDataMap[userId] = {
          'name': name,
          'profileImage': profileImage,
          'about': about,
          'title': title,
          'phone': phone,
          'email': email,
          'interest': interest,
        };
      }
    } catch (e) {
      print('❌ [PostScreenState] Error fetching author metadata: $e');
    }
    return userDataMap;
  }

  Future<bool> _checkIfLiked(String postId, String userId) async {
    final likeDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .get();
    return likeDoc.exists;
  }

  void _deletePost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      print('🗑️ [PostScreenState] Post deleted: $postId');
    } catch (e) {
      print('❌ [PostScreenState] Error deleting post: $e');
    }
  }

  void _navigateToEditPost(String postId, String content, String? imageUrl, String? videoUrl) {
    print('➡️ [PostScreenState] Navigating to edit post screen for post ID: $postId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(
          postId: postId,
          initialContent: content,
          initialImageUrl: imageUrl,
          initialVideoUrl: videoUrl,
        ),
      ),
    );
  }

  void _handlePostAction() {
    print("🔄 [PostScreenState] Post action detected. Real-time streams will handle updates.");
  }

  bool _setEquals<T>(Set<T> set1, Set<T> set2) {
    if (set1.length != set2.length) return false;
    for (var item in set1) {
      if (!set2.contains(item)) return false;
    }
    return true;
  }

  void _cleanupSubscriptions() {
    print('🧹 [PostScreenState] Cleaning up all subscriptions.');
    _authStateSubscription?.cancel();
    _ownPostsSubscription?.cancel();
    _publicPostsSubscription?.cancel();
    _friendsSubscription?.cancel();
    _hiddenPostsSubscription?.cancel();
    _mutedUsersSubscription?.cancel();
    _blockedUsersSubscription?.cancel();
    _authorBlockedSubscription?.cancel(); // NEW

    for (var subscription in _followingPostsSubscriptions) {
      subscription.cancel();
    }
    _followingPostsSubscriptions.clear();
  }

  @override
  void dispose() {
    print('👋 [PostScreenState] dispose() called. Cleaning up all subscriptions.');
    _cleanupSubscriptions();
    super.dispose();
  }

  // Helper widget to wrap content with responsive constraints
  Widget _buildResponsiveContent(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isDesktop(context)) {
          return Center(
            child: Container(
              width: _getContentWidth(context),
              child: child,
            ),
          );
        }
        return child;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 [PostScreenState] build() called.');
    final currentUserId = _currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        body: _buildResponsiveContent(
          const Center(
            child: Text('Please sign in to view posts.', style: TextStyle(fontSize: 18)),
          ),
        ),
      );
    }

    return Scaffold(
      body: _buildResponsiveContent(
        isLoading
            ? ListView.builder(
          itemCount: 3,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),
        )
            : posts.isEmpty
            ? Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.feed_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                const Text(
                  'No posts available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.0, vertical: 8),
                  child: Text(
                    'Create your first post or follow others to see their updates here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                if (_blockedUserIds.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'You are currently blocking users. Their posts are not visible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        )
            : RefreshIndicator(
          color: Colors.teal,
          backgroundColor: Colors.black,
          onRefresh: () => _fetchAndFilterPosts(),
          child: ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postDoc = posts[index];
              final postData = postDoc.data()! as Map<String, dynamic>;
              final postId = postDoc.id;
              final authorId = postData['authorId'] as String;
              final timestamp = postData['timestamp'] as Timestamp?;
              final visibility = postData['visibility'] as String? ?? 'public';
              final commentsEnabled = postData['commentsEnabled'] as bool? ?? true;
              final userInfo = authorData[authorId] ?? {};
              final authorName = userInfo['name'] as String? ?? 'Unknown';
              final profileImageUrl = userInfo['profileImage'] as String?;
              final authorAbout = userInfo['about'] as String? ?? '';
              final authorTitle = userInfo['title'] as String? ?? '';
              final authorPhone = userInfo['phone'] as String? ?? '';
              final authorEmail = userInfo['email'] as String? ?? '';
              final videoUrl = postData['videoUrl'] as String?;

              // NEW: Get the list of imageUrls.
              final imageUrls = postData['imageUrls'] as List<dynamic>?;

              // NEW: Get the blocked status for this specific author
              final isBlockedByAuthor = _blockedByAuthors[authorId] ?? false;

              print('➡️ [PostScreenState] Building PostWidget for post ID: $postId at index $index');

              return FutureBuilder<bool>(
                future: _checkIfLiked(postId, currentUserId),
                builder: (context, snapshot) {
                  final liked = snapshot.data ?? false;
                  return PostWidget(
                    key: PageStorageKey(postId),
                    postId: postId,
                    authorId: authorId,
                    userId: currentUserId,
                    postContent: postData['content'] as String? ?? '',
                    interest: postData['interest'] as String? ?? 'General',
                    imageUrl: postData['imageUrl'] as String?,
                    videoUrl: videoUrl,
                    imageUrls: imageUrls?.cast<String>(), // NEW: Pass the imageUrls list
                    timestamp: timestamp ?? Timestamp.now(),
                    authorName: authorName,
                    profileImageUrl: profileImageUrl,
                    likeCount: postData['likeCount'] as int? ?? 0,
                    commentCount: postData['commentCount'] as int? ?? 0,
                    initiallyLiked: liked,
                    onDelete: _deletePost,
                    areCommentsEnabled: commentsEnabled,
                    postVisibility: visibility,
                    authorAbout: authorAbout,
                    authorTitle: authorTitle,
                    authorPhone: authorPhone,
                    authorEmail: authorEmail,
                    onEditPost: () => _navigateToEditPost(
                      postId,
                      postData['content'] as String? ?? '',
                      postData['imageUrl'] as String?,
                      postData['videoUrl'] as String?,
                    ),
                    onPostEdited: _handlePostAction,
                    onPostHidden: _handlePostAction,
                    onUserMuted: _handlePostAction,
                    onUserBlocked: _handlePostAction,
                    initiallyBookmarked: false,
                    isBlockedByAuthor: isBlockedByAuthor, // NEW: Pass the flag
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print('➕ [PostScreenState] Navigating to CreatePostScreen.');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreatePostScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.black),
        backgroundColor: const Color(0xFF106C70),
      ),
    );
  }
}