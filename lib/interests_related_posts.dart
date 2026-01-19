// File: InterestsRelatedPosts.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:hyellow_w/post_widget.dart';
import 'package:hyellow_w/user_list_screen.dart';
import 'package:hyellow_w/edit_post_screen.dart';

class InterestsRelatedPosts extends StatefulWidget {
  final String initialInterest;

  const InterestsRelatedPosts({Key? key, required this.initialInterest}) : super(key: key);

  @override
  _InterestsRelatedPostsState createState() => _InterestsRelatedPostsState();
}

class _InterestsRelatedPostsState extends State<InterestsRelatedPosts> {
  List<QueryDocumentSnapshot> posts = [];
  Map<String, Map<String, dynamic>> authorData = {};

  bool _isInitialLoadComplete = false;

  Set<String> _followingIds = {};
  Set<String> _hiddenPostIds = {};
  Set<String> _mutedUserIds = {};
  Set<String> _blockedUserIds = {};
  Set<String> _likedPostIds = {};
  // NEW: Set to store users who have blocked the current user
  Set<String> _usersWhoBlockedMe = {};
  User? _currentUser;

  StreamSubscription<QuerySnapshot>? _postsSubscription;
  StreamSubscription<DocumentSnapshot>? _friendsSubscription;
  StreamSubscription<QuerySnapshot>? _hiddenPostsSubscription;
  StreamSubscription<QuerySnapshot>? _mutedUsersSubscription;
  StreamSubscription<DocumentSnapshot>? _blockedUsersSubscription;
  StreamSubscription<QuerySnapshot>? _likedPostsSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _setupRealtimeStreams(_currentUser!.uid);
      // NEW: Load the list of users who have blocked the current user
      _loadUsersWhoBlockedMe();
    } else {
      setState(() => _isInitialLoadComplete = true);
    }
  }

  void _setupRealtimeStreams(String currentUserId) {
    _cleanupSubscriptions();
    setState(() => _isInitialLoadComplete = false);

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

    _likedPostsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('likes')
        .snapshots()
        .listen(_onLikedPostsChanged);

    _setupPostsStream();
  }

  // NEW: Function to load users who have blocked the current user.
  // This is a one-time fetch, not a stream, as Firestore's query capabilities
  // make a real-time stream for this difficult without a different data structure.
  Future<void> _loadUsersWhoBlockedMe() async {
    final currentUserId = _currentUser?.uid;
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

      if (_setEquals(_usersWhoBlockedMe, newBlockedMeSet)) return;

      if (mounted) {
        setState(() {
          _usersWhoBlockedMe = newBlockedMeSet;
        });
        print("🚫 Users who blocked me updated: $_usersWhoBlockedMe");
      }
    } catch (e) {
      print("Error loading users who blocked me: $e");
    }
  }

  void _setupPostsStream() {
    _postsSubscription?.cancel();
    if (_blockedUserIds.length > 10) {
      print('Warning: `whereNotIn` has a limit of 10. Consider splitting your query for blocked users.');
    }

    final blockedList = _blockedUserIds.toList();

    _postsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('interest', isEqualTo: widget.initialInterest)
        .where('authorId', whereNotIn: blockedList.isEmpty ? [''] : blockedList)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(_onPostsChanged);
  }

  void _onPostsChanged(QuerySnapshot snapshot) async {
    print("📝 Posts changed for ${widget.initialInterest}: ${snapshot.docs.length} documents");

    List<QueryDocumentSnapshot> filteredPosts = await _filterPosts(snapshot.docs);
    Map<String, Map<String, dynamic>> newAuthorData = await _getAuthorMetadata(filteredPosts.map((p) => p['authorId'] as String).toSet());

    if (mounted) {
      setState(() {
        posts = filteredPosts;
        authorData = newAuthorData;
        if (!_isInitialLoadComplete) {
          _isInitialLoadComplete = true;
        }
      });
      print("✅ Posts refreshed: ${posts.length} posts displayed for ${widget.initialInterest}");
    }
  }

  void _onFriendsChanged(DocumentSnapshot friendsDoc) {
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
      _refreshFilteredPosts();
      print("✅ Following IDs updated: $_followingIds");
    }
  }

  void _onHiddenPostsChanged(QuerySnapshot snapshot) {
    final newHiddenPostIds = snapshot.docs.map((doc) => doc.id).toSet();
    if (!_setEquals(_hiddenPostIds, newHiddenPostIds)) {
      _hiddenPostIds = newHiddenPostIds;
      _refreshFilteredPosts();
      print("🙈 Hidden posts updated: $_hiddenPostIds");
    }
  }

  void _onMutedUsersChanged(QuerySnapshot snapshot) {
    final newMutedUserIds = snapshot.docs.map((doc) => doc.id).toSet();
    if (!_setEquals(_mutedUserIds, newMutedUserIds)) {
      _mutedUserIds = newMutedUserIds;
      _refreshFilteredPosts();
      print("🔇 Muted users updated: $_mutedUserIds");
    }
  }

  void _onBlockedUsersChanged(DocumentSnapshot snapshot) {
    final newBlockedUserIds = (snapshot.data() as Map<String, dynamic>?)?['blocked']?.cast<String>() ?? [];
    final newSet = newBlockedUserIds.toSet();

    if (!_setEquals(_blockedUserIds, newSet)) {
      _blockedUserIds = newSet;
      _setupPostsStream();
      print("🚫 Blocked users updated: $_blockedUserIds");
    }
  }

  void _onLikedPostsChanged(QuerySnapshot snapshot) {
    final newLikedPostIds = snapshot.docs.map((doc) => doc.id).toSet();
    if (!_setEquals(_likedPostIds, newLikedPostIds)) {
      _likedPostIds = newLikedPostIds;
      if (mounted) setState(() {});
      print("👍 Liked posts updated: ${_likedPostIds.length}");
    }
  }

  Future<List<QueryDocumentSnapshot>> _filterPosts(List<QueryDocumentSnapshot> allPosts) async {
    if (_currentUser == null) return [];

    List<QueryDocumentSnapshot> filteredPosts = allPosts.where((doc) {
      final postId = doc.id;
      final postData = doc.data() as Map<String, dynamic>;
      final authorId = postData['authorId'] as String? ?? '';
      final visibility = postData['visibility'] as String? ?? 'public';

      bool isVisible = false;
      if (visibility == 'public') {
        isVisible = true;
      } else if (visibility == 'private') {
        if (authorId == _currentUser!.uid) {
          isVisible = true;
        }
      } else if (visibility == 'followers') {
        if (authorId == _currentUser!.uid) {
          isVisible = true;
        } else if (_followingIds.contains(authorId)) {
          isVisible = true;
        }
      }

      return isVisible && !_hiddenPostIds.contains(postId) && !_mutedUserIds.contains(authorId);
    }).toList();

    filteredPosts.sort((a, b) {
      final tsA = a['timestamp'] as Timestamp?;
      final tsB = b['timestamp'] as Timestamp?;
      if (tsA == null && tsB == null) return 0;
      if (tsA == null) return 1;
      if (tsB == null) return -1;
      return tsB.compareTo(tsA);
    });

    return filteredPosts;
  }

  Future<void> _refreshFilteredPosts() async {
    if (!mounted || _currentUser == null) return;

    await _loadUsersWhoBlockedMe(); // Re-fetch the list of users who have blocked me

    final blockedList = _blockedUserIds.toList();

    final postsSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('interest', isEqualTo: widget.initialInterest)
        .where('authorId', whereNotIn: blockedList.isEmpty ? [''] : blockedList)
        .orderBy('timestamp', descending: true)
        .get();

    List<QueryDocumentSnapshot> newFilteredPosts = await _filterPosts(postsSnapshot.docs);
    final newAuthorIds = newFilteredPosts.map((p) => p['authorId'] as String).toSet();
    final newAuthorData = await _getAuthorMetadata(newAuthorIds);

    if (mounted) {
      setState(() {
        posts = newFilteredPosts;
        authorData = newAuthorData;
      });
      print("✅ Posts refreshed: ${posts.length} posts displayed for ${widget.initialInterest}");
    }
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
      print('Error fetching author metadata: $e');
    }
    return userDataMap;
  }

  bool _setEquals<T>(Set<T> set1, Set<T> set2) {
    if (set1.length != set2.length) return false;
    for (var item in set1) {
      if (!set2.contains(item)) return false;
    }
    return true;
  }

  void _cleanupSubscriptions() {
    _postsSubscription?.cancel();
    _friendsSubscription?.cancel();
    _hiddenPostsSubscription?.cancel();
    _mutedUsersSubscription?.cancel();
    _blockedUsersSubscription?.cancel();
    _likedPostsSubscription?.cancel();
  }

  @override
  void dispose() {
    _cleanupSubscriptions();
    super.dispose();
  }

  void _deletePost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  void _navigateToEditPost(String postId, String content, String? imageUrl, String? videoUrl, List<String>? imageUrls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(
          postId: postId,
          initialContent: content,
          initialImageUrl: imageUrl,
          initialVideoUrl: videoUrl,
          initialImageUrls: imageUrls, // NEW: Pass the list
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
    final currentUserId = _currentUser?.uid;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in to view posts.', style: TextStyle(fontSize: 18)),
        ),
      );
    }
    return Scaffold(

    appBar: AppBar(
      title: Text(
        widget.initialInterest,
        style: const TextStyle(
          color: Color(0xFF106C70),
          fontSize: 13,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: iconColor),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: iconColor),
          onPressed: () => _refreshFilteredPosts(),
        ),
        IconButton(
          icon: Icon(Icons.people, color: iconColor),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserListScreen(
                  selectedInterest: widget.initialInterest,
                ),
              ),
            );
          },
        ),
      ],
    ),

    body: Center(
        child: SizedBox(
          width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
          child: !_isInitialLoadComplete
              ? const Center(child: CircularProgressIndicator())
              : posts.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.post_add_outlined,
                  size: 60,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No posts available',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Try adjusting your filters or come back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: () async {
              _refreshFilteredPosts();
            },
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final postDoc = posts[index];
                final postData = postDoc.data() as Map<String, dynamic>;
                final postId = postDoc.id;
                final authorId = postData['authorId'];
                final user = authorData[authorId] ?? {'name': 'Unknown', 'profileImage': ''};
                final isLiked = _likedPostIds.contains(postId);

                // NEW: Determine if the author of the post has blocked the current user
                final isBlockedByAuthor = _usersWhoBlockedMe.contains(authorId);
                final List<String>? imageUrls = (postData['imageUrls'] as List<dynamic>?)?.cast<String>();


                return PostWidget(
                  key: ValueKey(postId),
                  postId: postId,
                  authorId: authorId,
                  postContent: postData['content'] ?? '',
                  imageUrl: postData['imageUrl'],
                  videoUrl: postData['videoUrl'],
                  interest: postData['interest'] ?? 'General',
                  timestamp: postData['timestamp'] ?? Timestamp.now(),
                  userId: currentUserId,
                  authorName: user['name'],
                  profileImageUrl: user['profileImage'],
                  likeCount: postData['likeCount'] ?? 0,
                  commentCount: postData['commentCount'] ?? 0,
                  imageUrls: (postData['imageUrls'] as List<dynamic>?)?.cast<String>(),
                  initiallyLiked: isLiked,
                  postVisibility: postData['visibility'] ?? 'public',
                  areCommentsEnabled: postData['commentsEnabled'] ?? true,
                  authorAbout: user['about'] ?? '',
                  authorTitle: user['title'] ?? '',
                  authorPhone: user['phone'] ?? '',
                  authorEmail: user['email'] ?? '',
                  onDelete: _deletePost,
                  onPostEdited: _handlePostAction,
                  onPostHidden: _handlePostAction,
                  onUserMuted: _handlePostAction,
                  onUserBlocked: _handlePostAction, // This will trigger a re-fetch, which will also update _usersWhoBlockedMe
                  onEditPost: () => _navigateToEditPost(
                    postId,
                    postData['content'] as String? ?? '',
                    postData['imageUrl'] as String?,
                    postData['videoUrl'] as String?,
                    imageUrls, // Pass the new list to the edit screen

                  ),
                  isBlockedByAuthor: isBlockedByAuthor, // NEW: Pass the blocking status
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}