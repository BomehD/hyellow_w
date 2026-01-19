import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/profile_screen1.dart';

class FollowersFollowingScreen extends StatelessWidget {
  const FollowersFollowingScreen({super.key});

  // New helper function for responsive layout width
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
    // Responsive variables
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = _getContentWidth(screenWidth);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Friends',
            style: TextStyle(color: Color(0xFF106C70), fontSize: 13),
          ),
          bottom: const TabBar(
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF106C70),
            indicatorWeight: 2.5,
            tabs: [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
            ],
          ),
        ),
        body: Center(
          child: SizedBox(
            width: contentWidth,
            child: const TabBarView(
              children: [
                FollowersTab(),
                FollowingTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FollowersTab extends StatelessWidget {
  const FollowersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Center(child: Text('Please sign in to view followers.'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Friends').doc(currentUserId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
          return const Center(child: Text('No followers yet.', style: TextStyle(fontSize: 16)));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final followers = data['followersMetadata'] as Map<String, dynamic>? ?? {};
        final followerIds = followers.keys.toList();

        if (followerIds.isEmpty) {
          return const Center(child: Text('No followers yet.', style: TextStyle(fontSize: 16)));
        }

        return ListView.builder(
          itemCount: followerIds.length,
          itemBuilder: (context, index) {
            return FutureBuilder<Map<String, dynamic>>(
              key: ValueKey(followerIds[index]), // Key ensures proper widget tree updates
              future: _fetchUserProfileData(followerIds[index]),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const ListTile(title: Text('Loading...'));
                }

                final profile = userSnapshot.data!;
                return UserInfoTile(
                  userId: followerIds[index],
                  displayName: profile['name'] ?? 'Unnamed',
                  profileImageUrl: profile['profileImage'] ?? '',
                  onRemovePressed: () async {
                    await _removeFollower(currentUserId, followerIds[index], context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _removeFollower(String currentUserId, String followerId, BuildContext context) async {
    try {
      // Remove follower from current user's document
      await FirebaseFirestore.instance.collection('Friends').doc(currentUserId).update({
        'followersMetadata.$followerId': FieldValue.delete(),
      });
      // Also remove current user from follower's following list
      await FirebaseFirestore.instance.collection('Friends').doc(followerId).update({
        'followingMetadata.$currentUserId': FieldValue.delete(),
      });


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follower removed.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing follower: $e')),
      );
    }
  }
}

class FollowingTab extends StatelessWidget {
  const FollowingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Center(child: Text('Please sign in to view who you are following.'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Friends').doc(currentUserId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
          return const Center(child: Text('No following yet.', style: TextStyle(fontSize: 16)));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final following = data['followingMetadata'] as Map<String, dynamic>? ?? {};
        final followingIds = following.keys.toList();

        if (followingIds.isEmpty) {
          return const Center(child: Text('No following yet.', style: TextStyle(fontSize: 16)));
        }

        return ListView.builder(
          itemCount: followingIds.length,
          itemBuilder: (context, index) {
            return FutureBuilder<Map<String, dynamic>>(
              key: ValueKey(followingIds[index]), // Key ensures proper widget tree updates
              future: _fetchUserProfileData(followingIds[index]),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const ListTile(title: Text('Loading...'));
                }

                final profile = userSnapshot.data!;
                return UserInfoTile(
                  userId: followingIds[index],
                  displayName: profile['name'] ?? 'Unnamed',
                  profileImageUrl: profile['profileImage'] ?? '',
                  onRemovePressed: () async {
                    await _removeFollowing(currentUserId, followingIds[index], context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _removeFollowing(String currentUserId, String targetUserId, BuildContext context) async {
    try {
      // Remove target user from current user's following list
      await FirebaseFirestore.instance.collection('Friends').doc(currentUserId).update({
        'followingMetadata.$targetUserId': FieldValue.delete(),
      });
      // Also remove current user from target user's followers list
      await FirebaseFirestore.instance.collection('Friends').doc(targetUserId).update({
        'followersMetadata.$currentUserId': FieldValue.delete(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unfollowed successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unfollowing: $e')),
      );
    }
  }
}

class UserInfoTile extends StatelessWidget {
  final String userId;
  final String displayName;
  final String profileImageUrl;
  final VoidCallback onRemovePressed;

  const UserInfoTile({
    super.key,
    required this.userId,
    required this.displayName,
    required this.profileImageUrl,
    required this.onRemovePressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profileImageUrl.isNotEmpty
            ? NetworkImage(profileImageUrl)
            : const AssetImage('assets/default_profile_image.png') as ImageProvider,
      ),
      title: Text(
        displayName,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle, color: Colors.grey),
        onPressed: onRemovePressed,
      ),
      onTap: () async {
        try {
          final profileData = await FirebaseFirestore.instance.collection('profiles').doc(userId).get();
          final userData = await FirebaseFirestore.instance.collection('users').doc(userId).get();

          final profile = profileData.data() ?? {};
          final user = userData.data() ?? {};

          String name = profile['name'] ?? user['name'] ?? 'Unnamed';
          String about = profile['about'] ?? 'No bio available';
          String title = profile['title'] ?? 'No title available';
          String phone = profile['phone'] ?? 'No phone';
          String email = profile['email'] ?? 'No email';
          String interest = _extractInterest(profile['interest'] ?? user['interests']);
          String image = profile['profileImage'] ?? 'assets/default_profile_image.png';

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen1(
                userId: userId,
                name: name,
                about: about,
                title: title,
                phone: phone,
                email: email,
                interest: interest,
                profileImage: image,
              ),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: $e')),
          );
        }
      },
    );
  }

  String _extractInterest(dynamic rawInterest) {
    if (rawInterest is List && rawInterest.isNotEmpty) {
      return rawInterest.first.toString();
    } else if (rawInterest is String && rawInterest.isNotEmpty) {
      return rawInterest;
    }
    return 'General';
  }
}

Future<Map<String, dynamic>> _fetchUserProfileData(String userId) async {
  final profileSnapshot = await FirebaseFirestore.instance.collection('profiles').doc(userId).get();
  final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();

  final profileData = profileSnapshot.data() ?? {};
  final userData = userSnapshot.data() ?? {};

  return {
    'name': profileData['name'] ?? userData['name'] ?? 'Unnamed',
    'profileImage': profileData['profileImage'] ?? '',
  };
}