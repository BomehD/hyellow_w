import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_card.dart';

class UserListScreen extends StatefulWidget {
  final String selectedInterest;
  final String? highlightUserId;

  const UserListScreen({
    super.key,
    required this.selectedInterest,
    this.highlightUserId,
  });

  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? currentUserId;
  Set<String> followingList = {};
  List<String> selectedCountries = [];

  @override
  void initState() {
    super.initState();
    _fetchPreferencesAndUserData();
  }

  Future<void> _fetchPreferencesAndUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedCountries = prefs.getStringList('user_country_filter');
      if (storedCountries != null) {
        selectedCountries = storedCountries;
      }

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        currentUserId = currentUser.uid;

        final currentUserDoc = FirebaseFirestore.instance
            .collection('Friends')
            .doc(currentUserId);
        final currentUserData = await currentUserDoc.get();
        final data = currentUserData.data() as Map<String, dynamic>?;

        if (data != null && data.containsKey('followingMetadata')) {
          final Map<String, dynamic> metadata =
          data['followingMetadata'] as Map<String, dynamic>;
          followingList = metadata.keys.toSet();
        }

        setState(() {});
      }
    } catch (e) {
      debugPrint("Error fetching preferences: $e");
    }
  }

  bool isCountryMatch(String? userCountry) {
    if (selectedCountries.isEmpty || selectedCountries.length > 10) return true;
    return userCountry != null && selectedCountries.contains(userCountry);
  }

  Widget _buildUserPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        height: 100,
        child: Row(
          children: [
            const SizedBox(width: 10),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.onSurface.withOpacity(0.1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 15,
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 60, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No matches yet!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your country filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'People in ${widget.selectedInterest}',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 13,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: theme.iconTheme.color ?? theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: currentUserId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('interest', isEqualTo: widget.selectedInterest)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: TextStyle(color: theme.colorScheme.error)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final allUsers = snapshot.data?.docs ?? [];
          List<QueryDocumentSnapshot> highlightedUser = [];
          List<QueryDocumentSnapshot> otherUsers = [];

          for (var doc in allUsers) {
            final userData = doc.data() as Map<String, dynamic>;
            final countryField = userData['country'];
            final userCountry = (countryField is String)
                ? countryField
                : (countryField is List && countryField.isNotEmpty)
                ? countryField.first.toString()
                : null;

            if (!isCountryMatch(userCountry)) continue;

            if (doc.id == widget.highlightUserId) {
              highlightedUser.add(doc);
            } else {
              otherUsers.add(doc);
            }
          }

          final usersToShow = [...highlightedUser, ...otherUsers];
          if (usersToShow.isEmpty) {
            return _buildEmptyState(context);
          }

          return Center(
            child: Container(
              width: MediaQuery.of(context).size.width > 600
                  ? 500
                  : double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                itemCount: usersToShow.length,
                itemBuilder: (context, index) {
                  final userDoc = usersToShow[index];
                  final user = userDoc.data() as Map<String, dynamic>;
                  final userId = userDoc.id;
                  final isFollowing = followingList.contains(userId);

                  Future<bool> isBlockedByRecipient(
                      String recipientId, String currentUserId) async {
                    try {
                      final blockDoc = await FirebaseFirestore.instance
                          .collection('Blocks')
                          .doc(recipientId)
                          .get();
                      List<dynamic> blockedUsers =
                          blockDoc.data()?['blocked'] ?? [];
                      return blockedUsers.contains(currentUserId);
                    } catch (e) {
                      debugPrint(
                          'Error checking blocked status: $e');
                      return false;
                    }
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('profiles')
                        .doc(userId)
                        .get(),
                    builder: (context, profileSnapshot) {
                      if (profileSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return _buildUserPlaceholder(context);
                      }
                      if (profileSnapshot.hasError) {
                        return ListTile(
                            title: Text(
                                'Error: ${profileSnapshot.error}',
                                style: TextStyle(
                                    color: theme.colorScheme.error)));
                      }

                      final profileData =
                          profileSnapshot.data?.data()
                          as Map<String, dynamic>? ??
                              {};
                      final profileImageUrl =
                          profileData['profileImage'] ?? '';

                      return CustomCard(
                        name: user['name'] ?? 'Unnamed',
                        profileImage: profileImageUrl,
                        currentUserId: currentUserId!,
                        userId: userId,
                        initialIsFollowing: isFollowing,
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
