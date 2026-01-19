import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isTyping;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isTyping = false,
  });

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied to clipboard!',
            style: GoogleFonts.inter(),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final showCopyButton = !isUser && !isTyping && text.isNotEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: EdgeInsets.fromLTRB(18, 12, 18, showCopyButton ? 8 : 12),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFFE0E0E0)
              : const Color(0xFF4DB6AC), // A gentle, muted teal
          borderRadius: BorderRadius.circular(20),
        ),
        child: isTyping
            ? const SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Use MarkdownBody for AI messages, keeping SelectableText for user messages
            isUser
                ? SelectableText(
              text,
              style: GoogleFonts.inter(
                color: isUser ? Colors.black87 : Colors.white,
                fontSize: 16,
              ),
            )
                : MarkdownBody(
              data: text,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context).copyWith(
                  textTheme: Theme.of(context).textTheme.apply(
                      bodyColor: Colors.white,
                      fontSizeFactor: 1.0,
                      decorationColor: Colors.white),
                ),
              ).copyWith(
                p: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                ),
                strong: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (showCopyButton)
              Align(
                alignment: Alignment.centerRight,
                child: Builder(
                  builder: (BuildContext builderContext) {
                    return IconButton(
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _copyToClipboard(builderContext),
                      icon: Icon(
                        Icons.content_copy_rounded,
                        color: isUser ? Colors.black54 : Colors.white54,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
