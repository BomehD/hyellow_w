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

        if (mounted) {
          setState(() {});
        }
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

  Widget _buildOfflineStateWithPlaceholders(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // Placeholders in the background
        ListView.builder(
          itemCount: 5,
          itemBuilder: (context, index) => _buildUserPlaceholder(context),
        ),
        // Offline banner on top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wifi_off,
                  color: theme.colorScheme.onErrorContainer,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Internet Connection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Check your connection and try again',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onErrorContainer.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  onPressed: () {
                    setState(() {
                      // This will trigger a rebuild and retry
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
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
            return ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => _buildUserPlaceholder(context),
            );
          }
          if (snapshot.hasError) {
            // Check if error is due to network issues
            final errorString = snapshot.error.toString().toLowerCase();
            if (errorString.contains('unavailable') ||
                errorString.contains('unable to resolve') ||
                errorString.contains('failed to connect') ||
                errorString.contains('network is unreachable') ||
                errorString.contains('no address associated')) {
              return _buildOfflineStateWithPlaceholders(context);
            }
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
                        // Silently skip profiles that fail to load
                        debugPrint('Error loading profile for $userId: ${profileSnapshot.error}');
                        return const SizedBox.shrink();
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