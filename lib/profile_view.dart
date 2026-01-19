// File: ProfileView.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/home_screen.dart';
import 'package:hyellow_w/profile_page.dart';
import 'package:hyellow_w/followers_following_screen.dart';
import 'FullscreenImageViewer.dart';
import 'my_content_screen.dart';
import 'saved_posts_screen.dart';
import 'package:hyellow_w/utils/download_profile_image.dart';

class ProfileView extends StatefulWidget {
  final String name;
  final String interest;
  final String about;
  final String title;
  final String phone;
  final String email;
  final String profileImage;

  const ProfileView({
    super.key,
    required this.name,
    required this.interest,
    required this.about,
    required this.title,
    required this.phone,
    required this.email,
    required this.profileImage,
  });

  @override
  _ProfileViewState createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late String name;
  late String interest;
  late String about;
  late String title;
  late String phone;
  late String email;
  late String profileImage;

  int followersCount = 0;
  int followingCount = 0;
  String? currentUserId;

  Stream<DocumentSnapshot>? _friendsStream;

  @override
  void initState() {
    super.initState();
    name = widget.name;
    interest = widget.interest;
    about = widget.about;
    title = widget.title;
    phone = widget.phone;
    email = widget.email;
    profileImage = widget.profileImage;

    _fetchCounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _friendsStream = FirebaseFirestore.instance
          .collection('Friends')
          .doc(currentUserId)
          .snapshots();
    }
  }

  Future<void> _fetchCounts() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      currentUserId = currentUser.uid;

      final userFriendsDoc =
      FirebaseFirestore.instance.collection('Friends').doc(currentUserId);
      final snapshot = await userFriendsDoc.get();
      final data = snapshot.data();

      if (data != null) {
        if (mounted) {
          setState(() {
            followersCount =
                (data['followersMetadata'] as Map<String, dynamic>?)
                    ?.keys
                    .length ??
                    0;
            followingCount =
                (data['followingMetadata'] as Map<String, dynamic>?)
                    ?.keys
                    .length ??
                    0;
          });
        }
      }
    }
  }

  void _showFullscreenImage(
      BuildContext context, String imageUrl, String heroTag) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: theme.textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white : theme.primaryColor,
            fontSize: 13,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : colors.onSurface),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/');
          },
        ),
        backgroundColor:
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0.5,
      ),
      body: Center(
        child: SizedBox(
          width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: colors.outline,
                    child: GestureDetector(
                      onTap: () {
                        if (profileImage.isNotEmpty &&
                            !profileImage.contains('assets/')) {
                          _showFullscreenImage(
                            context,
                            profileImage,
                            profileImage,
                          );
                        }
                      },
                      onLongPress: () {
                        _downloadImage(context, profileImage);
                      },
                      child: Hero(
                        tag: profileImage.isNotEmpty &&
                            !profileImage.contains('assets/')
                            ? profileImage
                            : 'default_profile_tag',
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage:
                          profileImage.isNotEmpty &&
                              !profileImage.contains('assets/')
                              ? NetworkImage(profileImage)
                              : const AssetImage(
                              'assets/default_profile_image.png')
                          as ImageProvider,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                StreamBuilder<DocumentSnapshot>(
                  stream: _friendsStream,
                  builder: (context, snapshot) {
                    int currentFollowersCount = 0;
                    int currentFollowingCount = 0;

                    if (snapshot.hasData &&
                        snapshot.data!.exists &&
                        snapshot.data!.data() != null) {
                      final data =
                      snapshot.data!.data() as Map<String, dynamic>;
                      currentFollowersCount =
                          (data['followersMetadata'] as Map<String, dynamic>?)
                              ?.keys
                              .length ??
                              0;
                      currentFollowingCount =
                          (data['followingMetadata'] as Map<String, dynamic>?)
                              ?.keys
                              .length ??
                              0;
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const FollowersFollowingScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor:
                                isDark ? Colors.white : colors.onSurface,
                              ),
                              child: const Text('Followers'),
                            ),
                            Text(
                              '$currentFollowersCount',
                              style: TextStyle(
                                color:
                                isDark ? Colors.white : colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const FollowersFollowingScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor:
                                isDark ? Colors.white : colors.onSurface,
                              ),
                              child: const Text('Following'),
                            ),
                            Text(
                              '$currentFollowingCount',
                              style: TextStyle(
                                color:
                                isDark ? Colors.white : colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 15),

                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(
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

                      if (result != null && result is Map<String, dynamic>) {
                        if (mounted) {
                          setState(() {
                            name = result['name'] ?? name;
                            interest = result['interest'] ?? interest;
                            about = result['about'] ?? about;
                            title = result['title'] ?? title;
                            phone = result['phone'] ?? phone;
                            email = result['email'] ?? email;
                            profileImage =
                                result['profileImage'] ?? profileImage;
                          });
                        }
                      }
                    },
                    icon: Icon(Icons.edit,
                        color: isDark ? Colors.white : const Color(0xFF106C70)),
                    label: Text(
                      "Edit Profile",
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF106C70),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isDark ? Colors.white : const Color(0xFF106C70),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 5),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MyContentScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : colors.onSurface,
                    ),
                    child: const Text("My Activity"),
                  ),
                ),

                const SizedBox(height: 1),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SavedPostsScreen()),
                      );
                    },
                    icon: Icon(Icons.bookmark_border,
                        size: 20,
                        color: isDark ? Colors.white : colors.onSurface),
                    label: Text(
                      "Saved Posts",
                      style: TextStyle(
                          color: isDark ? Colors.white : colors.onSurface),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _buildSectionHeader(context, "Personal Info"),
                _buildProfileInfo("Full Name", name, isDark, colors),
                _buildAboutSection("About", about, isDark, colors),
                _buildProfileInfo("Interest", interest, isDark, colors),
                _buildProfileInfo("Title", title, isDark, colors),
                const SizedBox(height: 20),
                _buildSectionHeader(context, "Contact Info"),
                _buildProfileInfo("Phone", phone, isDark, colors),
                _buildProfileInfo("Email", email, isDark, colors),

              ],
            ),
          ),
        ),
      ),
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


  Widget _buildProfileInfo(
      String label, String value, bool isDark, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(0),
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : colors.onSurface)),
          Flexible(
            child: Text(value,
                style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : colors.onSurface),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(
      String label, String value, bool isDark, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(0),
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : colors.onSurface)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : colors.onSurface),
              textAlign: TextAlign.justify,
              maxLines: 15,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
