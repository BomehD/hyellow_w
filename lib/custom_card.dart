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
    return Container(
      margin: EdgeInsets.symmetric(vertical: 20, horizontal: 30),
      constraints: BoxConstraints(
        maxWidth: 400,
        maxHeight: 300,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 10,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Row for Name and Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Conditionally show "Add" or "Remove" Button
                if (userId != currentUserId) // Only show if not the current user
                  ElevatedButton(
                    onPressed: isFollowing ? onRemovePressed : onAddPressed,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black54,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isFollowing ? 'Remove' : 'Add',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20),
            // Profile Picture (centered)
            Center(
              child: Container(
                width: 300,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                ),
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
                    borderRadius: BorderRadius.circular(10),
                    // The Hero widget must wrap the image itself
                    child: profileImage != null && profileImage!.isNotEmpty
                        ? Hero(
                      tag: profileImage!, // The Hero tag must be a unique String
                      child: Image.network(
                        profileImage!,
                        width: 300,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Hero(
                      tag: 'default_profile_tag', // Use a consistent tag for the default image
                      child: Image.asset(
                        'assets/default_profile_image.png',
                        width: 300,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}