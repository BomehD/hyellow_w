import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hyellow_w/profile_view.dart';
import 'package:hyellow_w/search_functions.dart';
import 'package:hyellow_w/profile_screen1.dart';

class LiveSearchScreen extends StatefulWidget {
  @override
  _LiveSearchScreenState createState() => _LiveSearchScreenState();
}

class _LiveSearchScreenState extends State<LiveSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    final users = await searchUsersByName(query);
    setState(() {
      _results = users;
      _isSearching = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget buildUserTile(Map<String, dynamic> user) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: (user['profileImage'] != null &&
            user['profileImage'].isNotEmpty)
            ? NetworkImage(user['profileImage'])
            : const AssetImage('assets/default_profile_image.png')
        as ImageProvider,
      ),
      title: Text(
        user['name'] ?? '',
        style: TextStyle(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        user['interest'] != '' ? user['interest'] : 'No interest set',
        style: TextStyle(
          fontStyle:
          user['interest'] != '' ? FontStyle.normal : FontStyle.italic,
          color: user['interest'] != ''
              ? colorScheme.onSurfaceVariant
              : colorScheme.outline,
        ),
      ),
      onTap: () async {
        final profileData = await getUserProfile(user['id']);

        if (profileData != null) {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          if (user['id'] == currentUserId) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileView(
                  name: profileData['name'],
                  interest: profileData['interest'],
                  about: profileData['about'],
                  title: profileData['title'],
                  phone: profileData['phone'],
                  email: profileData['email'],
                  profileImage: profileData['profileImage'],
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen1(
                  name: profileData['name'],
                  interest: profileData['interest'],
                  about: profileData['about'],
                  title: profileData['title'],
                  phone: profileData['phone'],
                  email: profileData['email'],
                  profileImage: profileData['profileImage'],
                  userId: user['id'],
                ),
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search by name...',
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            border: InputBorder.none,
          ),
          style: TextStyle(color: colorScheme.onSurface),
          onChanged: _onSearchChanged,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: _isSearching
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(colorScheme.primary),
        ),
      )
          : _results.isEmpty
          ? Center(
        child: Text(
          'No results',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      )
          : ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) =>
            buildUserTile(_results[index]),
      ),
    );
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final firestore = FirebaseFirestore.instance;

    final userDoc = await firestore.collection('users').doc(userId).get();
    final profileDoc = await firestore.collection('profiles').doc(userId).get();

    if (!userDoc.exists && !profileDoc.exists) return null;

    final userData = userDoc.data() ?? {};
    final profileData = profileDoc.data() ?? {};

    return {
      'name': userData['name'] ?? '',
      'interest': profileData['interest'] ?? '',
      'about': profileData['about'] ?? '',
      'title': profileData['title'] ?? '',
      'phone': profileData['phone'] ?? '',
      'email': profileData['email'] ?? '',
      'profileImage': profileData['profileImage'] ?? '',
    };
  }
}
