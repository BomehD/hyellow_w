import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_bubble.dart';
import 'ai_assistant_logic.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_drawer.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;
  bool _isLoading = true;
  String _searchQuery = '';
  final StreamController<List<String>> _searchStreamController =
  StreamController<List<String>>.broadcast();
  final List<Map<String, dynamic>> _messages = [];

  late final AiAssistantLogic _logic;

  @override
  void initState() {
    super.initState();
    _logic = AiAssistantLogic(_messages, setState);
    _loadInitialChat();

    _controller.addListener(() {
      setState(() {
        _isTyping = _controller.text.trim().isNotEmpty;
        _handleTextInputChange(_controller.text);
      });
    });
  }

  Future<void> _loadInitialChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('ai_chats')
          .where('userId', isEqualTo: user.uid)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (chatsSnapshot.docs.isNotEmpty) {
        final lastChatId = chatsSnapshot.docs.first.id;
        await _logic.loadChat(lastChatId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading initial chat history: $e');
      }
      _messages.add({
        'text': 'Sorry, I could not load the chat history.',
        'isUser': false
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchStreamController.close();
    super.dispose();
  }

  void _handleTextInputChange(String text) {
    final mentionIndex = text.lastIndexOf('@');
    if (mentionIndex != -1) {
      final currentQuery = text.substring(mentionIndex + 1);
      _logic.searchUsers(currentQuery).then((results) {
        _searchStreamController.add(results);
      });
      setState(() {
        _searchQuery = currentQuery;
      });
    } else {
      setState(() {
        _searchQuery = '';
      });
      _searchStreamController.add([]);
    }
  }

  void _onHandleSelected(String handle) {
    final text = _controller.text;
    final mentionIndex = text.lastIndexOf('@');
    if (mentionIndex != -1) {
      final newText = '${text.substring(0, mentionIndex)}@$handle ';
      _controller.text = newText;
      _controller.selection =
          TextSelection.fromPosition(TextPosition(offset: newText.length));
    }
    _searchQuery = '';
    _searchStreamController.add([]);
  }

  Future<void> _sendMessage() async {
    final messageText = _controller.text.trim();
    if (messageText.isEmpty) return;

    setState(() {
      _controller.clear();
      _searchQuery = '';
      _searchStreamController.add([]);
    });

    try {
      await _logic.sendMessage(messageText);
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
    }
  }

  Widget _buildInputWidget(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        if (_searchQuery.isNotEmpty)
          StreamBuilder<List<String>>(
            stream: _searchStreamController.stream,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final handle = snapshot.data![index];
                      return ListTile(
                        onTap: () => _onHandleSelected(handle),
                        title: Text(
                          '@$handle',
                          style: GoogleFonts.inter(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        leading: Icon(
                          Icons.person,
                          color: theme.iconTheme.color?.withOpacity(0.7),
                        ),
                      );
                    },
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor ??
                (isDark ? Colors.grey[800] : Colors.grey[200]),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: "Ask CoSense...",
                    hintStyle: GoogleFonts.inter(
                      color: theme.hintColor,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              if (_isTyping)
                IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(
                    Icons.arrow_upward_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                )
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width > 600;
    final contentWidth = isDesktop ? 600.0 : double.infinity;

    return Scaffold(
      extendBodyBehindAppBar: true,
      endDrawer: AiDrawer(logic: _logic, screenContext: context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.home_rounded,
              size: 25,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              'CoSense',
              style: GoogleFonts.raleway(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF121212), const Color(0xFF1E1E1E)]
                : [const Color(0xFFF7F7F7), const Color(0xFFE0E0E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount:
                      _messages.length + (_messages.isEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_messages.isEmpty && index == 0) {
                          return const ChatBubble(
                            text: 'Hi! How can I help you today?',
                            isUser: false,
                          );
                        }
                        final message =
                        _messages[_messages.isEmpty ? 0 : index];
                        return ChatBubble(
                          text: message['text'],
                          isUser: message['isUser'],
                          isTyping: message['isTyping'] ?? false,
                        );
                      },
                    ),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: _buildInputWidget(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
