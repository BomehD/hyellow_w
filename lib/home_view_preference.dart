// home_view_preference_firestore.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode

class HomeViewPreferenceFirestore {

  static Future<void> setSelectedView(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'selectedView': index});
    } on FirebaseException catch (e) {

      if (kDebugMode) {
        print('Error updating selected view: ${e.message}');
      }
    } catch (e) {
      // Catch any other unexpected errors.
      if (kDebugMode) {
        print('An unexpected error occurred: $e');
      }
    }
  }

  static Future<int> getSelectedView() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 1;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data()?['selectedView'] as int? ?? 1;
      } else {
        return 1;
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        print('Failed to get selected view, using default: ${e.message}');
      }
      return 1;
    } catch (e) {
      // Catch any other exceptions.
      if (kDebugMode) {
        print('An unexpected error occurred while fetching preferences: $e');
      }
      return 1;
    }
  }
}
