import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hyellow_w/profile_view.dart';
import 'profile_screen1.dart';
import 'FullscreenImageViewer.dart';
// Import the utility file for image downloads
import 'package:hyellow_w/utils/download_profile_image.dart';

// Helper function to show a fullscreen image (moved outside the widget)
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

// Helper function to handle image downloading
void _downloadImage(BuildContext context, String imageUrl) async {
  // Use a utility class to handle the download logic
  await DownloadProfileImage.downloadAndSaveImage(context, imageUrl);
}

class CustomCard extends StatelessWidget {
  final String name;
  final String? profileImage;
  final VoidCallback onAddPressed;
  final VoidCallback onRemovePressed;
  final String currentUserId;
  final String userId;
  final bool isFollowing;

  CustomCard({
    required this.name,
    this.profileImage,
    required this.onAddPressed,
    required this.onRemovePressed,
    required this.currentUserId,
    required this.userId,
    required this.isFollowing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      constraints: BoxConstraints(
        maxWidth: 400,
        maxHeight: 320,
      ),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C2C2C),
            Color(0xFF1A1A1A),
          ],
        )
            : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFFAFAFA),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? null
            : Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
          // Decorative circle elements
          Positioned(
          top: -30,
          right: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.amber.withOpacity(0.1)
                  : Colors.amber.withOpacity(0.05),
            ),
          ),
        ),
        Positioned(
          bottom: -20,
          left: -20,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.05),
            ),
          ),
        ),
        // Main content
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture (moved to top)
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                        Colors.amber.shade400,
                        Colors.orange.shade600,
                      ]
                          : [
                        Colors.amber.shade300,
                        Colors.orange.shade500,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.amber.withOpacity(0.3)
                            : Colors.amber.withOpacity(0.2),
                        spreadRadius: 0,
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: GestureDetector(
                      onTap: () {
                        // Only show fullscreen view for network images
                        if (profileImage != null && profileImage!.isNotEmpty && !profileImage!.contains('assets/')) {
                          // Create a unique hero tag using the image URL
                          String heroTag = profileImage!;
                          _showFullscreenImage(context, profileImage!, heroTag);
                        }
                      },
                      onLongPress: () {
                        // Only allow download for network images
                        if (profileImage != null && profileImage!.isNotEmpty && !profileImage!.contains('assets/')) {
                          _downloadImage(context, profileImage!);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(70),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Color(0xFF2C2C2C) : Colors.white,
                          ),
                          child: profileImage != null && profileImage!.isNotEmpty
                              ? Hero(
                            tag: profileImage!,
                            child: Image.network(
                              profileImage!,
                              width: 132,
                              height: 132,
                              fit: BoxFit.cover,
                            ),
                          )
                              : Hero(
                            tag: 'default_profile_tag',
                            child: Image.asset(
                              'assets/default_profile_image.png',
                              width: 132,
                              height: 132,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // User's Name wrapped in GestureDetector
              GestureDetector(
                onTap: () async {
                  try {
                    // Get the current user's ID from FirebaseAuth
                    User? currentUser = FirebaseAuth.instance.currentUser;

                    // Check if the current user ID matches the tapped user's ID
                    if (currentUser != null && currentUser.uid == userId) {
                      // Fetch the current user's profile data
                      DocumentSnapshot userDoc = await FirebaseFirestore.instance
                          .collection('profiles')
                          .doc(currentUser.uid) // Use the current user's ID to fetch the document
                          .get();

                      // Initialize profile variables for the current user
                      String name = userDoc['name'] ?? '';
                      String interest = userDoc['interest'] ?? '';
                      String about = userDoc['about'] ?? '';
                      String title = userDoc['title'] ?? '';
                      String phone = userDoc['phone'] ?? '';
                      String email = userDoc['email'] ?? '';
                      String profileImage = userDoc['profileImage'] ?? 'assets/default_profile_image.png';

                      // Navigate to ProfileView with the retrieved data
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileView(
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
                    } else {
                      // Fetch profile data from 'profiles' collection for other users
                      final profileSnapshot = await FirebaseFirestore.instance
                          .collection('profiles')
                          .doc(userId)
                          .get();

                      Map<String, dynamic>? profileData = profileSnapshot.exists
                          ? profileSnapshot.data()
                          : null;

                      // Fetch fallback data from 'users' collection
                      final userSnapshot = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .get();

                      Map<String, dynamic>? userData = userSnapshot.exists
                          ? userSnapshot.data()
                          : null;

                      // Determine data to use for navigation
                      String name = profileData?['name'] ?? userData?['name'] ?? 'Unnamed'; // Fallback to 'Unnamed' if all are null

                      // Retrieve interests logic (Handle both string and list types)
                      dynamic interests = profileData?['interest'] ?? userData?['interests']; // Supports both profile and user interests
                      String interest = '';

                      if (interests is List) {
                        // If interests is a list, get the first element
                        interest = (interests.isNotEmpty) ? interests[0] : 'General'; // Fallback to 'General'
                      } else if (interests is String) {
                        // If interests is a string, use it directly
                        interest = interests.isNotEmpty ? interests : 'General'; // Fallback to 'General' if empty
                      } else {
                        // If interests is neither a list nor a string, use 'General'
                        interest = 'General';
                      }

                      // Retrieve other profile fields
                      String about = profileData?['about'] ?? 'No bio available';
                      String title = profileData?['title'] ?? 'No title available';
                      String phone = profileData?['phone'] ?? 'No phone number provided';
                      String email = profileData?['email'] ?? 'No email provided';
                      String profileImage = profileData?['profileImage'] ?? 'assets/default_profile_image.png';

                      // Navigate to ProfileScreen1
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen1(
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
                    }
                  } catch (e) {
                    // Handle errors gracefully
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('An error occurred: ${e.toString()}')),
                    );
                  }
                },
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              // Conditionally show "Add" or "Remove" Button
              if (userId != currentUserId)
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: isFollowing
                        ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: isDark
                          ? [
                        Colors.red.shade400,
                        Colors.red.shade600,
                      ]
                          : [
                        Colors.red.shade300,
                        Colors.red.shade500,
                      ],
                    )
                        : LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: isDark
                          ? [
                        Colors.amber.shade400,
                        Colors.orange.shade600,
                      ]
                          : [
                        Colors.amber.shade300,
                        Colors.orange.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? (isFollowing ? Colors.red : Colors.amber).withOpacity(0.3)
                            : (isFollowing ? Colors.red : Colors.amber).withOpacity(0.2),
                        spreadRadius: 0,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isFollowing ? onRemovePressed : onAddPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isFollowing ? Icons.person_remove : Icons.person_add,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          isFollowing ? 'Remove' : 'Add Friend',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),],
        ),
      ),
    );
  }
}