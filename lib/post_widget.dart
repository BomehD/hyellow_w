import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hyellow_w/comment_interactions.dart';
import 'package:hyellow_w/like_interactions.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';

import 'package:hyellow_w/profile_screen1.dart';
import 'package:hyellow_w/profile_view.dart';
import 'package:share_plus/share_plus.dart';
import 'FullscreenImageViewer.dart';
import 'package:hyellow_w/utils/download_profile_image.dart';

import 'full_screen_video_player.dart';
import 'expandable_post_text.dart';
import 'marquee_widget.dart';
import 'manage_post_screen.dart';
import 'package:hyellow_w/post_interactions.dart';
import 'package:hyellow_w/utils/media_downloader_mobile.dart';

// Helper function to show fullscreen image
void _showFullscreenImage(BuildContext context, String imageUrl, String heroTag) {
  if (imageUrl.isNotEmpty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
      ),
    );
  }


}

class PostWidget extends StatefulWidget {
  final String postId;
  final String postContent;
  final String userId;
  final String authorId;
  final String authorName;
  final String? profileImageUrl;
  final String? imageUrl;
  final String? videoUrl;
  final List<String>? imageUrls; // NEW: Added for multiple images
  final Timestamp timestamp;
  final String interest;
  final int likeCount;
  final int commentCount;
  final bool initiallyLiked;
  final void Function(String postId)? onDelete;
  final String postVisibility;
  final bool areCommentsEnabled;
  final String authorAbout;
  final String authorTitle;
  final String authorPhone;
  final String authorEmail;
  final bool isBlockedByAuthor; // Added property to handle two-way block

  final VoidCallback? onPostEdited;
  final VoidCallback? onPostHidden;
  final VoidCallback? onUserMuted;
  final VoidCallback? onUserBlocked;
  final void Function(String postId, bool isLiked)? onLikeToggled;

  final bool initiallyBookmarked;
  final VoidCallback? onEditPost;

  const PostWidget({
    super.key,
    required this.postId,
    required this.postContent,
    required this.userId,
    required this.authorId,
    required this.authorName,
    this.profileImageUrl,
    required this.timestamp,
    required this.interest,
    required this.likeCount,
    required this.commentCount,
    required this.initiallyLiked,
    this.imageUrl,
    this.videoUrl,
    this.imageUrls, // NEW: Added to constructor
    this.onDelete,
    required this.postVisibility,
    required this.areCommentsEnabled,
    this.authorAbout = '',
    this.authorTitle = '',
    this.authorPhone = '',
    this.authorEmail = '',
    this.onPostEdited,
    this.onPostHidden,
    this.onUserMuted,
    this.onUserBlocked,
    this.onLikeToggled,
    this.initiallyBookmarked = false,
    required this.onEditPost,
    required this.isBlockedByAuthor, // Added to constructor
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  final ValueNotifier<bool> _isLikedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _likeCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _commentCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isSavedNotifier = ValueNotifier<bool>(false);

  late bool _currentCommentsEnabled;
  StreamSubscription<DocumentSnapshot>? _commentsEnabledSubscription;
  StreamSubscription<DocumentSnapshot>? postSubscription;
  StreamSubscription<DocumentSnapshot>? likeDocSubscription;

  // Internal video controller management
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoFuture;
  bool _showControls = true; // To show/hide the play/pause icon

  // NEW: Added for media sliding functionality
  late PageController _pageController;
  int _currentMediaIndex = 0;

  // Removed internal blocking state as it's now handled by the parent widget.
  // bool _isBlocked = false;
  // bool _isLoadingBlockStatus = false;

  @override
  void initState() {
    super.initState();
    _isLikedNotifier.value = widget.initiallyLiked;
    _likeCountNotifier.value = widget.likeCount;
    _commentCountNotifier.value = widget.commentCount;
    _currentCommentsEnabled = widget.areCommentsEnabled;
    _isSavedNotifier.value = widget.initiallyBookmarked;

    _listenForCommentsEnabledChanges();
    _checkIfSaved();
    _attachRealtimeListeners();
    _initVideoController();
    _pageController = PageController(); // NEW: Initialize page controller
    // Removed the internal _checkBlockStatus() call
  }

  void _initVideoController() {
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
      _initializeVideoFuture = _videoController?.initialize().then((_) {
        // You can uncomment this if you want the video to auto-play when it loads
        // _videoController?.play();
      });
      _videoController?.addListener(() {
        if (mounted) {
          // This ensures the UI rebuilds when the controller state changes
          setState(() {});
        }
      });
      // Listen for video state changes to hide controls after a few seconds
      _videoController!.addListener(() {
        if (_videoController!.value.isPlaying) {
          _hideControls();
        }
      });
    }
  }

  // Removed the _checkBlockStatus() method

  void _hideControls() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _videoController!.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _showControls = true;
      } else {
        _videoController!.play();
        _showControls = true;
        // _hideControls will be called by the listener
      }
    });
  }

  void _attachRealtimeListeners() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);

    postSubscription = postRef.snapshots().listen((snapshot) {
      if (!mounted) return;
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final serverLikeCount = data['likeCount'] as int? ?? widget.likeCount;
      final serverCommentCount = data['commentCount'] as int? ?? widget.commentCount;
      final serverCommentsEnabled = data['commentsEnabled'] as bool? ?? widget.areCommentsEnabled;

      _likeCountNotifier.value = serverLikeCount;
      _commentCountNotifier.value = serverCommentCount;
      if (_currentCommentsEnabled != serverCommentsEnabled) {
        setState(() {
          _currentCommentsEnabled = serverCommentsEnabled;
        });
      }
    });

    if (currentUser != null) {
      final likeDocRef = postRef.collection('likes').doc(currentUser.uid);
      likeDocSubscription = likeDocRef.snapshots().listen((snap) {
        if (!mounted) return;
        _isLikedNotifier.value = snap.exists;
      });
    }
  }

  void _checkIfSaved() async {
    if (widget.userId.isEmpty) return;
    final savedDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('bookmarks')
        .doc(widget.postId)
        .get(const GetOptions(source: Source.serverAndCache));

    if (mounted) {
      _isSavedNotifier.value = savedDoc.exists;
    }
  }

  Future<void> _toggleSave() async {
    if (widget.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save posts.')),
      );
      return;
    }
    final saveRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('bookmarks')
        .doc(widget.postId);
    final bool wasSaved = _isSavedNotifier.value;
    _isSavedNotifier.value = !wasSaved;
    try {
      if (!wasSaved) {
        await saveRef.set({'timestamp': FieldValue.serverTimestamp()});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post saved!')),
        );
      } else {
        await saveRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post unsaved.')),
        );
      }
    } catch (e) {
      print('Error updating saved status: $e');
      if (mounted) {
        _isSavedNotifier.value = wasSaved;
      }
    }
  }

  void _listenForCommentsEnabledChanges() {
    _commentsEnabledSubscription = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final bool newCommentsEnabledStatus = snapshot.data()?['commentsEnabled'] ?? true;
        if (_currentCommentsEnabled != newCommentsEnabledStatus) {
          setState(() {
            _currentCommentsEnabled = newCommentsEnabledStatus;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyLiked != oldWidget.initiallyLiked) {
      _isLikedNotifier.value = widget.initiallyLiked;
    }
    if (widget.likeCount != oldWidget.likeCount) {
      _likeCountNotifier.value = widget.likeCount;
    }
    if (widget.commentCount != oldWidget.commentCount) {
      _commentCountNotifier.value = widget.commentCount;
    }
    if (widget.initiallyBookmarked != oldWidget.initiallyBookmarked) {
      _isSavedNotifier.value = widget.initiallyBookmarked;
    }
    if (oldWidget.postId != widget.postId) {
      _commentsEnabledSubscription?.cancel();
      _listenForCommentsEnabledChanges();
      _checkIfSaved();

      postSubscription?.cancel();
      likeDocSubscription?.cancel();
      _attachRealtimeListeners();
    }
    // New logic for when video URL changes
    if (oldWidget.videoUrl != widget.videoUrl) {
      _videoController?.dispose();
      _initVideoController();
    }
  }

  Future<void> _toggleLike() async {
    await LikeInteractions.toggleLike(
      postId: widget.postId,
      postAuthorId: widget.authorId,
      postContent: widget.postContent,
      isLikedNotifier: _isLikedNotifier,
      likeCountNotifier: _likeCountNotifier,
      // NEW: Pass the isBlockedByAuthor flag
      isPostAuthorBlocked: widget.isBlockedByAuthor,
    );
    widget.onLikeToggled?.call(widget.postId, _isLikedNotifier.value);
  }

  void _showCommentsDialog() {
    CommentInteractions.showCommentsDialog(
      context,
      widget.postId,
      widget.authorId,
      widget.postContent,
      _commentCountNotifier,
      // NEW: Pass the isBlockedByAuthor flag to the comments dialog
      isPostAuthorBlocked: widget.isBlockedByAuthor,
    );
  }

  void _showOptionsMenu() {
    final currentUserId = widget.userId;
    final isOwner = widget.authorId == currentUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow bottom sheet to be scrollable
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          constraints: BoxConstraints(
            // Limit height to 80% of screen to prevent overflow
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOwner) ...[
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Manage Post'),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManagePostScreen(
                            postId: widget.postId,
                            authorId: widget.authorId,
                            postContent: widget.postContent,
                            imageUrl: widget.imageUrl,
                            videoUrl: widget.videoUrl,
                            currentVisibility: widget.postVisibility,
                            commentsEnabled: _currentCommentsEnabled,
                          ),
                        ),
                      );
                      widget.onPostEdited?.call();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.share),
                    title: const Text('Share'),
                    onTap: () async {
                      _sharePost();
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Download Media'),
                    onTap: () async {
                      Navigator.pop(context);
                      String? mediaUrl;
                      String? mediaType;

                      if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
                        mediaUrl = widget.imageUrl;
                        mediaType = 'image';
                      } else if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
                        mediaUrl = widget.videoUrl;
                        mediaType = 'video';
                      }

                      if (mediaUrl != null) {
                        await MediaDownloader.downloadMedia(context, mediaUrl, mediaType);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No media available to download.')),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark_border),
                    title: ValueListenableBuilder<bool>(
                      valueListenable: _isSavedNotifier,
                      builder: (context, isSaved, child) {
                        return Text(isSaved ? 'Unsave Post' : 'Save Post');
                      },
                    ),
                    onTap: () async {
                      await _toggleSave();
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _confirmDeletePost();
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.report, color: Colors.orange),
                    title: const Text('Report Post'),
                    onTap: () async {
                      await _showReportDialog();
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.hide_image),
                    title: const Text('Hide Post'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _hidePostWithCallback();
                    },
                  ),
                  // Renamed to 'Block User' and will block the author of the post.
                  ListTile(
                    leading: Icon(widget.isBlockedByAuthor ? Icons.lock_open : Icons.block),
                    title: Text(widget.isBlockedByAuthor ? 'Unblock User' : 'Block User'),
                    onTap: () async {
                      Navigator.pop(context);
                      // This function now handles toggling the block status of the author.
                      await _toggleBlockUser();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.volume_off),
                    title: const Text('Mute User'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _muteUserWithCallback();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.share),
                    title: const Text('Share'),
                    onTap: () async {
                      _sharePost();
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Download Media'),
                    onTap: () async {
                      Navigator.pop(context);
                      String? mediaUrl;
                      String? mediaType;

                      if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
                        mediaUrl = widget.imageUrl;
                        mediaType = 'image';
                      } else if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
                        mediaUrl = widget.videoUrl;
                        mediaType = 'video';
                      }

                      if (mediaUrl != null) {
                        await MediaDownloader.downloadMedia(context, mediaUrl, mediaType);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No media available to download.')),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark_border),
                    title: ValueListenableBuilder<bool>(
                      valueListenable: _isSavedNotifier,
                      builder: (context, isSaved, child) {
                        return Text(isSaved ? 'Unsave Post' : 'Save Post');
                      },
                    ),
                    onTap: () async {
                      await _toggleSave();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _hidePostWithCallback() async {
    try {
      await PostInteractions.hidePost(widget.postId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post hidden successfully')),
      );
      widget.onPostHidden?.call();
    } catch (e) {
      print('Error hiding post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to hide post')),
      );
    }
  }

  Future<void> _muteUserWithCallback() async {
    try {
      await PostInteractions.muteUser(widget.authorId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.authorName} has been muted')),
      );
      widget.onUserMuted?.call();
    } catch (e) {
      print('Error muting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mute user')),
      );
    }
  }

  Future<void> _toggleBlockUser() async {
    try {
      if (widget.isBlockedByAuthor) {
        await PostInteractions.unblockUser(widget.authorId);
      } else {
        await PostInteractions.blockUser(widget.authorId);
      }
      widget.onUserBlocked?.call();
    } catch (e) {
      print('Error toggling block status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle block status: $e')),
      );
    }
  }

  Future<void> _showReportDialog() async {
    final TextEditingController _reportReasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          elevation: 10.0,
          title: const Text('Report Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: _reportReasonController,
              decoration: InputDecoration(
                hintText: "Reason for reporting...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                ),
                contentPadding: const EdgeInsets.all(12.0),
              ),
              maxLines: 4,
              keyboardType: TextInputType.multiline,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = _reportReasonController.text.trim();
                if (reason.isNotEmpty) {
                  try {
                    await PostInteractions.reportPost(widget.postId, reason);
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post reported successfully!')),
                    );
                  } catch (e) {
                    print('Error reporting post: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to report post')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide a reason for the report.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeletePost() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to remove this post from your posts?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                _deletePost();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deletePost() {
    widget.onDelete?.call(widget.postId);
  }

  void _sharePost() {
    final String postLink = 'https://hyellow-w.web.app/posts/${widget.postId}';
    final String shareText = '${widget.postContent}\n\nCheck out this post: $postLink';
    Share.share(shareText);
  }

  @override
  void dispose() {
    _isLikedNotifier.dispose();
    _likeCountNotifier.dispose();
    _commentCountNotifier.dispose();
    _isSavedNotifier.dispose();
    _commentsEnabledSubscription?.cancel();
    postSubscription?.cancel();
    likeDocSubscription?.cancel();
    // Dispose of the video controller here, as this widget created it.
    _videoController?.dispose();
    _pageController.dispose(); // NEW: Dispose page controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.zero,
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(),
            const SizedBox(height: 10),
            ExpandablePostText(text: widget.postContent),
            const SizedBox(height: 10),
            _buildMediaWidget(),
            const SizedBox(height: 10),
            _buildPostActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    IconData? visibilityIcon;
    String? visibilityTooltip;
    if (widget.postVisibility == 'private') {
      visibilityIcon = Icons.lock;
      visibilityTooltip = 'Private Post (Only you can see this)';
    } else if (widget.postVisibility == 'followers') {
      visibilityIcon = Icons.group;
      visibilityTooltip = 'Followers Only Post';
    } else if (widget.postVisibility == 'public') {
      visibilityTooltip = 'Public Post';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty) {
                  String heroTag = 'post-${widget.userId}-${widget.profileImageUrl}';
                  _showFullscreenImage(
                    context,
                    widget.profileImageUrl!,
                    heroTag,
                  );
                }
              },
              onLongPress: () async {
                if (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty) {
                  await DownloadProfileImage.downloadAndSaveImage(context, widget.profileImageUrl!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No profile image available to download.')),
                  );
                }
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage: widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty
                    ? NetworkImage(widget.profileImageUrl!)
                    : const AssetImage('assets/default_profile_image.png') as ImageProvider,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final User? currentUser = FirebaseAuth.instance.currentUser;
                  final String userId = widget.authorId;
                  final String name = widget.authorName;
                  final String interest = widget.interest;
                  final String about = widget.authorAbout;
                  final String title = widget.authorTitle;
                  final String phone = widget.authorPhone;
                  final String email = widget.authorEmail;
                  final String? profileImage = widget.profileImageUrl;

                  final Widget profileScreen;
                  if (currentUser != null && currentUser.uid == userId) {
                    profileScreen = ProfileView(
                      name: name,
                      interest: interest,
                      about: about,
                      title: title,
                      phone: phone,
                      email: email,
                      profileImage: profileImage ?? 'assets/default_profile_image.png',
                    );
                  } else {
                    profileScreen = ProfileScreen1(
                      userId: userId,
                      name: name,
                      interest: interest,
                      about: about,
                      title: title,
                      phone: phone,
                      email: email,
                      profileImage: profileImage ?? 'assets/default_profile_image.png',
                    );
                  }
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => profileScreen),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Row(
                      children: [
                        Text(
                          _formatTimestamp(widget.timestamp),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        if (visibilityIcon != null) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: visibilityTooltip,
                            child: Icon(
                              visibilityIcon,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showOptionsMenu,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (widget.interest.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 100,
              height: 20,
              child: MarqueeWidget(interest: widget.interest),
            ),
          ),
      ],
    );
  }

  Widget _buildPostActions() {
    return Row(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _isLikedNotifier,
          builder: (context, currentIsLiked, child) {
            return IconButton(
              icon: Icon(
                currentIsLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                color: widget.isBlockedByAuthor
                    ? Theme.of(context).colorScheme.outline // muted color when blocked
                    : (currentIsLiked
                    ? Theme.of(context).colorScheme.primary // active (liked) color
                    : Theme.of(context).colorScheme.onSurfaceVariant // default unliked color
                ),
              ),

              onPressed: widget.isBlockedByAuthor ? null : () async {
                await _toggleLike();
              },
            );
          },
        ),
        ValueListenableBuilder<int>(
          valueListenable: _likeCountNotifier,
          builder: (context, currentLikeCount, child) {
            return Text(currentLikeCount.toString());
          },
        ),
        const SizedBox(width: 14),
        IconButton(
          icon: Icon(
            Icons.comment_outlined,
            color: widget.isBlockedByAuthor
                ? Theme.of(context).colorScheme.outline // muted color when blocked
                : Theme.of(context).colorScheme.onSurface, // normal text/icon color
          ),
          onPressed: widget.isBlockedByAuthor ? null : _showCommentsDialog,
        ),

        ValueListenableBuilder<int>(
          valueListenable: _commentCountNotifier,
          builder: (context, currentCommentCount, child) {
            return Text(currentCommentCount.toString());
          },
        ),
        const Spacer(),
      ],
    );
  }

  // COMPLETELY REPLACED: _buildMediaWidget method with sliding functionality
  Widget _buildMediaWidget() {
    final double maxWidth = MediaQuery.of(context).size.width * 0.9;

    // Create list of media items
    List<Map<String, dynamic>> mediaItems = [];

    // Add video if exists
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      mediaItems.add({
        'type': 'video',
        'url': widget.videoUrl,
      });
    }

    // Add multiple images if they exist
    if (widget.imageUrls != null && widget.imageUrls!.isNotEmpty) {
      for (String imageUrl in widget.imageUrls!) {
        mediaItems.add({
          'type': 'image',
          'url': imageUrl,
        });
      }
    }

    // Add single image if exists (backward compatibility)
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty &&
        (widget.imageUrls == null || widget.imageUrls!.isEmpty)) {
      mediaItems.add({
        'type': 'image',
        'url': widget.imageUrl,
      });
    }

    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // If only one media item, show without PageView
    if (mediaItems.length == 1) {
      return _buildSingleMediaItem(mediaItems[0], maxWidth);
    }

    // Multiple media items - use PageView with indicators
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentMediaIndex = index;
              });
            },
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              return _buildSingleMediaItem(mediaItems[index], maxWidth);
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildPageIndicator(mediaItems.length),
      ],
    );
  }

  // NEW: Helper method to build individual media items
  Widget _buildSingleMediaItem(Map<String, dynamic> mediaItem, double maxWidth) {
    if (mediaItem['type'] == 'video') {
      return _buildVideoWidget(mediaItem['url'], maxWidth);
    } else if (mediaItem['type'] == 'image') {
      return _buildImageWidget(mediaItem['url'], maxWidth);
    }
    return const SizedBox.shrink();
  }

  // NEW: Extract video building logic
  // NEW: Updated to use GestureDetector for single/double taps
  Widget _buildVideoWidget(String videoUrl, double maxWidth) {
    if (_videoController != null && _initializeVideoFuture != null) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder(
            future: _initializeVideoFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && _videoController!.value.isInitialized) {
                return GestureDetector(
                  onTap: _togglePlayPause,
                  onDoubleTap: () => _showFullscreenVideo(context),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: maxWidth,
                        height: 200,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: _videoController!.value.size.width,
                            height: _videoController!.value.size.height,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                      ),
                      // Overlay icon for visual feedback
                      if (_showControls || !_videoController!.value.isPlaying)
                        Center(
                          child: Icon(
                            _videoController!.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                            color: Colors.white.withOpacity(0.8),
                            size: 60.0,
                          ),
                        ),
                    ],
                  ),
                );
              } else {
                return SizedBox(
                  width: maxWidth,
                  height: 200,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
            },
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // NEW: Extract image building logic with enhanced features
  Widget _buildImageWidget(String imageUrl, double maxWidth) {
    return GestureDetector(
      onTap: () {
        String heroTag = 'post-${widget.postId}-$imageUrl-$_currentMediaIndex';
        _showFullscreenImage(context, imageUrl, heroTag);
      },
      onLongPress: () {
        MediaDownloader.downloadMedia(context, imageUrl, 'image');
      },
      child: Hero(
        tag: 'post-${widget.postId}-$imageUrl-$_currentMediaIndex',
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: maxWidth,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: maxWidth,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: maxWidth,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.error_outline, size: 50),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // NEW: Build page indicator with line style
  Widget _buildPageIndicator(int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
            (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 4,
          width: _currentMediaIndex == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentMediaIndex == index
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  void _showFullscreenVideo(BuildContext context) {
    if (_videoController != null && _initializeVideoFuture != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenVideoPlayer(
            controller: _videoController!,
            initializeVideoFuture: _initializeVideoFuture!,
          ),
        ),
      );
    }
  }

  // Add the _formatTimestamp function here
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 365) return '${diff.inDays ~/ 365} year${diff.inDays ~/ 365 > 1 ? 's' : ''} ago';
    if (diff.inDays >= 30) return '${diff.inDays ~/ 30} month${diff.inDays ~/ 30 > 1 ? 's' : ''} ago';
    if (diff.inDays >= 7) return '${diff.inDays ~/ 7} week${diff.inDays ~/ 7 > 1 ? 's' : ''} ago';
    if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    if (diff.inHours > 0) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    return 'Just now';
  }
}