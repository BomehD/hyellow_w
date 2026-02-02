import 'package:cloud_firestore/cloud_firestore.dart';

Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
  final firestore = FirebaseFirestore.instance;
  final lowercaseQuery = query.toLowerCase();

  // Step 1: Fetch users
  final usersSnapshot = await firestore
      .collection('users')
      .orderBy('name_lower')
      .limit(100)
      .get();

  List<Map<String, dynamic>> results = [];

  for (var userDoc in usersSnapshot.docs) {
    final userId = userDoc.id;
    final userData = userDoc.data();
    final name = userData['name']?.toLowerCase() ?? '';

    // Step 2: Local Filter
    if (name.contains(lowercaseQuery)) {
      // Step 3: Pull data directly from userData (users collection)
      results.add({
        'id': userId,
        'name': userData['name'] ?? '',
        // Updated: Accessing 'interest' from the current user document
        'interest': userData['interest'] ?? 'No interest listed',
        'profileImage': userData['profileImage'] ?? '',
      });
    }
  }

  return results;
}