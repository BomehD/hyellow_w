import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hyellow_w/messaging/message.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hyellow_w/messaging/media_service.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final bool isHighlighted;
  final bool isSelected;
  final bool multiSelectionMode;
  final void Function(BuildContext context) onLongPress;
  final VoidCallback? onTap;
  final void Function(Message) onReply;
  final void Function(String) onDelete;
  final String Function(Timestamp?) formatTimestamp;
  final String friendId;
  final String currentUserId;
  final void Function(String? url, String? mediaType)? onDownload;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isHighlighted,
    required this.isSelected,
    required this.multiSelectionMode,
    required this.onLongPress,
    this.onTap,
    required this.onReply,
    required this.onDelete,
    required this.formatTimestamp,
    required this.friendId,
    required this.currentUserId,
    this.onDownload,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  VideoPlayerController? _videoPlayerController;
  bool _isDisposed = false;
  bool _isPlaying = false;
  final MediaService _mediaService = MediaService();

  bool _isExpanded = false;
  static const int _maxLines = 20;

  double _dragOffset = 0.0;
  bool _isDragging = false;
  static const double _slideThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.3, 0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    if (widget.isHighlighted) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _animationController.forward();
    } else if (!widget.isHighlighted && oldWidget.isHighlighted) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _videoPlayerController?.dispose();
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String _getStatusText() {
    if (widget.isMe && widget.message.readBy.containsKey(widget.friendId)) {
      final readTimestamp = widget.message.readBy[widget.friendId]!;
      return 'Seen ${DateFormat('HH:mm').format(readTimestamp.toDate())}';
    }
    return '';
  }

  IconData _getStatusIcon() {
    if (widget.isMe) {
      if (widget.message.readBy.containsKey(widget.friendId)) {
        return Icons.done_all;
      } else {
        return Icons.done;
      }
    }
    return Icons.check_circle_outline;
  }

  Color _getStatusIconColor(ColorScheme colorScheme) {
    if (widget.isMe) {
      if (widget.message.readBy.containsKey(widget.friendId)) {
        return colorScheme.primary;
      } else {
        return colorScheme.onPrimary.withOpacity(0.7);
      }
    }
    return Colors.transparent;
  }

  Future<String?> _getDownloadedFilePath(String fileName, String mediaType) async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      baseDir = Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      baseDir = await getApplicationDocumentsDirectory();
    }

    if (baseDir == null) return null;

    final subDirName = mediaType == 'audio' ? 'chat_media/audio' : 'chat_media/documents';
    final filePath = '${baseDir.path}/Hyellow/$subDirName/$fileName';
    final file = File(filePath);

    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  void _handleMediaTap(String mediaUrl, String? mediaType, String fileName) async {
    if (kIsWeb) {
      await launchUrl(Uri.parse(mediaUrl));
    } else {
      final cachedFile = await _mediaService.getCachedFile(mediaUrl);
      final filePath = cachedFile?.path ?? await _getDownloadedFilePath(fileName, mediaType ?? '');
      if (filePath != null) {
        await OpenFilex.open(filePath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File not found locally. Downloading...')),
          );
        }
        if (await canLaunchUrl(Uri.parse(mediaUrl))) {
          await launchUrl(Uri.parse(mediaUrl));
        }
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.multiSelectionMode) return;
    setState(() {
      _isDragging = true;
      _dragOffset = 0.0;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.multiSelectionMode || !_isDragging) return;

    setState(() {
      // For right-to-left swipe (reply), allow negative delta
      // For left-to-right swipe on own messages (delete), allow positive delta
      if (widget.isMe) {
        // Own messages: swipe right to delete
        _dragOffset = details.delta.dx > 0 ? _dragOffset + details.delta.dx : _dragOffset;
        _dragOffset = _dragOffset.clamp(0.0, _slideThreshold * 2);
      } else {
        // Others' messages: swipe left to reply
        _dragOffset = details.delta.dx < 0 ? _dragOffset + details.delta.dx.abs() : _dragOffset;
        _dragOffset = _dragOffset.clamp(0.0, _slideThreshold * 2);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.multiSelectionMode || !_isDragging) return;

    setState(() {
      _isDragging = false;
    });

    if (_dragOffset > _slideThreshold) {
      if (widget.isMe) {
        // Trigger delete for own messages
        _triggerDelete();
      } else {
        // Trigger reply for others' messages
        _triggerReply();
      }
    }

    // Reset position
    setState(() {
      _dragOffset = 0.0;
    });
  }

  void _triggerReply() {
    widget.onReply(widget.message);
    // Optional: Add haptic feedback
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }
  }

  void _triggerDelete() {
    // Show confirmation dialog before deleting
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Message"),
          content: const Text("Are you sure you want to delete this message?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("CANCEL"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDelete(widget.message.id);
                // Optional: Add haptic feedback
                if (!kIsWeb) {
                  HapticFeedback.mediumImpact();
                }
              },
              child: const Text("DELETE"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMediaContent(BuildContext context, ColorScheme colorScheme) {
    if (widget.message.mediaUrl == null || widget.message.mediaUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final String mediaUrl = widget.message.mediaUrl!;
    final String? mediaType = widget.message.mediaType;

    final uri = Uri.parse(mediaUrl);
    String fileName = Uri.decodeComponent(uri.pathSegments.last).split('?').first;
    fileName = fileName.split('/').last;

    Widget mediaWidget;
    switch (mediaType) {
      case 'image':
        mediaWidget = Container(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: mediaUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        );
        break;
      case 'video':
        mediaWidget = Container(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 150),
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_fill, size: 50),
                SizedBox(height: 5),
                Text('Video', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
        break;
      case 'audio':
      case 'document':
      case 'any':
        mediaWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isMe ? colorScheme.primary.withOpacity(0.7) : colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mediaType == 'audio' ? Icons.audiotrack : Icons.insert_drive_file,
                color: widget.isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                size: 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fileName,
                  style: TextStyle(
                    color: widget.isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
        break;
      default:
        mediaWidget = const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.multiSelectionMode ? null : () => _handleMediaTap(mediaUrl, mediaType, fileName),
      child: mediaWidget,
    );
  }

  Widget _buildSlideBackground() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_dragOffset <= 0) return const SizedBox.shrink();

    IconData icon;
    Color backgroundColor;
    Color iconColor;
    String actionText;

    if (widget.isMe) {
      // Delete action for own messages
      icon = Icons.delete;
      backgroundColor = Colors.red;
      iconColor = Colors.white;
      actionText = 'Delete';
    } else {
      // Reply action for others' messages
      icon = Icons.reply;
      backgroundColor = colorScheme.primary;
      iconColor = Colors.white;
      actionText = 'Reply';
    }

    return Positioned.fill(
      child: Container(
        alignment: widget.isMe ? Alignment.centerLeft : Alignment.centerRight,
        color: backgroundColor.withOpacity((_dragOffset / _slideThreshold).clamp(0.0, 1.0) * 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 4),
            Text(
              actionText,
              style: TextStyle(
                color: iconColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Background colors for swipe actions
    final Color replyBgColor = Colors.green.withOpacity(0.5);
    final Color deleteBgColor = Colors.red;
    final Icon replyIcon = const Icon(Icons.reply, color: Colors.white);
    final Icon deleteIcon = const Icon(Icons.delete, color: Colors.white);

    Color bubbleColor;
    if (widget.isSelected) {
      bubbleColor = colorScheme.secondaryContainer;
    } else if (widget.isHighlighted) {
      bubbleColor = widget.isMe ? colorScheme.primary : colorScheme.secondary;
    } else {
      if (widget.isMe) {
        bubbleColor = isDark ? colorScheme.primaryContainer : colorScheme.primary;
      } else {
        bubbleColor = isDark ? Colors.grey[850]! : colorScheme.surfaceVariant;
      }
    }

    Border? bubbleBorder;
    if (widget.isSelected) {
      bubbleBorder = Border.all(color: colorScheme.secondary, width: 2);
    } else if (widget.isHighlighted) {
      bubbleBorder = Border.all(color: widget.isMe ? colorScheme.secondary : colorScheme.primary, width: 2);
    }

    Color messageTextColor;
    if (widget.isMe) {
      messageTextColor = isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary;
    } else {
      messageTextColor = isDark ? Colors.white : colorScheme.onSurface;
    }

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Dismissible(
        key: ValueKey(widget.message.id),
        direction: DismissDirection.horizontal,
        confirmDismiss: widget.multiSelectionMode
            ? (direction) async => false
            : (direction) async {
          if (widget.isMe) {
            if (direction == DismissDirection.startToEnd) {
              widget.onReply(widget.message);
              return false;
            } else if (direction == DismissDirection.endToStart) {
              return await showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text("Confirm Delete"),
                    content: const Text("Are you sure you want to delete this message?"),
                    actions: <Widget>[
                      TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text("CANCEL")
                      ),
                      TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text("DELETE")
                      ),
                    ],
                  );
                },
              );
            }
          } else {
            if (direction == DismissDirection.endToStart) {
              widget.onReply(widget.message);
              return false;
            } else if (direction == DismissDirection.startToEnd) {
              return await showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text("Confirm Delete"),
                    content: const Text("Are you sure you want to delete this message?"),
                    actions: <Widget>[
                      TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text("CANCEL")
                      ),
                      TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text("DELETE")
                      ),
                    ],
                  );
                },
              );
            }
          }
          return false;
        },
        onDismissed: (direction) {
          if (widget.isMe) {
            if (direction == DismissDirection.endToStart) {
              widget.onDelete(widget.message.id);
            }
          } else {
            if (direction == DismissDirection.startToEnd) {
              widget.onDelete(widget.message.id);
            }
          }
        },
        background: widget.multiSelectionMode
            ? Container()
            : Container(
          color: widget.isMe ? replyBgColor : deleteBgColor,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: widget.isMe ? replyIcon : deleteIcon,
        ),
        secondaryBackground: widget.multiSelectionMode
            ? Container()
            : Container(
          color: widget.isMe ? deleteBgColor : replyBgColor,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: widget.isMe ? deleteIcon : replyIcon,
        ),
        child: GestureDetector(
          onTap: () {
            if (widget.onTap != null) {
              widget.onTap!();
            }
          },
          onLongPress: () {
            widget.onLongPress(context);
          },
          behavior: HitTestBehavior.opaque,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: EdgeInsets.only(
                top: 8,
                bottom: 8,
                left: widget.isMe ? 80 : 10,
                right: widget.isMe ? 10 : 80,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(15),
                  topRight: const Radius.circular(15),
                  bottomLeft: widget.isMe ? const Radius.circular(15) : const Radius.circular(0),
                  bottomRight: widget.isMe ? const Radius.circular(0) : const Radius.circular(15),
                ),
                border: bubbleBorder,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (widget.message.mediaUrl != null && widget.message.mediaUrl!.isNotEmpty)
                    _buildMediaContent(context, colorScheme),
                  if (widget.message.content.isNotEmpty)
                    Text(
                        widget.message.content,
                        style: TextStyle(color: messageTextColor, fontSize: 16)
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.formatTimestamp(widget.message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (widget.isMe) ...[
                        const SizedBox(width: 5),
                        Icon(
                          _getStatusIcon(),
                          size: 12,
                          color: _getStatusIconColor(colorScheme),
                        ),
                      ],
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}