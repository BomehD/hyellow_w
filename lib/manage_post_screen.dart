import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/edit_post_screen.dart';
import 'dart:async';

class ManagePostScreen extends StatefulWidget {
  final String postId;
  final String authorId;
  final String postContent;
  final String? imageUrl;
  final String? videoUrl;
  final String currentVisibility;
  final bool commentsEnabled;
  final VoidCallback? onPostUpdated; // Add callback for real-time integration

  const ManagePostScreen({
    super.key,
    required this.postId,
    required this.authorId,
    required this.postContent,
    this.imageUrl,
    this.videoUrl,
    required this.currentVisibility,
    required this.commentsEnabled,
    this.onPostUpdated,
  });

  @override
  State<ManagePostScreen> createState() => _ManagePostScreenState();
}

class _ManagePostScreenState extends State<ManagePostScreen> {
  late bool _commentsEnabled;
  late String _visibility;
  late bool _notificationsEnabled;
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Stream subscription for real-time updates
  StreamSubscription<DocumentSnapshot>? _postSubscription;

  @override
  void initState() {
    super.initState();
    _commentsEnabled = widget.commentsEnabled;
    _visibility = widget.currentVisibility;
    _notificationsEnabled = false;
    _fetchNotificationSetting();
    _setupPostListener();
  }

  @override
  void dispose() {
    _postSubscription?.cancel();
    super.dispose();
  }

  // Listen to real-time changes to the post document
  void _setupPostListener() {
    _postSubscription = _firestore
        .collection('posts')
        .doc(widget.postId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || !snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;

      final newCommentsEnabled = data['commentsEnabled'] as bool? ?? true;
      final newVisibility = data['visibility'] as String? ?? 'public';

      // Only update if values actually changed to avoid unnecessary rebuilds
      if (_commentsEnabled != newCommentsEnabled || _visibility != newVisibility) {
        setState(() {
          _commentsEnabled = newCommentsEnabled;
          _visibility = newVisibility;
        });
      }
    });
  }

  Future<void> _fetchNotificationSetting() async {
    if (_currentUser == null) return;

    try {
      final notificationDoc = await _firestore
          .collection('notifications_settings')
          .doc(_currentUser!.uid)
          .collection('post_notifications')
          .doc(widget.postId)
          .get();

      if (mounted) {
        setState(() {
          _notificationsEnabled = notificationDoc.exists &&
              (notificationDoc.data()?['enabled'] ?? false);
        });
      }
    } catch (e) {
      print('Error fetching notification setting: $e');
    }
  }

  Future<void> _toggleComments(bool newValue) async {
    if (!mounted || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('posts').doc(widget.postId).update({
        'commentsEnabled': newValue,
        'lastModified': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comments ${newValue ? 'enabled' : 'disabled'}'),
            backgroundColor: Colors.grey,
          ),
        );
        // Trigger callback to notify parent screens
        widget.onPostUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update comments status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateVisibility(String newVisibility) async {
    if (!mounted || _isLoading) return;

    // Show confirmation dialog for sensitive visibility changes
    if (newVisibility == 'private' || _visibility == 'private') {
      final confirm = await _showVisibilityConfirmation(newVisibility);
      if (!confirm) return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('posts').doc(widget.postId).update({
        'visibility': newVisibility,
        'lastModified': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post visibility changed to "$newVisibility"'),
            backgroundColor: Colors.green,
          ),
        );
        // Trigger callback to notify parent screens
        widget.onPostUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update visibility: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showVisibilityConfirmation(String newVisibility) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Confirm Visibility Change'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change post visibility to "$newVisibility"?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getVisibilityDescription(newVisibility),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  String _getVisibilityDescription(String visibility) {
    switch (visibility) {
      case 'public':
        return 'Anyone can see this post';
      case 'followers':
        return 'Only your followers can see this post';
      case 'private':
        return 'Only you can see this post';
      default:
        return 'Visibility setting';
    }
  }

  Future<void> _toggleNotifications(bool newValue) async {
    if (_currentUser == null || !mounted || _isLoading) return;

    setState(() => _isLoading = true);

    final notificationRef = _firestore
        .collection('notifications_settings')
        .doc(_currentUser!.uid)
        .collection('post_notifications')
        .doc(widget.postId);

    try {
      if (newValue) {
        await notificationRef.set({
          'enabled': true,
          'timestamp': FieldValue.serverTimestamp(),
          'postId': widget.postId,
          'postContent': widget.postContent.length > 50
              ? '${widget.postContent.substring(0, 50)}...'
              : widget.postContent,
        });
      } else {
        await notificationRef.delete();
      }

      if (mounted) {
        setState(() => _notificationsEnabled = newValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Notifications ${newValue ? 'enabled' : 'disabled'} for this post'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notification setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToEditPost() async {
    if (widget.postId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Post ID is missing.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();

      if (postSnapshot.exists) {
        final postData = postSnapshot.data() as Map<String, dynamic>;

        final List<String> initialImageUrls = (postData['imageUrls'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
            [];

        // FIX 1: Change to a nullable String
        final String? initialVideoUrl = postData['videoUrl'];

        // FIX 2: Use null-coalescing to provide a default empty string
        final String initialContent = postData['content'] ?? '';

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditPostScreen(
              postId: widget.postId,
              initialContent: initialContent, // Pass the non-null string
              initialVideoUrl: initialVideoUrl, // Pass the nullable string
              initialImageUrls: initialImageUrls,
            ),
          ),
        );

        if (result == true) {
          widget.onPostUpdated?.call();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post updated successfully'),
                backgroundColor: Colors.grey,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post not found.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching post data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // New helper method for responsive layout
  double _getContentWidth(double screenWidth) {
    if (screenWidth >= 1200) {
      return 600; // Fixed width for large desktops
    } else if (screenWidth >= 800) {
      return screenWidth * 0.65; // 65% for tablets
    } else {
      return screenWidth; // Full width for mobile
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Post',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 1,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),


      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post preview section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Post Preview:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.postContent,
                          style: const TextStyle(fontSize: 16),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.imageUrl != null || widget.videoUrl != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                widget.videoUrl != null ? Icons.video_library : Icons.image,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.videoUrl != null ? 'Video attached' : 'Image attached',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Post Management:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Edit Post Option
                  Card(
                    elevation: 1,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      title: const Text('Edit Post Content'),
                      subtitle: const Text('Modify text, images, or videos'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _isLoading ? null : _navigateToEditPost,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Settings Section
                  const Text(
                    'Post Settings:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Notifications Toggle
                  Card(
                    elevation: 1,
                    child: SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _notificationsEnabled
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _notificationsEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                          color: _notificationsEnabled ? Colors.green : Colors.grey,
                        ),
                      ),
                      title: const Text('Post Notifications'),
                      subtitle: const Text('Get alerts for likes and comments'),
                      value: _notificationsEnabled,
                      onChanged: _isLoading ? null : _toggleNotifications,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Comments Toggle
                  Card(
                    elevation: 1,
                    child: SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _commentsEnabled
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _commentsEnabled ? Icons.comment : Icons.comments_disabled,
                          color: _commentsEnabled ? Colors.blue : Colors.red,
                        ),
                      ),
                      title: const Text('Allow Comments'),
                      subtitle: Text(_commentsEnabled
                          ? 'Users can comment on this post'
                          : 'Comments are disabled'),
                      value: _commentsEnabled,
                      onChanged: _isLoading ? null : _toggleComments,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Visibility Setting
                  Card(
                    elevation: 1,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getVisibilityColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_getVisibilityIcon(), color: _getVisibilityColor()),
                      ),
                      title: const Text('Post Visibility'),
                      subtitle: Text(_getVisibilityDescription(_visibility)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getVisibilityColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _visibility.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getVisibilityColor(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                      onTap: _isLoading ? null : _showVisibilityOptions,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getVisibilityColor() {
    switch (_visibility) {
      case 'public':
        return Colors.green;
      case 'followers':
        return Colors.orange;
      case 'private':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getVisibilityIcon() {
    switch (_visibility) {
      case 'public':
        return Icons.public;
      case 'followers':
        return Icons.group;
      case 'private':
        return Icons.lock;
      default:
        return Icons.help_outline;
    }
  }

  void _showVisibilityOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Post Visibility',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose who can see this post',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),

              _buildVisibilityOption('public', Icons.public, 'Public',
                  'Anyone on the platform can see this post'),

              _buildVisibilityOption('followers', Icons.group, 'Followers Only',
                  'Only users who follow you can see this post'),

              _buildVisibilityOption('private', Icons.lock, 'Private',
                  'Only you can see this post'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisibilityOption(String value, IconData icon, String title, String description) {
    final isSelected = _visibility == value;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: RadioListTile<String>(
        title: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ),
        value: value,
        groupValue: _visibility,
        onChanged: _isLoading ? null : (selectedValue) {
          if (selectedValue != null) {
            Navigator.pop(context);
            _updateVisibility(selectedValue);
          }
        },
      ),
    );
  }
}