import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/profile_screen1.dart';

class FollowersFollowing1 extends StatelessWidget {
  final String otherUserId;

  const FollowersFollowing1({super.key, required this.otherUserId});

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
            'Followers & Following',
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
            child: TabBarView(
              children: [
                UserFriendsTab(userId: otherUserId, isFollowersTab: true),
                UserFriendsTab(userId: otherUserId, isFollowersTab: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserFriendsTab extends StatelessWidget {
  final String userId;
  final bool isFollowersTab;

  const UserFriendsTab({super.key, required this.userId, required this.isFollowersTab});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Friends').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
          return Center(
            child: Text(
              isFollowersTab ? 'No followers yet.' : 'No following yet.',
              style: const TextStyle(fontSize: 16),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final metadata = isFollowersTab
            ? (data['followersMetadata'] as Map<String, dynamic>? ?? {})
            : (data['followingMetadata'] as Map<String, dynamic>? ?? {});
        final userIds = metadata.keys.toList();

        if (userIds.isEmpty) {
          return Center(
            child: Text(
              isFollowersTab ? 'No followers yet.' : 'No following yet.',
              style: const TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: userIds.length,
          itemBuilder: (context, index) {
            return UserInfoTile(
              userId: userIds[index],
              onRemovePressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cannot remove ${isFollowersTab ? "followers" : "following"} from this view',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class UserInfoTile extends StatelessWidget {
  final String userId;
  final VoidCallback onRemovePressed;

  const UserInfoTile({
    super.key,
    required this.userId,
    required this.onRemovePressed,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
            title: Text('Loading...'),
          );
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists || userSnapshot.data!.data() == null) {
          return const SizedBox.shrink(); // Hide if user data not found
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final displayName = userData['name'] ?? 'Unnamed';

        return GestureDetector(
          onTap: () async {
            try {
              final profileSnapshot = await FirebaseFirestore.instance
                  .collection('profiles')
                  .doc(userId)
                  .get();

              final profileData = profileSnapshot.data() ?? {};

              String name = profileData['name'] ?? userData['name'] ?? 'Unnamed';

              String extractInterest(dynamic rawInterest) {
                if (rawInterest is List && rawInterest.isNotEmpty) {
                  return rawInterest.first.toString();
                } else if (rawInterest is String && rawInterest.isNotEmpty) {
                  return rawInterest;
                }
                return 'General';
              }

              String interest = extractInterest(profileData['interest'] ?? userData['interests']);
              String about = profileData['about'] ?? 'No bio available';
              String title = profileData['title'] ?? 'No title available';
              String phone = profileData['phone'] ?? 'No phone number provided';
              String email = profileData['email'] ?? 'No email provided';
              String profileImage = profileData['profileImage'] ?? 'assets/default_profile_image.png';

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen1(
                    userId: userId,
                    name: name,
                    interest: interest,
                    about: about,
                    title: title,
                    phone: phone,
                    email: email,
                    profileImage: profileImage,
                  ),
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          child: ListTile(
            leading: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('profiles').doc(userId).get(),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState == ConnectionState.waiting) {
                  return const CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2));
                }
                String imageUrl = '';
                if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
                  final data = profileSnapshot.data!.data() as Map<String, dynamic>?;
                  imageUrl = data?['profileImage'] ?? '';
                }
                return CircleAvatar(
                  backgroundImage: imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : const AssetImage('assets/default_profile_image.png') as ImageProvider,
                );
              },
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.grey),
              onPressed: onRemovePressed,
            ),
          ),
        );
      },
    );
  }
}