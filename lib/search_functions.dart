import 'package:cloud_firestore/cloud_firestore.dart';

Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
  final firestore = FirebaseFirestore.instance;

  final lowercaseQuery = query.toLowerCase();

  // Step 1: Fetch users (limit added for performance)
  final usersSnapshot = await firestore
      .collection('users')
      .orderBy('name_lower')
      .limit(100) // You can increase this if needed
      .get();

  List<Map<String, dynamic>> results = [];

  for (var userDoc in usersSnapshot.docs) {
    final userId = userDoc.id;
    final userData = userDoc.data();
    final name = userData['name']?.toLowerCase() ?? '';

    // Step 2: Check if query is in any part of the name
    if (name.contains(lowercaseQuery)) {
      // Step 3: Attempt to get matching profile
      final profileDoc = await firestore.collection('profiles').doc(userId).get();
      final profileData = profileDoc.data();

      results.add({
        'id': userId,
        'name': userData['name'] ?? '',
        'interest': profileData?['interest'] ?? '',
        'profileImage': profileData?['profileImage'] ?? '',
      });
    }
  }

  return results;
}
