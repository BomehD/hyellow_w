import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'ai_assistant_logic.dart';

class AiDrawer extends StatefulWidget {
  final AiAssistantLogic logic;
  final BuildContext screenContext;

  const AiDrawer({super.key, required this.logic, required this.screenContext});

  @override
  State<AiDrawer> createState() => _AiDrawerState();
}

class _AiDrawerState extends State<AiDrawer> {
  late Future<List<Map<String, dynamic>>> _recentChatsFuture;

  @override
  void initState() {
    super.initState();
    _recentChatsFuture = widget.logic.fetchRecentChats();
  }

  void _confirmAndDeleteChat(String chatId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: const Text('Are you sure you want to delete this chat? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.logic.deleteChat(chatId);
      setState(() {
        _recentChatsFuture = widget.logic.fetchRecentChats();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth > 600 ? 400.0 : screenWidth * 0.75;

    return Drawer(
      width: drawerWidth,
      backgroundColor: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Chats',
                    style: GoogleFonts.raleway(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () {
                      widget.logic.startNewChat();
                      Navigator.pop(widget.screenContext);
                    },
                  ),
                ],
              ),
            ),
            Divider(color: isDark ? Colors.white24 : Colors.black12),

            // Recent Chats
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _recentChatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.red[200] : Colors.red,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'No recent chats',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    );
                  }

                  final recentChats = snapshot.data!;
                  return ListView.builder(
                    itemCount: recentChats.length,
                    itemBuilder: (context, index) {
                      final chat = recentChats[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.only(left: 16.0, right: 8.0),
                        title: Text(
                          chat['title'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          chat['lastMessage'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: isDark ? Colors.white54 : Colors.black38,
                          ),
                          onPressed: () => _confirmAndDeleteChat(chat['chatId']),
                          iconSize: 18.0,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                        ),
                        onTap: () {
                          widget.logic.loadChat(chat['chatId']);
                          Navigator.pop(widget.screenContext);
                        },
                      );
                    },
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
