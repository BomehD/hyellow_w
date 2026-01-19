// lib/messaging/chat_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/messaging/message_bubble.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../messaging/message.dart';
import 'chat_app_bar.dart';
import 'chat_services.dart';
import 'media_service.dart';
import 'message_input_field.dart';
import 'package:hyellow_w/utils/media_downloader.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> friend;

  const ChatDetailScreen({super.key, required this.friend});

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final MediaService _mediaService = MediaService();

  String? _chatId;
  Stream<QuerySnapshot>? _messagesStream;
  bool _isMuted = false;
  bool _isPinned = false;
  Message? _replyingToMessage;
  String? _editingMessageId;

  String? _highlightedMessageId;
  OverlayEntry? _overlayEntry;

  bool _multiSelectionMode = false;
  final Set<String> _selectedMessages = {};

  bool _isUploadingMedia = false;
  bool _isLoading = true;

  bool _isBlocked = false;
  bool _isBlockedByOther = false; // NEW: whether the other user blocked current user

  @override
  void initState() {
    super.initState();
    _checkExistingChat();
    _loadBlockedStatus();
    _loadBlockedByOtherStatus();
  }

  Future<void> _loadBlockedStatus() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    try {
      final blockDoc = await _firestore.collection('Blocks').doc(currentUserId).get();
      final blockedList = blockDoc.data()?['blocked'] as List<dynamic>?;
      if (mounted) {
        setState(() {
          _isBlocked = blockedList?.contains(widget.friend['id']) ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading blocked status: $e');
    }
  }

  Future<void> _loadBlockedByOtherStatus() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final blockDoc = await _firestore.collection('Blocks').doc(widget.friend['id']).get();
      final blockedList = blockDoc.data()?['blocked'] as List<dynamic>?;

      if (mounted) {
        setState(() {
          _isBlockedByOther = blockedList?.contains(currentUserId) ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading "blocked by other" status: $e');
    }
  }

  void _checkExistingChat() async {
    final chatId = await _chatService.getExistingChatId(widget.friend['id']);
    if (mounted) {
      setState(() {
        _chatId = chatId;
        if (_chatId != null) {
          _messagesStream = _firestore
              .collection('chats')
              .doc(_chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .snapshots();
        }
        _isLoading = false;
      });

      if (chatId != null) {
        _chatService.markMessagesAsRead(chatId, widget.friend['id']);
        _listenToChatStatus(chatId);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _listenToChatStatus(String chatId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final chatData = snapshot.data()!;
        final currentUserId = currentUser.uid;

        final mutedBy = (chatData['mutedBy'] as List<dynamic>?)?.cast<String>() ?? [];
        final pinnedBy = (chatData['pinnedBy'] as List<dynamic>?)?.cast<String>() ?? [];

        final newIsMuted = mutedBy.contains(currentUserId);
        final newIsPinned = pinnedBy.contains(currentUserId);

        if (_isMuted != newIsMuted || _isPinned != newIsPinned) {
          if (mounted) {
            setState(() {
              _isMuted = newIsMuted;
              _isPinned = newIsPinned;
            });
          }
        }
      }
    });
  }

  void _sendMessage({String? mediaUrl, String? mediaType}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final String currentMessageText = _messageController.text.trim();

    if (currentMessageText.isEmpty && mediaUrl == null) {
      if (_chatId == null) {
        return;
      }
    }

    if (_editingMessageId != null) {
      if (mediaUrl == null) {
        if (_chatId != null) {
          _chatService.editMessage(context, _chatId!, _editingMessageId!, currentMessageText);
        }
      }
      setState(() {
        _editingMessageId = null;
        _messageController.clear();
      });
    } else {
      bool showLoading = mediaUrl != null;

      if (_chatId == null) {
        if (showLoading) {
          setState(() {
            _isUploadingMedia = true;
          });
        }

        final newChatId = await _chatService.createChatAndSendMessage(
          currentMessageText,
          widget.friend['id'],
          replyToMessageId: _replyingToMessage?.id,
          replyToSenderName: _replyingToMessage?.senderId == _auth.currentUser!.uid
              ? 'You'
              : widget.friend['name'],
          replyToContent: _replyingToMessage?.content,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
        );

        if (mounted) {
          setState(() {
            _chatId = newChatId;
            if (_chatId != null) {
              _messagesStream = _firestore
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots();
            }
            if (showLoading) {
              _isUploadingMedia = false;
            }
          });
          if (newChatId != null) {
            _listenToChatStatus(newChatId);
          }
        }
      } else {
        _chatService.sendMessage(
          _chatId!,
          currentMessageText,
          widget.friend['id'],
          replyToMessageId: _replyingToMessage?.id,
          replyToSenderName: _replyingToMessage?.senderId == _auth.currentUser!.uid
              ? 'You'
              : widget.friend['name'],
          replyToContent: _replyingToMessage?.content,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
        );
      }
      _messageController.clear();
    }
    setState(() {
      _replyingToMessage = null;
    });
    _removeOverlay();
  }

  Future<void> _attachMedia() async {
    final FileType? selectedType = await showModalBottomSheet<FileType>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image'),
                onTap: () {
                  Navigator.pop(context, FileType.image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Video'),
                onTap: () {
                  Navigator.pop(context, FileType.video);
                },
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack),
                title: const Text('Audio'),
                onTap: () {
                  Navigator.pop(context, FileType.audio);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Document'),
                onTap: () {
                  Navigator.pop(context, FileType.any);
                },
              ),
            ],
          ),
        );
      },
    );

    if (selectedType == null) return;

    setState(() {
      _isUploadingMedia = true;
    });

    try {
      final file = await _mediaService.pickFile(selectedType);
      if (file != null) {
        String mediaTypeName;
        switch (selectedType) {
          case FileType.image:
            mediaTypeName = 'image';
            break;
          case FileType.video:
            mediaTypeName = 'video';
            break;
          case FileType.audio:
            mediaTypeName = 'audio';
            break;
          default:
            mediaTypeName = 'document';
            break;
        }

        final downloadUrl = await _mediaService.uploadFile(file, mediaTypeName);

        if (downloadUrl != null) {
          _sendMessage(mediaUrl: downloadUrl, mediaType: mediaTypeName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload media.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error attaching media: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting or uploading media: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
        });
      }
    }
  }

  Future<void> _downloadMedia(String? url, String? mediaType) async {
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media URL is missing.')),
      );
      return;
    }

    await MediaDownloader.downloadMedia(context, url, mediaType);
  }

  Future<void> _deleteMessage(String messageId) async {
    if (_chatId == null) return;
    await _chatService.deleteMessage(context, _chatId!, messageId);
    _removeOverlay();
  }

  void _setReplyingTo(Message message) {
    setState(() {
      _replyingToMessage = message;
      _editingMessageId = null;
    });
    _messageFocusNode.requestFocus();
    _removeOverlay();
  }

  void _clearReplyingTo() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_highlightedMessageId != null) {
      setState(() {
        _highlightedMessageId = null;
      });
    }
  }

  void _toggleMessageSelection(Message message) {
    setState(() {
      if (_selectedMessages.contains(message.id)) {
        _selectedMessages.remove(message.id);
      } else {
        _selectedMessages.add(message.id);
      }

      if (_selectedMessages.isEmpty) {
        _multiSelectionMode = false;
        _removeOverlay();
      } else {
        _multiSelectionMode = true;
        _removeOverlay();
      }
    });
  }

  void _enterMultiSelectionMode(Message message) {
    if (_multiSelectionMode) return;

    setState(() {
      _multiSelectionMode = true;
      _selectedMessages.clear();
      _selectedMessages.add(message.id);
      _removeOverlay();
    });
  }

  void _showBubbleOptions(BuildContext bubbleContext, Message message, bool isMe) {
    if (_multiSelectionMode) {
      _toggleMessageSelection(message);
      return;
    }

    _removeOverlay();

    setState(() {
      _highlightedMessageId = message.id;
    });

    final RenderBox? renderBox = bubbleContext.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      debugPrint("Could not find RenderBox for message ${message.id}");
      return;
    }

    final Offset globalBubblePosition = renderBox.localToGlobal(Offset.zero);
    final Size bubbleSize = renderBox.size;

    final double overlayHeight = 40;
    final double padding = 8;

    double top = globalBubblePosition.dy - overlayHeight - padding;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    if (top < (statusBarHeight + appBarHeight + padding)) {
      top = globalBubblePosition.dy + bubbleSize.height + padding;
      if (top + overlayHeight > screenHeight - kBottomNavigationBarHeight - padding) {
        top = (screenHeight - overlayHeight) / 2;
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Choose an overlay background that contrasts in both light/dark modes.
    final overlayBg = isDark ? Colors.grey[900]!.withOpacity(0.85) : Colors.black.withOpacity(0.8);
    final overlayIconColor = Colors.white; // good contrast against overlayBg

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: isMe ? null : globalBubblePosition.dx,
        right: isMe ? (screenWidth - (globalBubblePosition.dx + bubbleSize.width)) : null,
        top: top,
        height: overlayHeight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth - (2 * padding),
            minWidth: 0,
          ),
          child: IntrinsicWidth(
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: overlayBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 5,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.reply, color: overlayIconColor, size: 20),
                      tooltip: 'Reply',
                      onPressed: () {
                        _setReplyingTo(message);
                        _removeOverlay();
                      },
                    ),
                    if (isMe && message.mediaUrl == null)
                      IconButton(
                        icon: Icon(Icons.edit, color: overlayIconColor, size: 20),
                        tooltip: 'Edit',
                        onPressed: () {
                          setState(() {
                            _editingMessageId = message.id;
                            _messageController.text = message.content;
                            _replyingToMessage = null;
                          });
                          _messageFocusNode.requestFocus();
                          _removeOverlay();
                        },
                      ),
                    IconButton(
                      icon: Icon(Icons.select_all, color: overlayIconColor, size: 20),
                      tooltip: 'Select',
                      onPressed: () {
                        _enterMultiSelectionMode(message);
                      },
                    ),
                    if (isMe)
                      IconButton(
                        icon: Icon(Icons.delete, color: overlayIconColor, size: 20),
                        tooltip: 'Delete',
                        onPressed: () async {
                          bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("Confirm Delete"),
                                content: Text("Are you sure you want to delete this message?"),
                                actions: <Widget>[
                                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("CANCEL")),
                                  TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("DELETE")),
                                ],
                              );
                            },
                          );
                          if (confirm == true) {
                            _deleteMessage(message.id);
                          }
                          _removeOverlay();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)?.insert(_overlayEntry!);
  }

  Future<void> _clearChat() async {
    if (_chatId == null) return;
    await _chatService.clearChat(context, _chatId!);
    _removeOverlay();
  }

  Future<void> _deleteChat() async {
    if (_chatId == null) return;
    await _chatService.deleteChat(context, _chatId!);
    _removeOverlay();
  }

  Future<void> _toggleMuteChat() async {
    if (_chatId == null) return;
    await _chatService.toggleMuteChat(context, _chatId!, _isMuted);
  }

  Future<void> _togglePinChat() async {
    if (_chatId == null) return;
    await _chatService.togglePinChat(context, _chatId!, _isPinned);
  }

  void _copySelectedMessages() {
    if (_selectedMessages.isEmpty || _chatId == null) return;
    _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .where(FieldPath.documentId, whereIn: _selectedMessages.toList())
        .get()
        .then((snapshot) {
      final messagesToCopy = snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
      messagesToCopy.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));

      final String copiedText = messagesToCopy
          .map((msg) {
        final sender = msg.senderId == _auth.currentUser!.uid ? 'You' : widget.friend['name'];
        if (msg.mediaUrl != null && msg.content.isEmpty) {
          return '$sender: [${msg.mediaType?.toUpperCase() ?? 'Media'}] - ${msg.mediaUrl}';
        } else if (msg.mediaUrl != null && msg.content.isNotEmpty) {
          return '$sender: ${msg.content} [${msg.mediaType?.toUpperCase() ?? 'Media'}] - ${msg.mediaUrl}';
        }
        return '$sender: ${msg.content}';
      })
          .join('\n');

      Clipboard.setData(ClipboardData(text: copiedText)).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedMessages.length} message(s) copied to clipboard!')),
        );
        setState(() {
          _selectedMessages.clear();
          _multiSelectionMode = false;
        });
      });
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to copy messages: ${e.toString()}')),
      );
    });
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessages.isEmpty || _chatId == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete ${_selectedMessages.length} Messages?"),
          content: Text("Are you sure you want to delete these ${_selectedMessages.length} messages?"),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("CANCEL")),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("DELETE")),
          ],
        );
      },
    );

    if (confirm == true) {
      for (String messageId in _selectedMessages) {
        await _chatService.deleteMessage(context, _chatId!, messageId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedMessages.length} message(s) deleted.')),
        );
        setState(() {
          _selectedMessages.clear();
          _multiSelectionMode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: ChatDetailAppBar(
        friend: widget.friend,
        multiSelectionMode: _multiSelectionMode,
        selectedMessageCount: _selectedMessages.length,
        onCloseMultiSelection: () {
          setState(() {
            _multiSelectionMode = false;
            _selectedMessages.clear();
            _removeOverlay();
          });
        },
        onCopySelected: _copySelectedMessages,
        onDeleteSelected: _deleteSelectedMessages,
        isMuted: _isMuted,
        isPinned: _isPinned,
        onToggleMute: _toggleMuteChat,
        onTogglePin: _togglePinChat,
        onClearChat: _clearChat,
        onDeleteChat: _deleteChat,
        chatService: _chatService,
        isBlocked: _isBlocked,
      ),
      body: GestureDetector(
        onTap: () {
          if (_multiSelectionMode) {
            setState(() {
              _selectedMessages.clear();
              _multiSelectionMode = false;
            });
          }
          _removeOverlay();
          FocusScope.of(context).unfocus();
        },
        child: Container(
          color: colorScheme.background,
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const SizedBox.shrink()
                    : _chatId == null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.waving_hand_rounded,
                        size: 54.0,
                        color: colorScheme.primary.withOpacity(0.8),
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        "Let's get this conversation started!",
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        "Send your first message and say hi.",
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
                    : StreamBuilder<QuerySnapshot>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      if (_messagesStream != null) {
                        return const SizedBox.shrink();
                      }
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.waving_hand_rounded,
                              size: 54.0,
                              color: colorScheme.primary.withOpacity(0.8),
                            ),
                            const SizedBox(height: 16.0),
                            Text(
                              "This is the start of your conversation.",
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    var messages = snapshot.data!.docs.map((doc) => Message.fromFirestore(doc)).toList();

                    for (var message in messages) {
                      if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
                        _mediaService.cacheFile(message.mediaUrl!);
                      }
                    }

                    return ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        bool isMe = message.senderId == _auth.currentUser?.uid;
                        bool isHighlighted = _highlightedMessageId == message.id;
                        bool isSelected = _selectedMessages.contains(message.id);

                        return MessageBubble(
                          message: message,
                          isMe: isMe,
                          isHighlighted: isHighlighted,
                          isSelected: isSelected,
                          multiSelectionMode: _multiSelectionMode,
                          onLongPress: (bubbleContext) {
                            if (!_multiSelectionMode) {
                              _showBubbleOptions(bubbleContext, message, isMe);
                            } else {
                              _toggleMessageSelection(message);
                            }
                          },
                          onTap: () {
                            _removeOverlay();
                            if (_multiSelectionMode) {
                              _toggleMessageSelection(message);
                            }
                          },
                          onReply: _setReplyingTo,
                          onDelete: _deleteMessage,
                          formatTimestamp: _chatService.formatMessageTimestamp,
                          friendId: widget.friend['id'],
                          currentUserId: _auth.currentUser!.uid,
                          onDownload: _downloadMedia,
                        );
                      },
                    );
                  },
                ),
              ),
              if (_isUploadingMedia)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Uploading media...',
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              _multiSelectionMode || _isBlocked || _isBlockedByOther
                  ? const SizedBox.shrink()
                  : MessageInputField(
                messageController: _messageController,
                messageFocusNode: _messageFocusNode,
                replyingToMessage: _replyingToMessage,
                editingMessageId: _editingMessageId,
                friendName: widget.friend['name'],
                currentUserId: _auth.currentUser!.uid,
                onSendMessage: _sendMessage,
                onClearReplyingTo: _clearReplyingTo,
                onAttachMedia: _attachMedia,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
