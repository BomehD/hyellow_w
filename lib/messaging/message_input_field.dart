import 'package:flutter/material.dart';
import 'package:hyellow_w/messaging/message.dart';

class MessageInputField extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final Message? replyingToMessage;
  final String? editingMessageId;
  final String friendName;
  final String currentUserId;
  final Future<void> Function() onSendMessage;
  final VoidCallback onClearReplyingTo;
  final VoidCallback onAttachMedia;

  const MessageInputField({
    super.key,
    required this.messageController,
    required this.messageFocusNode,
    required this.replyingToMessage,
    required this.editingMessageId,
    required this.friendName,
    required this.currentUserId,
    required this.onSendMessage,
    required this.onClearReplyingTo,
    required this.onAttachMedia,
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField> {
  bool _isSending = false;

  Future<void> _handleSend() async {
    final text = widget.messageController.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await widget.onSendMessage();
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        if (widget.replyingToMessage != null)
          Container(
            padding: const EdgeInsets.all(8.0),
            color: colorScheme.surfaceVariant,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replying to: ${widget.replyingToMessage!.senderId == widget.currentUserId ? "You" : widget.friendName}',
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        widget.replyingToMessage!.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: widget.onClearReplyingTo,
                ),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: colorScheme.onSurfaceVariant),
                  onPressed: widget.onAttachMedia,
                ),

                Expanded(
                  child: TextField(
                    controller: widget.messageController,
                    focusNode: widget.messageFocusNode,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),

                IconButton(
                  icon: Icon(
                    widget.editingMessageId != null ? Icons.check : Icons.send,
                    color: _isSending
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                  ),
                  onPressed: _isSending ? null : _handleSend,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}