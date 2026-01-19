import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/home_screen.dart';
import 'package:hyellow_w/followers_following_screen.dart';
import 'package:hyellow_w/user_list_screen.dart';
import 'FullscreenImageViewer.dart';
import 'package:hyellow_w/utils/download_profile_image.dart';

import 'content_screen.dart';
import 'follower_following1.dart';

class ProfileScreen1 extends StatefulWidget {
  final String userId;
  final String? name;
  final String? interest;
  final String? about;
  final String? title;
  final String? phone;
  final String? email;
  final String? profileImage;

  const ProfileScreen1({
    super.key,
    required this.userId,
    this.name,
    this.interest,
    this.about,
    this.title,
    this.phone,
    this.email,
    this.profileImage,
  });

  @override
  _ProfileScreen1State createState() => _ProfileScreen1State();
}

class _ProfileScreen1State extends State<ProfileScreen1> {
  String? _name;
  String? _interest;
  String? _about;
  String? _title;
  String? _phone;
  String? _email;
  String? _profileImage;

  String? currentUserId;
  bool isFollowing = false;
  bool isBlocked = false;
  bool _isBlockedByAuthor = false;
  bool _isLoadingProfileData = true;
  bool _isLoadingFollowStatus = true;
  bool _isLoadingBlockStatus = true;
  bool _isLoadingAuthorBlockStatus = true;

  Stream<DocumentSnapshot>? _friendsStream;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;

    _name = widget.name;
    _interest = widget.interest;
    _about = widget.about;
    _title = widget.title;
    _phone = widget.phone;
    _email = widget.email;
    _profileImage = widget.profileImage;

    _friendsStream = FirebaseFirestore.instance
        .collection('Friends')
        .doc(widget.userId)
        .snapshots();

    _fetchAndSetProfileData();
    _checkIfFollowing();
    _checkIfBlocked();
    _checkIfBlockedByAuthor();
  }

  // UPDATED: Helper function to check if the user is blocked by me
  Future<void> _checkIfBlocked() async {
    if (currentUserId == null || currentUserId == widget.userId) {
      if (mounted) {
        setState(() {
          isBlocked = false;
          _isLoadingBlockStatus = false;
        });
      }
      return;
    }

    try {
      final blockDoc = await FirebaseFirestore.instance.collection('Blocks').doc(currentUserId).get();
      List<dynamic> blockedUsers = blockDoc.data()?['blocked'] ?? [];

      if (mounted) {
        setState(() {
          isBlocked = blockedUsers.contains(widget.userId);
          _isLoadingBlockStatus = false;
        });
      }
    } catch (e) {
      print('Error checking my block status: $e');
      if (mounted) {
        setState(() {
          isBlocked = false;
          _isLoadingBlockStatus = false;
        });
      }
    }
  }

  // NEW: Helper function to check if the user is blocked by the profile author
  Future<void> _checkIfBlockedByAuthor() async {
    if (currentUserId == null || currentUserId == widget.userId) {
      if (mounted) {
        setState(() {
          _isBlockedByAuthor = false;
          _isLoadingAuthorBlockStatus = false;
        });
      }
      return;
    }

    try {
      final blockDoc = await FirebaseFirestore.instance.collection('Blocks').doc(widget.userId).get();
      List<dynamic> blockedUsers = blockDoc.data()?['blocked'] ?? [];

      if (mounted) {
        setState(() {
          _isBlockedByAuthor = blockedUsers.contains(currentUserId);
          _isLoadingAuthorBlockStatus = false;
        });
      }
    } catch (e) {
      print('Error checking author\'s block status: $e');
      if (mounted) {
        setState(() {
          _isBlockedByAuthor = false;
          _isLoadingAuthorBlockStatus = false;
        });
      }
    }
  }

  Future<void> unblockUser(String userId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to unblock a user.')),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('Blocks').doc(currentUserId).update({
        'blocked': FieldValue.arrayRemove([userId])
      });

      if (mounted) {
        setState(() {
          isBlocked = false;
          // Also re-check the other way, in case this user also blocked me
          _checkIfBlockedByAuthor();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User has been unblocked.')),
        );
      }
    } catch (e) {
      print('Error unblocking user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unblock user. Please try again.')),
        );
      }
    }
  }

  Future<void> blockUser(String userId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to block a user.')),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('Blocks').doc(currentUserId).set({
        'blocked': FieldValue.arrayUnion([userId])
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          isBlocked = true;
          // Also set the following status to false immediately
          isFollowing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User has been blocked.')),
        );
      }
    } catch (e) {
      print('Error blocking user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to block user. Please try again.')),
        );
      }
    }
  }


  Future<void> _fetchAndSetProfileData() async {
    setState(() {
      _isLoadingProfileData = true;
    });

    try {
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final profileSnap = await FirebaseFirestore.instance.collection('profiles').doc(widget.userId).get();

      if (mounted) {
        setState(() {
          if (userSnap.exists) {
            final userData = userSnap.data() as Map<String, dynamic>;
            _name = userData['name'] as String?;
            _interest = userData['interest'] as String?;
          } else {
            _name = 'User Not Found';
            _interest = 'N/A';
          }

          if (profileSnap.exists) {
            final profileData = profileSnap.data() as Map<String, dynamic>;
            _about = profileData['about'] as String?;
            _title = profileData['title'] as String?;
            _phone = profileData['phone'] as String?;
            _email = profileData['email'] as String?;
            _profileImage = profileData['profileImage'] as String?;
          } else {
            _about = 'Profile details missing.';
            _title = 'N/A';
            _phone = 'N/A';
            _email = 'N/A';
            _profileImage = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _name = _name ?? 'Error Loading';
          _interest = _interest ?? 'N/A';
          _about = _about ?? 'Error loading details.';
          _title = _title ?? 'N/A';
          _phone = _phone ?? 'N/A';
          _email = _email ?? 'N/A';
          _profileImage = _profileImage ?? null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfileData = false;
        });
      }
    }
  }

  Future<void> _checkIfFollowing() async {
    setState(() {
      _isLoadingFollowStatus = true;
    });

    if (currentUserId == null || currentUserId == widget.userId) {
      if (mounted) {
        setState(() {
          isFollowing = false;
          _isLoadingFollowStatus = false;
        });
      }
      return;
    }

    // UPDATED: Added a check for isBlocked before proceeding with follow status check
    if (isBlocked) {
      if (mounted) {
        setState(() {
          isFollowing = false;
          _isLoadingFollowStatus = false;
        });
      }
      return;
    }

    // NEW: Check if the current user is blocked by the author
    if (_isBlockedByAuthor) {
      if (mounted) {
        setState(() {
          isFollowing = false;
          _isLoadingFollowStatus = false;
        });
      }
      return;
    }

    try {
      final currentUserFriendsDoc = await FirebaseFirestore.instance
          .collection('Friends')
          .doc(currentUserId)
          .get();
      final currentUserFriendsData = currentUserFriendsDoc.data() as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          isFollowing = (currentUserFriendsData?['followingMetadata'] as Map<String, dynamic>?)
              ?.containsKey(widget.userId) ?? false;
          _isLoadingFollowStatus = false;
        });
      }
    } catch (e) {
      print("Error checking follow status: $e");
      if (mounted) {
        setState(() {
          isFollowing = false;
          _isLoadingFollowStatus = false;
        });
      }
    }
  }

  Future<void> toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    currentUserId = currentUser.uid;
    if (currentUserId == widget.userId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You cannot follow or unfollow yourself.")),
        );
      }
      return;
    }

    // UPDATED: Now check if either party has blocked the other
    if (isBlocked || _isBlockedByAuthor) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You cannot follow a blocked user.")),
        );
      }
      return;
    }

    final userFriendsDocRef = FirebaseFirestore.instance.collection('Friends').doc(currentUserId);
    final followedUserDocRef = FirebaseFirestore.instance.collection('Friends').doc(widget.userId);

    final bool wasFollowing = isFollowing;
    if (mounted) {
      setState(() {
        isFollowing = !isFollowing;
      });
    }

    try {
      if (!wasFollowing) {
        await userFriendsDocRef.set({
          'followingMetadata': {
            widget.userId: {'timestamp': FieldValue.serverTimestamp()}
          }
        }, SetOptions(merge: true));

        await followedUserDocRef.set({
          'followersMetadata': {
            currentUserId: {'timestamp': FieldValue.serverTimestamp()}
          }
        }, SetOptions(merge: true));

        final currentUserProfileSnap =
        await FirebaseFirestore.instance.collection('profiles').doc(currentUserId!).get();
        final currentUserProfileData = currentUserProfileSnap.data();
        final senderProfileImage = currentUserProfileData?['profileImage'] as String?;

        final currentUserNameSnap = await FirebaseFirestore.instance.collection('users').doc(currentUserId!).get();
        final currentUserName = currentUserNameSnap.data()?['name'] ?? 'Someone';

        await FirebaseFirestore.instance.collection('notifications').add({
          'recipientId': widget.userId,
          'senderId': currentUserId,
          'type': 'new_follower',
          'message': '$currentUserName started following you.',
          'timestamp': Timestamp.now(),
          'isRead': false,
          'imageUrl': senderProfileImage,
        });
      } else {
        await userFriendsDocRef.update({
          'followingMetadata.${widget.userId}': FieldValue.delete(),
        });

        await followedUserDocRef.update({
          'followersMetadata.${currentUserId}': FieldValue.delete(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status: $e')),
        );
        setState(() {
          isFollowing = wasFollowing;
        });
      }
    }
  }

  // --- IMAGE HELPERS ---
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

  void _downloadImage(BuildContext context, String imageUrl) async {
    if (imageUrl.isNotEmpty && !imageUrl.contains('assets/')) {
      await DownloadProfileImage.downloadAndSaveImage(context, imageUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No downloadable image available.')),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final isEitherPartyBlocked = isBlocked || _isBlockedByAuthor;

    if (_isLoadingProfileData ||
        _isLoadingFollowStatus ||
        _isLoadingBlockStatus ||
        _isLoadingAuthorBlockStatus) {
      return Scaffold(
        appBar: AppBar(title: const Text("Profile Loading...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final displayProfileImage = _profileImage != null &&
        _profileImage!.isNotEmpty &&
        !_profileImage!.contains('assets/')
        ? NetworkImage(_profileImage!)
        : const AssetImage('assets/default_profile_image.png') as ImageProvider;

    final displayName = _name ?? 'Unknown User';
    final displayInterest = _interest ?? 'No interest specified.';
    final displayAbout = _about ?? 'No "about" section provided.';
    final displayTitle = _title ?? 'No title provided.';
    final displayPhone = _phone ?? 'N/A';
    final displayEmail = _email ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Profile",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.teal,
            fontSize: 13,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (currentUserId != null && currentUserId != widget.userId)
            IconButton(
              icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ListTile(
                          leading: Icon(isBlocked ? Icons.lock_open : Icons.block),
                          title: Text(isBlocked ? 'Unblock' : 'Block'),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            if (isBlocked) {
                              unblockUser(widget.userId);
                            } else {
                              blockUser(widget.userId);
                            }
                          },
                        ),
                      ],
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // --- PROFILE IMAGE ---
                Center(
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.grey,
                    child: GestureDetector(
                      onTap: () {
                        if (_profileImage != null) {
                          _showFullscreenImage(context, _profileImage!, _profileImage!);
                        }
                      },
                      onLongPress: () {
                        if (_profileImage != null) {
                          _downloadImage(context, _profileImage!);
                        }
                      },
                      child: Hero(
                        tag: _profileImage ?? 'default_profile_tag',
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: displayProfileImage,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // --- FOLLOWERS / FOLLOWING ---
                StreamBuilder<DocumentSnapshot>(
                  stream: _friendsStream,
                  builder: (context, snapshot) {
                    int currentFollowersCount = 0;
                    int currentFollowingCount = 0;

                    if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      currentFollowersCount = (data['followersMetadata'] as Map<String, dynamic>?)?.keys.length ?? 0;
                      currentFollowingCount = (data['followingMetadata'] as Map<String, dynamic>?)?.keys.length ?? 0;
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCountButton("Followers", currentFollowersCount),
                        _buildCountButton("Following", currentFollowingCount),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 15),

                // --- FOLLOW BUTTON / BLOCKED ---
                if (currentUserId != widget.userId && !isEitherPartyBlocked)
                  Center(
                    child: TextButton(
                      onPressed: toggleFollow,
                      style: TextButton.styleFrom(
                        foregroundColor: isFollowing ? const Color(0xFF8B0000) : Colors.teal,
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isFollowing ? const Color(0xFF8B0000) : Colors.teal,
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                    ),
                  ),

                if (isEitherPartyBlocked)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isBlocked ? 'Blocked' : 'User Unavailable',
                        style: TextStyle(color: isDark ? colors.onSurfaceVariant : Colors.black54),
                      ),
                    ),
                  ),

                const SizedBox(height: 1),

                // --- CONTENT BUTTON ---
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ContentScreen(userId: widget.userId)),
                      );
                    },
                    style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white : Colors.black),
                    child: Text(currentUserId == widget.userId ? "My Activity" : "View uploads"),
                  ),
                ),

                const SizedBox(height: 20),
                _buildSectionHeader(context, "Personal Info"),
                _buildProfileInfo("Full Name", displayName, isDark, colors),
                _buildAboutSection("About", displayAbout, isDark, colors),
                _buildProfileInfo("Interest", displayInterest, isDark, colors),
                _buildProfileInfo("Title", displayTitle, isDark, colors),
                const SizedBox(height: 20),
                _buildSectionHeader(context, "Contact Info"),
                _buildProfileInfo("Phone", displayPhone, isDark, colors),
                _buildProfileInfo("Email", displayEmail, isDark, colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountButton(String label, int count) {
    return Column(
      children: [
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowersFollowing1(
                  otherUserId: widget.userId,
                ),
              ),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white, // 🔹 White text
          ),
          child: Text(label),
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white, // 🔹 White count text
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }


  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.black54,
            width: 1.0,
          ),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: colors.secondary, // now works
        ),
      ),
    );
  }

  Widget _buildProfileInfo(String label, String value, bool isDark, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
          Flexible(
            child: Text(value, style: TextStyle(fontSize: 16, color: isDark ? colors.onSurfaceVariant : Colors.black87), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(String label, String value, bool isDark, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 16, color: isDark ? colors.onSurfaceVariant : Colors.black87),
            textAlign: TextAlign.justify,
            maxLines: 15,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
