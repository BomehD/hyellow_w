import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'full_screen_image_viewer.dart';
import 'package:hyellow_w/utils/download_profile_image.dart';
import 'chat_detail_screen.dart';
import 'friends_list.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Added Firestore instance
  Map<String, Map<String, dynamic>> profilesData = {};
  Map<String, Map<String, dynamic>> usersData = {};
  Map<String, dynamic>? currentUserProfile;
  Set<String> blockedUsers = {}; // Set to store blocked user IDs

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoadingProfiles = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutBack,
      ),
    );
    _animationController.forward();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    }
  }

  Future<void> _loadInitialData() async {
    try {
      await _loadCurrentUserProfile();
      await _loadBlockedUsers(); // Load blocked users on init
      await _loadProfilesData();
      if (mounted) {
        setState(() {
          _isLoadingProfiles = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _loadInitialData: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfiles = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chats: $e')),
        );
      }
    }
  }

  Future<void> _loadBlockedUsers() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final blockDoc = await _firestore.collection('Blocks').doc(user.uid).get();
      if (blockDoc.exists && blockDoc.data()!.containsKey('blocked')) {
        final List<dynamic> blockedList = blockDoc.data()!['blocked'];
        if (mounted) {
          setState(() {
            blockedUsers = blockedList.cast<String>().toSet();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final profileDoc = await _firestore.collection('profiles').doc(user.uid).get();
        if (mounted) {
          if (profileDoc.exists) {
            setState(() {
              currentUserProfile = profileDoc.data();
            });
          } else {
            final userDoc = await _firestore.collection('users').doc(user.uid).get();
            if (mounted) {
              if (userDoc.exists) {
                setState(() {
                  currentUserProfile = userDoc.data();
                });
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading current user profile: $e');
      }
    }
  }

  Future<void> _toggleMuteChat(String chatId, bool isCurrentlyMuted) async {
    try {
      final chatDocRef = _firestore.collection('chats').doc(chatId);
      final currentUserId = _auth.currentUser!.uid;

      if (isCurrentlyMuted) {
        await chatDocRef.update({
          'mutedBy': FieldValue.arrayRemove([currentUserId]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat unmuted.')),
          );
        }
      } else {
        await chatDocRef.update({
          'mutedBy': FieldValue.arrayUnion([currentUserId]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat muted.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling mute status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change mute status: $e')),
        );
      }
    }
  }

  Future<void> _togglePinChat(String chatId, bool isCurrentlyPinned) async {
    try {
      final chatDocRef = _firestore.collection('chats').doc(chatId);
      final currentUserId = _auth.currentUser!.uid;

      if (isCurrentlyPinned) {
        await chatDocRef.update({
          'pinnedBy': FieldValue.arrayRemove([currentUserId]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat unpinned.')),
          );
        }
      } else {
        await chatDocRef.update({
          'pinnedBy': FieldValue.arrayUnion([currentUserId]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat pinned.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling pin status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change pin status: $e')),
        );
      }
    }
  }

  Future<void> _archiveChat(String chatId) async {
    try {
      final chatDocRef = _firestore.collection('chats').doc(chatId);
      await chatDocRef.update({
        'deletedBy': FieldValue.arrayUnion([_auth.currentUser!.uid]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation archived.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error archiving chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to archive conversation: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadProfilesData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() {});
      return;
    }

    profilesData.clear();
    usersData.clear();

    List<String> friendIds = [];
    try {
      var chatsSnapshot = await _firestore
          .collection('chats')
          .where('users', arrayContains: currentUser.uid)
          .get();

      for (var chat in chatsSnapshot.docs) {
        List<dynamic> users = chat['users'];
        String? friendId = users.firstWhere((id) => id != currentUser.uid, orElse: () => null);
        if (friendId != null) {
          friendIds.add(friendId);
        }
      }

      if (friendIds.isEmpty) {
        if (mounted) setState(() {});
        return;
      }

      const int chunkSize = 10;
      List<List<String>> chunks = [];
      for (int i = 0; i < friendIds.length; i += chunkSize) {
        chunks.add(friendIds.sublist(i, i + chunkSize > friendIds.length ? friendIds.length : i + chunkSize));
      }

      for (var chunk in chunks) {
        var profilesSnapshot = await _firestore
            .collection('profiles')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in profilesSnapshot.docs) {
          profilesData[doc.id] = doc.data() as Map<String, dynamic>;
        }

        var usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in usersSnapshot.docs) {
          usersData[doc.id] = doc.data() as Map<String, dynamic>;
        }
      }

      for (var friendId in friendIds) {
        final profile = profilesData[friendId];
        final user = usersData[friendId];

        if (profile != null) {
          profilesData[friendId]?.addAll(user ?? {});
        } else if (user != null) {
          profilesData[friendId] = user;
        } else {
          profilesData[friendId] = {'name': 'Unknown Contact'};
        }
      }
    } catch (e) {
      debugPrint('Error loading profiles data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load some profile data: $e')),
        );
      }
    }
  }

  Future<bool?> _showConfirmationDialog(String message) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  // Blocks a user, updating friend relationships and deleting relevant notifications.
  Future<void> _blockUser(String userId) async {
    final bool? confirm = await _showConfirmationDialog(
        'Block this user? They will no longer be able to follow you or see your content.');
    if (confirm != true) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return; // Ensure currentUserId is not null after dialog

    try {
      await _firestore.collection('Blocks').doc(currentUserId).set({
        'blocked': FieldValue.arrayUnion([userId])
      }, SetOptions(merge: true));

      // Remove from current user's followers by deleting from followersMetadata map
      await _firestore.collection('Friends').doc(currentUserId).update({
        'followersMetadata.$userId': FieldValue.delete()
      });

      // Remove current user from target user's following list by deleting from followingMetadata map
      await _firestore.collection('Friends').doc(userId).update({
        'followingMetadata.$currentUserId': FieldValue.delete()
      });

      // Delete related new_follower notifications from this user
      final notificationQuery = await _firestore.collection('notifications')
          .where('recipientId', isEqualTo: currentUserId)
          .where('senderId', isEqualTo: userId)
          .where('type', isEqualTo: 'new_follower')
          .get();

      final WriteBatch batch = _firestore.batch();
      for (final doc in notificationQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        setState(() {
          blockedUsers.add(userId);
        }); // Rebuild to update block status
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to block user: $e')));
      }
    }
  }

  // Unblocks a user.
  Future<void> _unblockUser(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore.collection('Blocks').doc(currentUserId).update({
        'blocked': FieldValue.arrayRemove([userId])
      });

      if (mounted) {
        setState(() {
          blockedUsers.remove(userId);
        }); // Rebuild to update block status
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unblock user: $e')));
      }
    }
  }

  void _showFullscreenImage(BuildContext context, String imageUrl, String heroTag) {
    if (imageUrl.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenImageViewer(
            imageUrl: imageUrl,
            heroTag: heroTag,
          ),
        ),
      );
    }
  }

  void _downloadImage(BuildContext context, String? imageUrl) async {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      await DownloadProfileImage.downloadAndSaveImage(context, imageUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No downloadable image available.')),
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '';
    }
    final DateTime messageTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = DateTime(now.year, now.month, now.day - 1);

    if (messageTime.isAfter(today)) {
      return DateFormat.jm().format(messageTime);
    } else if (messageTime.isAfter(yesterday)) {
      return 'Yesterday';
    } else {
      if (messageTime.year == now.year) {
        return DateFormat.MMMd().format(messageTime);
      } else {
        return DateFormat.yMd().format(messageTime);
      }
    }
  }

  // New helper method for responsive layout
  double _getContentWidth(double screenWidth) {
    if (screenWidth >= 1200) {
      return 600; // Fixed width for large desktops
    } else if (screenWidth >= 800) {
      return screenWidth * 0.65; // 65% for tablets
    } else {
      return screenWidth; // Full width for mobile
    }
  }

  @override
  Widget build(BuildContext context) {
    String? currentUserProfileImageUrl = currentUserProfile?['profileImage'];
    ImageProvider currentUserAvatarImage;
    bool isCurrentUserAssetImage = false;

    if (currentUserProfileImageUrl != null && currentUserProfileImageUrl.isNotEmpty) {
      currentUserAvatarImage = NetworkImage(currentUserProfileImageUrl);
    } else {
      currentUserAvatarImage = const AssetImage('assets/default_profile_image.png');
      isCurrentUserAssetImage = true;
    }

    final String currentUserHeroTag = _auth.currentUser!.uid;

    // Responsive logic
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        flexibleSpace: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(25.0),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: const TextStyle(color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                          : const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    ),
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  String imageUrl = isCurrentUserAssetImage
                      ? 'assets/default_profile_image.png'
                      : currentUserProfileImageUrl!;
                  _showFullscreenImage(
                    context,
                    imageUrl,
                    currentUserHeroTag,
                  );
                },
                onLongPress: () {
                  _downloadImage(context, currentUserProfileImageUrl);
                },
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                  ),
                  child: Hero(
                    tag: currentUserHeroTag,
                    child: CircleAvatar(
                      radius: 21,
                      backgroundImage: currentUserAvatarImage,
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _scaleAnimation,
        child: FloatingActionButton(
          onPressed: () async {
            final selectedFriend = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FriendsList()),
            );

            if (selectedFriend != null && mounted) {

              // FIX: Manually inject the friend's data into the local cache
              setState(() {
                profilesData[selectedFriend['id']] = {
                  'name': selectedFriend['name'],
                  'profileImage': selectedFriend['profileImage'],
                  'userId': selectedFriend['userId'],
                };
              });

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(friend: selectedFriend),
                ),
              );

              if (result == 'user_unblocked' || result == 'chat_deleted') {
                if (mounted) {
                  setState(() {
                    _loadBlockedUsers(); // Refresh the blocked users list
                  });
                }
              }
            }
          },
          backgroundColor: const Color(0xFF106C70),
          elevation: 6,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 28),
          tooltip: 'Start a new conversation',
        ),
      ),
      // The body is now wrapped in a Center and SizedBox for responsive behavior
      body: Center(
        child: SizedBox(
          width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
          child: _isLoadingProfiles
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('chats')
                .where('users', arrayContains: _auth.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 70,
                          color: Colors.grey[200],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No conversations yet. Tap the message icon to initiate a new discussion.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              var chats = snapshot.data!.docs.where((chat) {
                List<dynamic> deletedBy = (chat.data() as Map<String, dynamic>)['deletedBy'] ?? [];
                return !deletedBy.contains(_auth.currentUser!.uid);
              }).toList();

              chats.sort((a, b) {
                final currentUserUid = _auth.currentUser!.uid;
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                final aPinnedBy = (aData['pinnedBy'] as List<dynamic>?)?.cast<String>() ?? [];
                final bPinnedBy = (bData['pinnedBy'] as List<dynamic>?)?.cast<String>() ?? [];

                final aIsPinned = aPinnedBy.contains(currentUserUid);
                final bIsPinned = bPinnedBy.contains(currentUserUid);

                if (aIsPinned && !bIsPinned) return -1;
                if (!aIsPinned && bIsPinned) return 1;

                final aLastMessageAt = aData['lastMessageAt'] as Timestamp?;
                final bLastMessageAt = bData['lastMessageAt'] as Timestamp?;

                if (aLastMessageAt == null && bLastMessageAt == null) return 0;
                if (aLastMessageAt == null) return 1;
                if (bLastMessageAt == null) return -1;

                return bLastMessageAt.compareTo(aLastMessageAt);
              });


              if (_searchQuery.isNotEmpty) {
                chats = chats.where((chat) {
                  Map<String, dynamic> chatData = chat.data() as Map<String, dynamic>;
                  List<dynamic> users = chatData['users'];
                  String friendId = users.firstWhere((id) => id != _auth.currentUser!.uid, orElse: () => '');

                  if (friendId.isEmpty) {
                    return false;
                  }

                  if (!profilesData.containsKey(friendId)) {
                    return false;
                  }

                  String name = profilesData[friendId]?['name'] ?? '';
                  return name.toLowerCase().contains(_searchQuery);
                }).toList();
              }

              if (chats.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_outlined,
                          size: 70,
                          color: Colors.grey[200],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No conversations found matching "${_searchController.text}".'
                              : 'All conversations have been archived. Start a new one anytime!',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  var chat = chats[index];
                  Map<String, dynamic> chatData = chat.data() as Map<String, dynamic>;
                  List<dynamic> users = chatData['users'];

                  String friendId = users.firstWhere((id) => id != _auth.currentUser!.uid, orElse: () => '');

                  if (friendId.isEmpty) return const SizedBox.shrink();

                  // Filter out chats with blocked users
                  if (blockedUsers.contains(friendId)) {
                    return const SizedBox.shrink();
                  }

                  var friendProfileData = profilesData[friendId] ?? {};
                  String name = friendProfileData['name'] ?? 'Unknown Contact';
                  String? profileImageUrl = friendProfileData['profileImage'];

                  final String friendHeroTag = friendId;

                  ImageProvider avatarImage;
                  bool isAssetImage = false;

                  if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
                    avatarImage = NetworkImage(profileImageUrl);
                  } else {
                    avatarImage = const AssetImage('assets/default_profile_image.png');
                    isAssetImage = true;
                  }

                  String lastMessage = chatData['lastMessage'] ?? 'No messages yet';
                  Timestamp? lastMessageAt = chatData['lastMessageAt'];

                  Map<String, dynamic> unreadCounts = chatData['unreadCount'] ?? {};
                  int unreadCount = unreadCounts[_auth.currentUser!.uid] ?? 0;

                  final currentUserUid = _auth.currentUser!.uid;
                  final mutedBy = (chatData['mutedBy'] as List<dynamic>?)?.cast<String>() ?? [];
                  final pinnedBy = (chatData['pinnedBy'] as List<dynamic>?)?.cast<String>() ?? [];
                  bool isMuted = mutedBy.contains(currentUserUid);
                  bool isPinned = pinnedBy.contains(currentUserUid);
                  bool isBlocked = blockedUsers.contains(friendId);

                  return Column(
                    children: [
                      Material(
                        color: isPinned ? Colors.blue.shade50 : Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            Map<String, dynamic> friend = {
                              'id': friendId,
                              'name': name,
                              'profileImage': profileImageUrl ?? 'assets/default_profile_image.png',
                              'userId': friendProfileData['userId'] ?? friendId,
                            };

                            // Await the result from the ChatDetailScreen
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailScreen(friend: friend),
                              ),
                            );

                            // If a result is returned (e.g., 'user_unblocked'), refresh the state
                            if (result == 'user_unblocked' || result == 'chat_deleted') {
                              if (mounted) {
                                setState(() {
                                  _loadBlockedUsers(); // Refresh the blocked users list
                                });
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    String imageUrl = isAssetImage
                                        ? 'assets/default_profile_image.png'
                                        : profileImageUrl!;
                                    _showFullscreenImage(
                                      context,
                                      imageUrl,
                                      friendHeroTag,
                                    );
                                  },
                                  onLongPress: () {
                                    if (!isAssetImage) {
                                      _downloadImage(context, profileImageUrl);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Cannot download a default asset image.')),
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white10,
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Hero(
                                      tag: friendHeroTag,
                                      child: CircleAvatar(
                                        radius: 25,
                                        backgroundImage: avatarImage,
                                        backgroundColor: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 16,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isMuted)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 4.0),
                                              child: Icon(
                                                Icons.volume_off,
                                                size: 18,
                                                color: Theme.of(context).colorScheme.outline,
                                              ),
                                            ),
                                          if (isPinned)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 4.0),
                                              child: Icon(
                                                Icons.push_pin,
                                                size: 18,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTimestamp(lastMessageAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.outlineVariant,
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: Icon(
                                              Icons.more_horiz,
                                              color: Theme.of(context).colorScheme.outlineVariant,
                                            ),
                                            splashRadius: 18,
                                            onSelected: (value) {
                                              if (value == 'archive') {
                                                _archiveChat(chat.id);
                                              } else if (value == 'toggleMute') {
                                                _toggleMuteChat(chat.id, isMuted);
                                              } else if (value == 'togglePin') {
                                                _togglePinChat(chat.id, isPinned);
                                              } else if (value == 'toggleBlock') {
                                                if (isBlocked) {
                                                  _unblockUser(friendId);
                                                } else {
                                                  _blockUser(friendId);
                                                }
                                              }
                                            },
                                            itemBuilder: (BuildContext context) {
                                              return [
                                                const PopupMenuItem(
                                                  value: 'archive',
                                                  child: Text('Archive'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'toggleMute',
                                                  child: Text(isMuted ? 'Unmute' : 'Mute'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'togglePin',
                                                  child: Text(isPinned ? 'Unpin' : 'Pin'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'toggleBlock',
                                                  child: Text(isBlocked ? 'Unblock' : 'Block'),
                                                ),
                                              ];
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lastMessage,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: unreadCount > 0
                                                    ? Theme.of(context).colorScheme.onSurface
                                                    : Theme.of(context).colorScheme.outline,
                                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (unreadCount > 0) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primary,
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                unreadCount.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 32),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Divider(
                        color: Colors.grey.shade300,
                        height: 1,
                        indent: 80,
                        endIndent: 16,
                      ),
                    ],
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