import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserJoinTrackerScreen extends StatefulWidget {
  const UserJoinTrackerScreen({Key? key}) : super(key: key);

  @override
  State<UserJoinTrackerScreen> createState() => _UserJoinTrackerScreenState();
}

class _UserJoinTrackerScreenState extends State<UserJoinTrackerScreen> {
  bool _showUserCount = false;

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🛰️ New Users (Live)')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👇 Toggle user count
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextButton.icon(
              onPressed: () {
                setState(() => _showUserCount = !_showUserCount);
              },
              icon: const Icon(Icons.people_outline),
              label: Text(_showUserCount ? 'Hide Total Users' : 'Show Total Users'),
            ),
          ),

          if (_showUserCount)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Text('Loading user count...');
                  final totalUsers = snapshot.data!.docs.length;
                  return Text(
                    '👥 Total Users: $totalUsers',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),

          const Divider(),

          // 📋 Recent users list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('joinedAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error loading users'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'No Name';
                    final handle = data['handle'] ?? 'N/A';
                    final interests = (data['interest'] as String?) ?? 'No Interests';
                    final joinedAt = data['joinedAt'] as Timestamp?;
                    final profileImage = data['profileImage'];

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: profileImage != null && profileImage.isNotEmpty
                            ? NetworkImage(profileImage)
                            : const AssetImage('assets/default_profile_image.png') as ImageProvider,
                      ),
                      title: Text('$name (@$handle)'),
                      subtitle: Text('Joined: ${_formatTimestamp(joinedAt)}\nInterest: $interests'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
