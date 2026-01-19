import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hyellow_w/profile_page.dart';
import 'package:hyellow_w/profile_view.dart';
import 'package:hyellow_w/home_view1.dart';
import 'package:hyellow_w/home_view2.dart';
import 'package:hyellow_w/home_view3.dart';
import 'package:hyellow_w/login_screen.dart';
import 'package:hyellow_w/post_screen.dart';
import 'package:hyellow_w/settings_screen.dart';
import 'package:hyellow_w/notification_screen.dart';
import 'package:hyellow_w/live_search_screen.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'ai_assistant/ai_assistant_screen.dart';
import 'home_view_preference.dart';
import 'messaging/chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoPal',
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.teal),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
      ),
      themeMode: _themeMode,
      home: HomeScreen(
        currentThemeMode: _themeMode,
        onThemeChanged: (ThemeMode newMode) {
          setState(() {
            _themeMode = newMode;
          });
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;

  const HomeScreen({
    Key? key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _homeViewType = 1;
  late PageController _pageController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _loadHomeViewPreference();

    Future.delayed(Duration.zero, () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data()?['welcomeShown'] == false) {
          _showWelcomeDialog();
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'welcomeShown': true});
        }
      }
    });
  }

  void _loadHomeViewPreference() async {
    final selected = await HomeViewPreferenceFirestore.getSelectedView();
    setState(() {
      _homeViewType = [1, 2, 3].contains(selected) ? selected : 1;
      _selectedIndex = 0;
      _isLoading = false;
    });
  }

  List<Widget> _buildWidgetOptions(int viewIndex) {
    Widget homeView;
    switch (viewIndex) {
      case 1: homeView = HomeView1(); break;
      case 2: homeView = HomeView2(); break;
      case 3:
      default: homeView = HomeView3(); break;
    }
    return [homeView, ChatScreen(), PostScreen()];
  }

  void _onItemTapped(int index) {
    if (index >= 0 && index < 3) {
      setState(() => _selectedIndex = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  void _showWelcomeDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: theme.copyWith(
            dialogTheme: theme.dialogTheme.copyWith(
              backgroundColor: theme.brightness == Brightness.dark
                  ? Colors.grey[850] // Dark mode background
                  : Colors.white70,   // Light mode background
            ),
          ),
          child: AlertDialog(
            title: const Text('Welcome to CoPal!'),
            content: const Text(
              'We\'re glad you\'re here.\n\n'
                  'Please interact thoughtfully.\nStay alert, and protect your personal information.\n'
                  'Always use good judgment and steer clear of suspicious activity.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Got it',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _openUserProfile(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
      final data = userDoc.data() ?? {};
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileView(
            name: data['name'] ?? '',
            interest: data['interest'] ?? '',
            about: data['about'] ?? '',
            title: data['title'] ?? '',
            phone: data['phone'] ?? '',
            email: data['email'] ?? '',
            profileImage: data['profileImage'] ?? 'assets/default_profile_image.png',
          ),
        ),
      );
    }
  }

  Future<void> _onMenuSelected(String value, BuildContext context) async {
    switch (value) {
      case 'Option 1':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SettingsScreen(
              currentThemeMode: widget.currentThemeMode,
              onThemeChanged: widget.onThemeChanged,
            ),
          ),
        );


        break;
      case 'Option 2':
        Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationScreen()));
        break;
      case 'Log out':
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
        break;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'CoPal',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.search, size: 28.0, color: theme.iconTheme.color),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LiveSearchScreen())),
                ),
                IconButton(
                  icon: Icon(Icons.person, size: 24.0, color: theme.iconTheme.color),
                  onPressed: () => _openUserProfile(context),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: theme.iconTheme.color),
                  onSelected: (value) => _onMenuSelected(value, context),
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(value: 'Option 1', child: Text('Settings')),
                    PopupMenuItem<String>(value: 'Option 2', child: Text('Notifications')),
                    PopupMenuItem<String>(value: 'Log out', child: Text('Log out')),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _selectedIndex == 0
          ? Padding(
        padding: const EdgeInsets.only(bottom: 200.0),
        child: SpeedDial(
          icon: Icons.grid_view_rounded,
          activeIcon: Icons.close,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.7),
          foregroundColor: Colors.white,
          elevation: 8,
          children: [
            SpeedDialChild(
              child: const Icon(Icons.auto_awesome, color: Colors.white),
              backgroundColor: theme.colorScheme.primary,
              label: 'CoSense',
              labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              labelBackgroundColor: theme.colorScheme.primary,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AiAssistantScreen())),
            ),
          ],
        ),
      )
          : null,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _buildWidgetOptions(_homeViewType),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.message_outlined), label: 'Messages'),
              BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined), label: 'Posts'),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: theme.colorScheme.onSurface,
            unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.5),
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}
