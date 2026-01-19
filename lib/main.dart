import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'post_detail_screen.dart';

final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint("✅ Firestore persistence enabled successfully.");
  } catch (e) {
    debugPrint("⚠️ Error enabling Firestore persistence: $e");
  }

  // Load saved theme mode (default: system)
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('themeMode') ?? 'system';

  ThemeMode initialThemeMode;
  switch (savedTheme) {
    case 'dark':
      initialThemeMode = ThemeMode.dark;
      break;
    case 'light':
      initialThemeMode = ThemeMode.light;
      break;
    default:
      initialThemeMode = ThemeMode.system;
  }

  runApp(MyApp(initialThemeMode: initialThemeMode));
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  const MyApp({super.key, required this.initialThemeMode});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String modeString = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.light
        ? 'light'
        : 'system';
    await prefs.setString('themeMode', modeString);

    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF106C70);

    return MaterialApp(
      scaffoldMessengerKey: snackbarKey,
      title: 'CoPal',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Transparent action bar
          elevation: 0, // Remove shadow
          foregroundColor: accentColor, // Icons & text
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: accentColor,
          unselectedItemColor: Colors.grey,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: accentColor,
          selectionColor: accentColor.withOpacity(0.3),
          selectionHandleColor: accentColor,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: accentColor,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: accentColor,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: accentColor,
          unselectedItemColor: Colors.grey,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.tealAccent,
          selectionColor: Colors.tealAccent.withOpacity(0.3),
          selectionHandleColor: Colors.tealAccent,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.tealAccent,
        ),
      ),
      themeMode: _themeMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        final isLoggedIn = FirebaseAuth.instance.currentUser != null;

        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'posts') {
          final postId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: postId),
            settings: settings,
          );
        }

        if (uri.path == '/login') {
          final redirectTo = uri.queryParameters['redirectTo'];
          return MaterialPageRoute(
            builder: (_) => LoginScreen(redirectTo: redirectTo),
            settings: settings,
          );
        }

        if (!isLoggedIn && uri.path != '/') {
          return MaterialPageRoute(
            builder: (_) => LoginScreen(redirectTo: uri.toString()),
            settings: settings,
          );
        }

        return MaterialPageRoute(
          builder: (_) => isLoggedIn
              ? HomeScreen(
            onThemeChanged: _setThemeMode,
            currentThemeMode: _themeMode,
          )
              : LoginScreen(),
          settings: settings,
        );
      },
    );
  }


}

class CorrectedAuthCheck extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;

  const CorrectedAuthCheck({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  _CorrectedAuthCheckState createState() => _CorrectedAuthCheckState();
}

class _CorrectedAuthCheckState extends State<CorrectedAuthCheck> with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = _auth.currentUser;
    if (user == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _updateLastSeen(user.uid);
    } else if (state == AppLifecycleState.resumed) {
      _updateLastSeen(user.uid);
    }
  }

  Future<void> _updateLastSeen(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'last_seen': FieldValue.serverTimestamp(),
      });
      debugPrint("Updated last_seen for $uid on app lifecycle change.");
    } catch (e) {
      debugPrint("Error updating last_seen: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error checking authentication: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        } else {
          final User? user = snapshot.data;
          if (user != null) {
            _updateLastSeen(user.uid);
            return HomeScreen(
              onThemeChanged: widget.onThemeChanged,
              currentThemeMode: widget.currentThemeMode,
            );
          } else {
            return LoginScreen();
          }
        }
      },
    );
  }
}
