import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'notification_moderation_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title:  Text('Notification Settings',  style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.mark_email_read_outlined),
            title: const Text('Mark All as Read'),
            onTap: () async {
              if (currentUserId == null) return;

              try {
                final unreadNotifications = await _firestore
                    .collection('notifications')
                    .where('recipientId', isEqualTo: currentUserId)
                    .where('isRead', isEqualTo: false)
                    .get();

                if (unreadNotifications.docs.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications to mark as read')),
                  );
                  return;
                }

                WriteBatch batch = _firestore.batch();
                for (var doc in unreadNotifications.docs) {
                  batch.update(doc.reference, {'isRead': true});
                }
                await batch.commit();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marked all as read')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error marking as read: $e')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear All Notifications'),
            onTap: () async {
              if (currentUserId == null) return;

              try {
                final userNotifications = await _firestore
                    .collection('notifications')
                    .where('recipientId', isEqualTo: currentUserId)
                    .get();

                if (userNotifications.docs.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No notifications to clear')),
                  );
                  return;
                }

                WriteBatch batch = _firestore.batch();
                for (var doc in userNotifications.docs) {
                  batch.delete(doc.reference);
                }
                await batch.commit();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cleared all notifications')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error clearing notifications: $e')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: const Text('Mute Notifications'),
            onTap: () async {
              if (currentUserId == null) return;

              try {
                final docRef = _firestore.collection('Friends').doc(currentUserId);
                final snapshot = await docRef.get();

                bool isMuted = snapshot.data()?['notificationsMuted'] ?? false;

                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(isMuted ? 'Unmute Notifications?' : 'Mute Notifications?'),
                      content: Text(
                        isMuted
                            ? 'Notifications are currently muted. Do you want to turn them back on?'
                            : 'Would you like to mute all notifications?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (!mounted) return; // Check mounted before async call
                            Navigator.of(context).pop();

                            await docRef.set(
                              {'notificationsMuted': !isMuted},
                              SetOptions(merge: true),
                            );

                            if (!mounted) return; // Check mounted after async call
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    !isMuted ? 'Notifications muted' : 'Notifications unmuted'),
                              ),
                            );
                          },
                          child: Text(isMuted ? 'Unmute' : 'Mute'),
                        ),
                      ],
                    );
                  },
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating mute status: $e')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Report or Block Recent Followers'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationModerationScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}