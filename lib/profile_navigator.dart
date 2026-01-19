import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../profile_screen1.dart';
import '../profile_view.dart';

Future<void> navigateToProfile(BuildContext context, String userId) async {
  User? currentUser = FirebaseAuth.instance.currentUser;

  try {
    // Try to fetch from 'profiles'
    DocumentSnapshot profileDoc = await FirebaseFirestore.instance
        .collection('profiles')
        .doc(userId)
        .get();

    Map<String, dynamic> profileData = profileDoc.data() as Map<String, dynamic>? ?? {};

    String name = profileData['name'] ?? '';
    String interest = profileData['interest'] ?? '';
    String about = profileData['about'] ?? '';
    String title = profileData['title'] ?? '';
    String phone = profileData['phone'] ?? '';
    String email = profileData['email'] ?? '';
    String profileImage = profileData['profileImage'] ?? 'assets/default_profile_image.png';

    // Fallback to 'users' for name/interest
    if (name.isEmpty || interest.isEmpty) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};
      name = name.isEmpty ? (userData['name'] ?? 'Unknown User') : name;

      final userInterest = userData['interest'] as String?;
      if (interest.isEmpty && userInterest != null && userInterest.isNotEmpty) {
        interest = userInterest;
      }
    }

    final profileScreen = (currentUser != null && currentUser.uid == userId)
        ? ProfileView(
      name: name,
      interest: interest,
      about: about,
      title: title,
      phone: phone,
      email: email,
      profileImage: profileImage,
    )
        : ProfileScreen1(
      userId: userId,
      name: name,
      interest: interest,
      about: about,
      title: title,
      phone: phone,
      email: email,
      profileImage: profileImage,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => profileScreen),
    );
  } catch (e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen1(
          userId: userId,
          name: 'Unknown User',
          interest: '',
          about: '',
          title: '',
          phone: '',
          email: '',
          profileImage: 'assets/default_profile_image.png',
        ),
      ),
    );
  }
}
