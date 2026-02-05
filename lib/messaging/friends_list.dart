import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/FullscreenImageViewer.dart';
import 'chat_detail_screen.dart';

class FriendsList extends StatefulWidget {
  const FriendsList({super.key});

  @override
  _FriendsListState createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _allFriends = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterFriends();
      });
    }
  }

  void _filterFriends() {
    if (_searchQuery.isEmpty) {
      _filteredFriends = _allFriends;
    } else {
      _filteredFriends = _allFriends.where((friend) {
        final name = (friend['name'] as String?)?.toLowerCase() ?? '';
        final interest = (friend['interest'] as String?)?.toLowerCase() ?? '';
        return name.contains(_searchQuery) || interest.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _getFriendsList();
      if (mounted) {
        setState(() {
          _allFriends = friends;
          _filterFriends();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load friends: $e')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getFriendsList() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user is logged in');

    String userId = currentUser.uid;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('Friends')
        .doc(userId)
        .get();

    if (!userDoc.exists || userDoc.data() == null) {
      return [];
    }

    Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
    Map<String, dynamic> followingMetadata =
        userData['followingMetadata'] as Map<String, dynamic>? ?? {};
    Set<String> friendIds = followingMetadata.keys.toSet();

    if (friendIds.isEmpty) {
      return [];
    }

    List<Map<String, dynamic>> friends = [];
    const int chunkSize = 10;
    List<String> friendIdsList = friendIds.toList();

    for (int i = 0; i < friendIdsList.length; i += chunkSize) {
      final chunk = friendIdsList.sublist(
          i, i + chunkSize > friendIdsList.length ? friendIdsList.length : i + chunkSize);

      var usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      var profilesSnapshot = await FirebaseFirestore.instance
          .collection('profiles')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      Map<String, DocumentSnapshot> profilesMap = {
        for (var doc in profilesSnapshot.docs) doc.id: doc
      };

      for (var userDoc in usersSnapshot.docs) {
        final friendId = userDoc.id;
        final userData = userDoc.data();
        final profileDoc = profilesMap[friendId];

        // SAFE INTEREST ACCESS
        dynamic rawInterest = userData['interest'] ?? userData['interests'];
        String interest;
        if (rawInterest is List && rawInterest.isNotEmpty) {
          interest = rawInterest.first.toString();
        } else if (rawInterest is String && rawInterest.isNotEmpty) {
          interest = rawInterest;
        } else {
          interest = 'General';
        }

        // SAFE PROFILE IMAGE ACCESS
        String? profileImage;
        if (profileDoc != null && profileDoc.exists && profileDoc.data() != null) {
          final profileData = profileDoc.data() as Map<String, dynamic>;
          profileImage = profileData['profileImage'] as String?;
        }

        friends.add({
          'id': friendId,
          'name': userData['name'] ?? 'No Name',
          'profileImage': profileImage,
          'interest': interest,
        });
      }
    }
    return friends;
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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        toolbarHeight: 70,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25.0),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              ),
              style: const TextStyle(fontSize: 16.0),
            ),
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredFriends.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchQuery.isNotEmpty
                        ? Icons.person_search_outlined
                        : Icons.people_alt_outlined,
                    size: 70,
                    color: Colors.grey[200],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No friends found matching "${_searchController.text}".'
                        : 'You have no friends yet. Add some to get started!',
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
          )
              : ListView.builder(
            itemCount: _filteredFriends.length,
            itemBuilder: (context, index) {
              final friend = _filteredFriends[index];
              String? profileImageUrl = friend['profileImage'];
              bool isAssetImage =
                  profileImageUrl == null || profileImageUrl.isEmpty;
              String friendId = friend['id'] ?? '';
              String heroTag = 'friend-profile-$friendId';

              return Column(
                children: [
                  ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        if (!isAssetImage) {
                          _showFullscreenImage(
                            context,
                            profileImageUrl!,
                            heroTag,
                          );
                        }
                      },
                      child: Hero(
                        tag: heroTag,
                        child: CircleAvatar(
                          backgroundImage: isAssetImage
                              ? const AssetImage(
                              'assets/default_profile_image.png')
                          as ImageProvider
                              : NetworkImage(profileImageUrl!),
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                    ),
                    title: Text(
                      friend['name'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      friend['interest'],
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      Map<String, dynamic> friendData = {
                        'id': friend['id'] ?? '',
                        'userId': friend['id'] ?? '',
                        'name': friend['name'] ?? 'Unknown',
                        'profileImage': friend['profileImage'] ?? '',
                      };

                      if (friendData['userId'].isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Friend userId is missing. Cannot open chat.')),
                        );
                        return;
                      }

                      Navigator.pop(context, friendData);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
