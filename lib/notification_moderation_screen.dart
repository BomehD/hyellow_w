import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'notification_moderation_screen.dart'; // Self-reference, often means it's for internal use

class NotificationModerationScreen extends StatefulWidget {
  const NotificationModerationScreen({super.key}); // Added super.key

  @override
  _NotificationModerationScreenState createState() => _NotificationModerationScreenState();
}

class _NotificationModerationScreenState extends State<NotificationModerationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? currentUserId;

  String? _selectedReportReason;
  final TextEditingController _customReasonController = TextEditingController(); // Made final

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser?.uid;
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  // Fetches recent new follower notifications for the current user.
  Stream<List<Map<String, dynamic>>> getRecentFollowerNotifications() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: currentUserId)
        .where('type', isEqualTo: 'new_follower')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => {
        'notificationId': doc.id,
        'senderId': doc['senderId'] as String,
        'message': doc['message'] as String,
        'timestamp': doc['timestamp'] as Timestamp,
        'isRead': doc['isRead'] as bool,
        // Include other fields from the notification document as needed
      }).toList();
    });
  }

  // Checks if a user is blocked by the current user.
  Future<bool> isBlocked(String userId) async {
    final blockDoc = await _firestore.collection('Blocks').doc(currentUserId).get();
    List<dynamic> blockedUsers = blockDoc.data()?['blocked'] ?? [];
    return blockedUsers.contains(userId);
  }

  // Blocks a user, updating friend relationships and deleting relevant notifications.
  Future<void> blockUser(String userId) async {
    final bool? confirm = await _showConfirmationDialog(
        'Block this user? They will no longer be able to follow you or see your content.');
    if (confirm != true) return;

    if (currentUserId == null) return; // Ensure currentUserId is not null after dialog

    try {
      await _firestore.collection('Blocks').doc(currentUserId).set({
        'blocked': FieldValue.arrayUnion([userId])
      }, SetOptions(merge: true));

      // Remove from current user's followers by deleting from followersMetadata map
      await _firestore.collection('Friends').doc(currentUserId).update({
        'followersMetadata.$userId': FieldValue.delete()
      });

      // Remove current user from target user's following list by deleting from followingMetadata map
      await _firestore.collection('Friends').doc(userId).update({
        'followingMetadata.$currentUserId': FieldValue.delete()
      });

      // Delete related new_follower notifications from this user
      final notificationQuery = await _firestore.collection('notifications')
          .where('recipientId', isEqualTo: currentUserId)
          .where('senderId', isEqualTo: userId)
          .where('type', isEqualTo: 'new_follower')
          .get();

      final WriteBatch batch = _firestore.batch();
      for (final doc in notificationQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        setState(() {}); // Rebuild to update block status
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to block user: $e')));
      }
    }
  }
  // Unblocks a user.
  Future<void> unblockUser(String userId) async {
    if (currentUserId == null) return;

    try {
      await _firestore.collection('Blocks').doc(currentUserId).update({
        'blocked': FieldValue.arrayRemove([userId])
      });

      if (mounted) {
        setState(() {}); // Rebuild to update block status
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unblock user: $e')));
      }
    }
  }



  // Reports a user to the moderation team.
  Future<void> reportUser(String userId) async {
    final String? reason = await _showEnhancedReportDialog();
    if (reason == null || reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report cancelled or no reason provided.')),
        );
      }
      return;
    }

    if (currentUserId == null) return; // Ensure currentUserId is not null

    try {
      await _firestore.collection('NotificationReports').add({
        'reporter': currentUserId,
        'reported': userId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User reported successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to report user: $e')));
      }
    }
  }

  // Shows a generic confirmation dialog.
  Future<bool?> _showConfirmationDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: const Text('Confirm Action', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  // Displays an enhanced modal bottom sheet for reporting a user.
  Future<String?> _showEnhancedReportDialog() async {
    _selectedReportReason = null;
    _customReasonController.clear();
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Report User',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please select a reason for reporting this user:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      _buildReportReasonOption(
                        setModalState,
                        'Inappropriate Content',
                        'inappropriate_content',
                      ),
                      _buildReportReasonOption(
                        setModalState,
                        'Spam or Scam',
                        'spam_scam',
                      ),
                      _buildReportReasonOption(
                        setModalState,
                        'Harassment or Hate Speech',
                        'harassment_hate_speech',
                      ),
                      _buildReportReasonOption(
                        setModalState,
                        'Impersonation',
                        'impersonation',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Other (Optional):',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customReasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Provide more details...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                      fillColor: Colors.grey[50],
                      filled: true,
                    ),
                    onChanged: (text) { // Clear selected reason if custom text is entered
                      if (text.isNotEmpty && _selectedReportReason != null) {
                        setModalState(() {
                          _selectedReportReason = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop(); // Pop with null
                        },
                        child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          String finalReason = _selectedReportReason ?? _customReasonController.text.trim();
                          if (finalReason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a reason or provide details.')),
                            );
                          } else {
                            Navigator.of(ctx).pop(finalReason);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text(
                          'Submit Report',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper for building report reason radio options.
  Widget _buildReportReasonOption(StateSetter setModalState, String title, String value) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: _selectedReportReason,
      onChanged: (String? newValue) {
        setModalState(() {
          _selectedReportReason = newValue;
          if (newValue != null) {
            _customReasonController.clear(); // Clear custom text if an option is selected
          }
        });
      },
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  // Shows moderation options (report/block/unblock) for a user.
  void showModerationOptions(String userId, bool isBlocked) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report'),
            onTap: () {
              Navigator.of(ctx).pop();
              reportUser(userId);
            },
          ),
          ListTile(
            leading: Icon(isBlocked ? Icons.lock_open : Icons.block),
            title: Text(isBlocked ? 'Unblock' : 'Block'),
            onTap: () {
              Navigator.of(ctx).pop();
              isBlocked ? unblockUser(userId) : blockUser(userId);
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Builds a tile for a user notification with moderation options.
  Widget _buildUserTile(Map<String, dynamic> notificationData) { // Renamed to _buildUserTile
    final String senderId = notificationData['senderId'] as String;
    final String message = notificationData['message'] as String;

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(senderId).get(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();

        final Map<String, dynamic>? userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final String name = userData?['name'] ?? 'Unknown';

        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('profiles').doc(senderId).get(),
          builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> profileSnapshot) {
            final Map<String, dynamic>? profileData = profileSnapshot.data?.data() as Map<String, dynamic>?;
            final String? profileImage = profileData?['profileImage'];

            return FutureBuilder<bool>(
              future: isBlocked(senderId),
              builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                final bool isBlockedUser = snapshot.data ?? false;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: profileImage != null && profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                    child: profileImage == null || profileImage.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(name),
                  subtitle: Text(isBlockedUser ? 'Blocked' : message),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => showModerationOptions(senderId, isBlockedUser),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Moderation',  style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: currentUserId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
        stream: getRecentFollowerNotifications(),
        builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading notifications: ${snapshot.error}'));
          }

          final List<Map<String, dynamic>> recentNotifications = snapshot.data ?? [];

          if (recentNotifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No new follower notifications to moderate.',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This screen shows recent follow requests for you to manage. If someone follows you, you\'ll see them here.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: recentNotifications.length,
            itemBuilder: (BuildContext context, int index) => _buildUserTile(recentNotifications[index]),
          );
        },
      ),
    );
  }
}