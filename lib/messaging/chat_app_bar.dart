// lib/messaging/widgets/_chat_app_bar.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hyellow_w/profile_screen1.dart';
import 'package:hyellow_w/messaging/chat_services.dart';
import 'package:hyellow_w/utils/download_profile_image.dart';
import 'full_screen_image_viewer.dart';

class ChatDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Map<String, dynamic> friend;
  final bool multiSelectionMode;
  final int selectedMessageCount;
  final VoidCallback onCloseMultiSelection;
  final VoidCallback onCopySelected;
  final VoidCallback onDeleteSelected;
  final bool isMuted;
  final bool isPinned;
  final VoidCallback onToggleMute;
  final VoidCallback onTogglePin;
  final VoidCallback onClearChat;
  final VoidCallback onDeleteChat;
  final ChatService chatService;
  final bool isBlocked;

  const ChatDetailAppBar({
    super.key,
    required this.friend,
    required this.multiSelectionMode,
    required this.selectedMessageCount,
    required this.onCloseMultiSelection,
    required this.onCopySelected,
    required this.onDeleteSelected,
    required this.isMuted,
    required this.isPinned,
    required this.onToggleMute,
    required this.onTogglePin,
    required this.onClearChat,
    required this.onDeleteChat,
    required this.chatService,
    required this.isBlocked,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  String _getInterest(Map<String, dynamic> profileData) {
    final dynamic interests = profileData['interest'];
    if (interests is List && interests.isNotEmpty) {
      return interests[0].toString();
    } else if (interests is String && interests.isNotEmpty) {
      return interests;
    }
    return 'General';
  }

  Future<void> _navigateToProfile(BuildContext context) async {
    final String? userId = friend['userId'];
    final String? friendName = friend['name'];

    if (userId == null || friendName == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend data is incomplete.')),
        );
      }
      return;
    }

    try {
      final profileSnapshot = await FirebaseFirestore.instance.collection('profiles').doc(userId).get();
      Map<String, dynamic> profileData = profileSnapshot.data() ?? {};

      if (profileData.isEmpty) {
        final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        profileData = userSnapshot.data() ?? {};
      }

      if (profileData.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User profile not found.')),
          );
        }
        return;
      }

      final String name = profileData['name'] ?? friendName;
      final String interest = _getInterest(profileData);
      final String about = profileData['about'] ?? 'No bio available';
      final String title = profileData['title'] ?? 'No title available';
      final String phone = profileData['phone'] ?? 'No phone number provided';
      final String email = profileData['email'] ?? 'No email provided';
      final String profileImage = profileData['profileImage'] ?? 'assets/default_profile_image.png';

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen1(
              userId: userId,
              name: name,
              interest: interest,
              about: about,
              title: title,
              phone: phone,
              email: email,
              profileImage: profileImage,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String? friendProfileImageUrl = friend['profileImage'];
    final ImageProvider friendAvatarImage = (friendProfileImageUrl != null &&
        friendProfileImageUrl.isNotEmpty &&
        !friendProfileImageUrl.startsWith('assets/'))
        ? NetworkImage(friendProfileImageUrl)
        : const AssetImage('assets/default_profile_image.png');

    return AppBar(
      leadingWidth: 40.0,
      titleSpacing: 0.0,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      leading: IconButton(
        icon: Icon(
          multiSelectionMode ? Icons.close : Icons.arrow_back,
          color: colorScheme.onSurface,
        ),
        onPressed: multiSelectionMode
            ? onCloseMultiSelection
            : () => Navigator.pop(context),
      ),
      title: multiSelectionMode
          ? Text(
        '$selectedMessageCount selected',
        style: TextStyle(color: colorScheme.onSurface),
      )
          : GestureDetector(
        onTap: () => _navigateToProfile(context),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (friendProfileImageUrl != null &&
                    friendProfileImageUrl.isNotEmpty &&
                    !friendProfileImageUrl.startsWith('assets/')) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(
                        imageUrl: friendProfileImageUrl,
                        heroTag: friend['userId'] ?? 'default_hero_tag',
                      ),
                    ),
                  );
                }
              },
              onLongPress: () async {
                if (friendProfileImageUrl != null &&
                    friendProfileImageUrl.isNotEmpty &&
                    !friendProfileImageUrl.startsWith('assets/')) {
                  await DownloadProfileImage.downloadAndSaveImage(context, friendProfileImageUrl);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot download a default asset image.')),
                    );
                  }
                }
              },
              child: Hero(
                tag: friend['userId'] ?? 'default_hero_tag',
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: friendAvatarImage,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend['name'] ?? 'Friend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(friend['userId']).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
                      return Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final lastSeen = data['last_seen'] as Timestamp?;
                    final statusText = chatService.formatLastSeen(lastSeen);

                    return Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusText == 'Online'
                            ? colorScheme.secondary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: statusText == 'Online' ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: multiSelectionMode
          ? [
        IconButton(
          icon: Icon(Icons.copy, color: colorScheme.onSurface),
          tooltip: 'Copy',
          onPressed: onCopySelected,
        ),
        IconButton(
          icon: Icon(Icons.delete, color: colorScheme.onSurface),
          tooltip: 'Delete',
          onPressed: onDeleteSelected,
        ),
      ]
          : [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
          onSelected: (String value) async {
            switch (value) {
              case 'toggleMute':
                onToggleMute();
                break;
              case 'togglePin':
                onTogglePin();
                break;
              case 'clear':
                onClearChat();
                break;
              case 'delete':
                final bool confirm = await _showDeleteChatDialog(context);
                if (context.mounted && confirm) {
                  onDeleteChat();
                  Navigator.of(context).pop(true);
                }
                break;
              case 'block':
                final bool confirm = await _showBlockUserDialog(context, friend['name'] ?? 'this user');
                if (context.mounted && confirm) {
                  await chatService.blockUser(friend['userId']);
                  if (context.mounted) Navigator.of(context).pop(true);
                }
                break;
              case 'unblock':
                final bool confirm = await _showUnblockUserDialog(context, friend['name'] ?? 'this user');
                if (context.mounted && confirm) {
                  await chatService.unblockUser(friend['userId']);
                  if (context.mounted) Navigator.of(context).pop(true);
                }
                break;
            }
          },
          itemBuilder: (BuildContext context) {
            return [
              PopupMenuItem<String>(
                value: 'toggleMute',
                child: Text(isMuted ? 'Unmute Chat' : 'Mute Chat'),
              ),
              PopupMenuItem<String>(
                value: 'togglePin',
                child: Text(isPinned ? 'Unpin Chat' : 'Pin Chat'),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Text('Clear Chat'),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete Chat'),
              ),
              PopupMenuItem<String>(
                value: isBlocked ? 'unblock' : 'block',
                child: Text(isBlocked ? 'Unblock User' : 'Block User'),
              ),
            ];
          },
        ),
      ],
    );
  }

  Future<bool> _showDeleteChatDialog(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: const Text("Are you sure you want to delete this chat? This cannot be undone."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("CANCEL"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("DELETE"),
            ),
          ],
        );
      },
    );
    return confirm ?? false;
  }

  Future<bool> _showBlockUserDialog(BuildContext context, String friendName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Block"),
          content: Text("Are you sure you want to block $friendName? You will no longer receive messages from this user."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("CANCEL"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("BLOCK"),
            ),
          ],
        );
      },
    );
    return confirm ?? false;
  }

  Future<bool> _showUnblockUserDialog(BuildContext context, String friendName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Unblock"),
          content: Text("Are you sure you want to unblock $friendName? You will be able to receive messages from this user again."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("CANCEL"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("UNBLOCK"),
            ),
          ],
        );
      },
    );
    return confirm ?? false;
  }
}
