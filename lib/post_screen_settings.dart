import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';

class PostScreenSettings extends StatefulWidget {
  const PostScreenSettings({Key? key}) : super(key: key);

  @override
  _PostScreenSettingsState createState() => _PostScreenSettingsState();
}

class _PostScreenSettingsState extends State<PostScreenSettings> {
  final currentUser = FirebaseAuth.instance.currentUser;
  bool isLoading = true;

  List<String> mutedUserIds = [];
  List<String> blockedUserIds = [];
  List<String> hiddenPostIds = [];

  Map<String, Map<String, dynamic>> mutedUsersData = {};
  Map<String, Map<String, dynamic>> blockedUsersData = {};
  Map<String, Map<String, dynamic>> hiddenPostsData = {};

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _fetchContentLists();
    } else {
      isLoading = false;
    }
  }

  Future<void> _fetchContentLists() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        _fetchMutedUsers(),
        _fetchBlockedUsers(),
        _fetchHiddenPosts(),
      ]);
    } catch (e) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Failed to fetch your settings.')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchMutedUsers() async {
    final user = currentUser;
    if (user == null || !mounted) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('mutedUsers')
          .get();

      mutedUserIds = snapshot.docs.map((doc) => doc.id).toList();

      if (mutedUserIds.isNotEmpty) {
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: mutedUserIds)
            .get();

        final profilesSnapshot = await FirebaseFirestore.instance
            .collection('profiles')
            .where(FieldPath.documentId, whereIn: mutedUserIds)
            .get();

        final Map<String, Map<String, dynamic>> data = {};
        for (var doc in usersSnapshot.docs) {
          data[doc.id] = doc.data();
        }

        for (var doc in profilesSnapshot.docs) {
          data[doc.id]?['profileImage'] = doc['profileImage'];
        }

        mutedUsersData = data;
      }
    } catch (e) {
      print("Error fetching muted users: $e");
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchBlockedUsers() async {
    final user = currentUser;
    if (user == null || !mounted) return;

    try {
      final blockDoc = await FirebaseFirestore.instance
          .collection('Blocks')
          .doc(user.uid)
          .get();

      if (blockDoc.exists) {
        final blockData = blockDoc.data();
        blockedUserIds = List<String>.from(blockData?['blocked'] ?? []);

        if (blockedUserIds.isNotEmpty) {
          final usersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: blockedUserIds)
              .get();

          final profilesSnapshot = await FirebaseFirestore.instance
              .collection('profiles')
              .where(FieldPath.documentId, whereIn: blockedUserIds)
              .get();

          final Map<String, Map<String, dynamic>> data = {};
          for (var doc in usersSnapshot.docs) {
            data[doc.id] = doc.data();
          }

          for (var doc in profilesSnapshot.docs) {
            data[doc.id]?['profileImage'] = doc['profileImage'];
          }

          blockedUsersData = data;
        } else {
          blockedUsersData = {};
        }
      } else {
        blockedUserIds = [];
        blockedUsersData = {};
      }
    } catch (e) {
      print("Error fetching blocked users: $e");
    }

    if (mounted) setState(() {});
  }

  Future<void> _fetchHiddenPosts() async {
    final user = currentUser;
    if (user == null || !mounted) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('hiddenPosts')
          .get();

      hiddenPostIds = snapshot.docs.map((doc) => doc.id).toList();

      if (hiddenPostIds.isNotEmpty) {
        final postsSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where(FieldPath.documentId, whereIn: hiddenPostIds)
            .get();

        final Map<String, Map<String, dynamic>> data = {};
        for (var doc in postsSnapshot.docs) {
          data[doc.id] = doc.data();
        }
        hiddenPostsData = data;
      }
    } catch (e) {
      print("Error fetching hidden posts: $e");
    }
    if (mounted) setState(() {});
  }

  Future<void> _unmuteUser(String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('mutedUsers')
        .doc(userId)
        .delete();

    snackbarKey.currentState?.showSnackBar(
      const SnackBar(content: Text('User unmuted.')),
    );
    _fetchMutedUsers();
  }

  Future<void> _unblockUser(String userId) async {
    final blocksRef = FirebaseFirestore.instance
        .collection('Blocks')
        .doc(currentUser!.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(blocksRef);

      if (snapshot.exists) {
        final blockedList = List<String>.from(snapshot.data()?['blocked'] ?? []);
        blockedList.remove(userId);

        transaction.update(blocksRef, {'blocked': blockedList});
      }
    });

    snackbarKey.currentState?.showSnackBar(
      const SnackBar(content: Text('User unblocked.')),
    );

    _fetchBlockedUsers();
  }

  Future<void> _unhidePost(String postId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('hiddenPosts')
        .doc(postId)
        .delete();

    snackbarKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Post unhidden.')),
    );
    _fetchHiddenPosts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to manage your settings.")),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.surface, // adapts with dark mode automatically

          title: Text(
            'Post Screen Settings',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white // white in dark mode
                  : colors.primary, // teal (primary) in light mode
            ),
          ),
          elevation: 0.5,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48.0),
            child: Column(
              children: [
                Divider(
                  height: 1,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800] // darker divider in dark
                      : colors.outlineVariant, // default in light
                ),
                TabBar(
                  labelColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white // white labels in dark
                      : colors.primary, // teal labels in light
                  unselectedLabelColor: colors.onSurfaceVariant,
                  indicatorColor: colors.primary,
                  tabs: const [
                    Tab(text: 'Muted Users'),
                    Tab(text: 'Blocked'),
                    Tab(text: 'Hidden Posts'),
                  ],
                ),
              ],
            ),
          ),
        ),

        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            _buildUserList(mutedUserIds, mutedUsersData, _unmuteUser),
            _buildUserList(blockedUserIds, blockedUsersData, _unblockUser),
            _buildPostList(hiddenPostIds, hiddenPostsData, _unhidePost),
          ],
        ),
        backgroundColor: colors.background, // adapts with dark mode
      ),
    );
  }

  Widget _buildUserList(
      List<String> userIds,
      Map<String, Map<String, dynamic>> userData,
      Function(String) onAction,
      ) {
    final colors = Theme.of(context).colorScheme;

    if (userIds.isEmpty) {
      return const Center(child: Text("No users in this list."));
    }

    return ListView.builder(
      itemCount: userIds.length,
      itemBuilder: (context, index) {
        final userId = userIds[index];
        final user = userData[userId];
        final userName = user?['name'] ?? 'Unknown User';
        final profileImage = user?['profileImage'];

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
            child: profileImage == null
                ? Icon(Icons.person, color: colors.onPrimary)
                : null,
            backgroundColor: colors.primary,
          ),
          title: Text(userName, style: TextStyle(color: colors.onSurface)),
          trailing: TextButton(
            onPressed: () => onAction(userId),
            child: Text(
              onAction == _unmuteUser ? 'Unmute' : 'Unblock',
              style: TextStyle(color: colors.error),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostList(
      List<String> postIds,
      Map<String, Map<String, dynamic>> postData,
      Function(String) onAction,
      ) {
    final colors = Theme.of(context).colorScheme;

    if (postIds.isEmpty) {
      return const Center(child: Text("No posts in this list."));
    }

    return ListView.builder(
      itemCount: postIds.length,
      itemBuilder: (context, index) {
        final postId = postIds[index];
        final post = postData[postId];
        final postContent = post?['content'] ?? 'No content available.';

        return ListTile(
          title: Text(
            postContent,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurface),
          ),
          trailing: TextButton(
            onPressed: () => onAction(postId),
            child: Text('Unhide', style: TextStyle(color: colors.error)),
          ),
        );
      },
    );
  }
}
