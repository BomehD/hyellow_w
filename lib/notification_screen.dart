import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/profile_screen1.dart';
import 'package:hyellow_w/single_post_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:rxdart/rxdart.dart'; // Import rxdart for combining streams

import 'notification_settings_screen.dart';
import 'post_widget.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key}); // Added super.key

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? currentUserId;

  // Streams for notifications and mute status
  Stream<List<Map<String, dynamic>>>? _notificationsDataStream;
  Stream<bool>? _muteStatusStream;

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser?.uid;

    if (currentUserId != null) {
      // Stream for fetching the mute status
      _muteStatusStream = _firestore
          .collection('Friends')
          .doc(currentUserId)
          .snapshots()
          .map((snapshot) => (snapshot.data()?['notificationsMuted'] ?? false) as bool)
          .handleError((e) {
         print('Error fetching mute status stream: $e');
        return false; // Default to not muted on error
      });

      // Stream for fetching the actual notifications
      _notificationsDataStream = _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          // Safely get the data map
          final data = doc.data();
          if (data == null) {
            // Handle case where data is null (e.g., deleted document, should be rare)
            return <String, dynamic>{};
          }

          return {
            'id': doc.id,
            'senderId': data['senderId'] as String,
            'type': data['type'] as String,
            'message': data['message'] as String,
            'timestamp': data['timestamp'] as Timestamp,
            'isRead': data['isRead'] as bool,
            'imageUrl': data['imageUrl'] as String?,
            'postId': data['postId'] as String?, // Safely accesses from 'data' map
            // Make sure all fields are accessed from 'data' now
            // Example: 'anotherField': data['anotherField'] as String?,
          };
        }).toList();
      }).handleError((e) {
        print('Error fetching notifications data stream: $e');
        return <Map<String, dynamic>>[];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Notifications',
            style: TextStyle(
              color: Color(0xFF106C70),
              fontSize: 13,
            ),
          ),
        ),
        body: const Center(child: Text('Please log in to view notifications.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF106C70),
            fontSize: 13,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<dynamic>>(
        // Combine the two streams
        stream: Rx.combineLatest2(
          _notificationsDataStream ?? Stream.value(<Map<String, dynamic>>[]),
          _muteStatusStream ?? Stream.value(false),
              (List<Map<String, dynamic>> notifications, bool isMuted) => [notifications, isMuted],
        ),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             print('Combined Stream Error: ${snapshot.error}');
            return Center(child: Text('Error loading notifications: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No data available.'));
          }

          final List<Map<String, dynamic>> notifications = snapshot.data![0] as List<Map<String, dynamic>>;
          final bool isMuted = snapshot.data![1] as bool;

          if (isMuted) {
            return const Center(
              child: Text(
                'Notifications are muted.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No new notifications.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationTile(notification);
            },
          );
        },
      ),
    );
  }

  void _followBack(String senderId, String notificationId) async {
    if (currentUserId == null) {
      print('DEBUG: Current user is null. Aborting follow back.');
      return;
    }
    print('DEBUG: Attempting to follow back user with senderId: $senderId');
    print('DEBUG: Current user ID: $currentUserId');
    print('DEBUG: Notification ID to mark as read: $notificationId');

    try {
      await _firestore.runTransaction((transaction) async {
        print('DEBUG: Transaction started.');

        // Get the document for the current user
        final currentUserDocRef = _firestore.collection('Friends').doc(currentUserId);
        print('DEBUG: Getting current user document at path: ${currentUserDocRef.path}');
        final currentUserSnapshot = await transaction.get(currentUserDocRef);
        print('DEBUG: Current user document exists: ${currentUserSnapshot.exists}');

        // Get the document for the sender
        final senderDocRef = _firestore.collection('Friends').doc(senderId);
        print('DEBUG: Getting sender document at path: ${senderDocRef.path}');
        final senderSnapshot = await transaction.get(senderDocRef);
        print('DEBUG: Sender document exists: ${senderSnapshot.exists}');

        // Create a map to update the current user's following list
        final Map<String, dynamic> currentUserUpdate = {
          'followingMetadata': {
            senderId: {'timestamp': FieldValue.serverTimestamp()}
          }
        };

        // If the document exists, use update; otherwise, use set with merge
        if (currentUserSnapshot.exists) {
          print('DEBUG: Updating current user\'s followingMetadata.');
          transaction.update(currentUserDocRef, currentUserUpdate);
        } else {
          print('DEBUG: Setting current user\'s followingMetadata with merge.');
          transaction.set(currentUserDocRef, currentUserUpdate, SetOptions(merge: true));
        }

        // Create a map to update the sender's followers list
        final Map<String, dynamic> senderUpdate = {
          'followersMetadata': {
            currentUserId: {'timestamp': FieldValue.serverTimestamp()}
          }
        };

        // If the document exists, use update; otherwise, use set with merge
        if (senderSnapshot.exists) {
          print('DEBUG: Updating sender\'s followersMetadata.');
          transaction.update(senderDocRef, senderUpdate);
        } else {
          print('DEBUG: Setting sender\'s followersMetadata with merge.');
          transaction.set(senderDocRef, senderUpdate, SetOptions(merge: true));
        }

        // Mark the notification as read within the same transaction
        final notificationDocRef = _firestore.collection('notifications').doc(notificationId);
        print('DEBUG: Updating notification to mark as read at path: ${notificationDocRef.path}');
        transaction.update(notificationDocRef, {'isRead': true});
        print('DEBUG: All transaction operations staged.');
      });

      print('DEBUG: Transaction successfully committed!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are now following back!')),
        );
      }
    } catch (e) {
      print('DEBUG: Transaction failed with error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to follow back: $e')),
        );
      }
    }
  }

  Widget _buildNotificationTile(Map<String, dynamic> notification) {
    final String senderId = notification['senderId'];
    final String type = notification['type'];
    final String message = notification['message'];
    final Timestamp timestamp = notification['timestamp'];
    final bool isRead = notification['isRead'] ?? false;
    final String? imageUrl = notification['imageUrl'];
    final String? postId = notification['postId'];

    return Opacity(
      opacity: isRead ? 0.6 : 1.0,
      child: ListTile(
        onTap: () async {
          // Mark this specific notification as read first
          try {
            await _firestore.collection('notifications').doc(notification['id']).update({
              'isRead': true,
            });
          } catch (e) {
             print('Error marking notification as read: $e');
          }

          if (type == 'new_follower') {
            final userSnap = await _firestore.collection('users').doc(senderId).get();
            final profileSnap = await _firestore.collection('profiles').doc(senderId).get();

            if (userSnap.exists && profileSnap.exists) {
              final userData = userSnap.data()!;
              final profileData = profileSnap.data()!;

              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen1(
                      name: userData['name'] ?? '',
                      interest: userData['interest'] ?? '',
                      about: profileData['about'] ?? '',
                      title: profileData['title'] ?? '',
                      phone: profileData['phone'] ?? '',
                      email: profileData['email'] ?? '',
                      profileImage: profileData['profileImage'] ?? '',
                      userId: senderId,
                    ),
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not load user profile.')),
                );
              }
            }
          } else if (postId != null && (type == 'like' || type == 'comment' || type == 'new_post')) {
            final postSnap = await _firestore.collection('posts').doc(postId).get();
            // ... (inside the else if (postId != null && ...) block) ...

            if (postSnap.exists) {
              final postData = postSnap.data()!;
              final authorSnap = await _firestore.collection('users').doc(postData['authorId']).get();
              final authorProfileSnap = await _firestore.collection('profiles').doc(postData['authorId']).get();

              final String authorName = authorSnap.data()?['name'] ?? 'Unknown';
              final String authorProfileImageUrl =
                  authorProfileSnap.data()?['profileImage'] ?? 'https://via.placeholder.com/150';

              final String currentLoggedInUserId = _auth.currentUser?.uid ?? '';

              if (mounted) {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SinglePostScreen(
                      postId: postId,
                      postContent: postData['content'] ?? '',
                      authorId: postData['authorId'],
                      authorName: authorName,
                      profileImageUrl: authorProfileImageUrl,
                      timestamp: postData['timestamp'] ?? Timestamp.now(),
                      interest: postData['interest'] ?? 'General',
                      likeCount: postData['likeCount'] ?? 0,
                      commentCount: postData['commentCount'] ?? 0,
                      imageUrl: postData['imageUrl'],
                      videoUrl: postData['videoUrl'],
                      postVisibility: postData['postVisibility'] ?? 'public',
                      areCommentsEnabled: postData['commentsEnabled'] ?? true,
                      authorAbout: authorProfileSnap.data()?['about'] ?? '',
                      authorTitle: authorProfileSnap.data()?['title'] ?? '',
                      authorPhone: authorProfileSnap.data()?['phone'] ?? '',
                      authorEmail: authorProfileSnap.data()?['email'] ?? '',
                    ),
                  ),
                );
              }
            }
            else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post not found or has been deleted.')),
                );
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification type not handled or content missing.')),
              );
            }
          }
        },
        leading: CircleAvatar(
          backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
          child: (imageUrl == null || imageUrl.isEmpty) ? const Icon(Icons.person) : null,
        ),
        title: Text(message),
        subtitle: Text(
          timeago.format(timestamp.toDate()),
          style: const TextStyle(fontSize: 12.0, color: Colors.grey),
        ),
        trailing: type == 'new_follower' && !isRead
            ? ElevatedButton(
          onPressed: () => _followBack(senderId, notification['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF106C70),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            elevation: 3,
          ),
          child: const Text(
            'Follow Back',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.0,
            ),
          ),
        )
            : null,
      ),
    );
  }
}