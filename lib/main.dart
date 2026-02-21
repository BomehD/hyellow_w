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
import 'package:firebase_messaging/firebase_messaging.dart';

final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();

/// 🔹 Background FCM handler - Must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📩 Background message received: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore persistence
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint("✅ Firestore persistence enabled successfully.");
  } catch (e) {
    debugPrint("⚠️ Error enabling Firestore persistence: $e");
  }

  // Load saved theme mode
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

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;

    // 🔹 Initialize Push Notification Logic
    _initPushNotifications();
  }

  Future<void> _initPushNotifications() async {
    // 1. Request permissions (Crucial for iOS/Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // 2. Get and save the initial FCM token
    _getAndSaveToken();

    // 3. Listen for token refreshes while the app is running
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // 4. Handle Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground message: ${message.notification?.title}');

      // Show a snackbar since the system notification won't pop up while the app is open
      if (message.notification != null) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(
            content: Text("${message.notification!.title}: ${message.notification!.body}"),
            action: SnackBarAction(
              label: "View",
              onPressed: () => _handleNotificationNavigation(message),
            ),
          ),
        );
      }
    });

    // 5. Handle notification taps (When app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

    // 6. Handle notification taps (When app was completely terminated)
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage);
    }
  }

  // 🔹 Centralized Navigation Logic based on notification data
  void _handleNotificationNavigation(RemoteMessage message) {
    final String? type = message.data['type'];
    final String? id = message.data['id'] ?? message.data['postId'];

    if (type == 'comment' || type == 'like') {
      Navigator.pushNamed(context, '/posts/$id');
    } else if (type == 'follow') {
      // Assuming you have a user profile route or similar
      Navigator.pushNamed(context, '/profile/$id');
    }
  }

  Future<void> _getAndSaveToken() async {
    String? token = await _messaging.getToken();
    if (token != null) {
      _saveTokenToFirestore(token);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Use merge:true so we don't overwrite existing user data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint('✅ FCM token synced to Firestore');
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String modeString = mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system';
    await prefs.setString('themeMode', modeString);

    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF106C70);

    // Reusable theme data function to avoid duplication
    ThemeData buildTheme(Brightness brightness) {
      bool isDark = brightness == Brightness.dark;
      return ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: brightness,
        ),
        scaffoldBackgroundColor: isDark ? Colors.black : Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: accentColor,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: isDark ? Colors.black : Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: accentColor,
          unselectedItemColor: Colors.grey,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: isDark ? Colors.tealAccent : accentColor,
          selectionColor: (isDark ? Colors.tealAccent : accentColor).withOpacity(0.3),
          selectionHandleColor: isDark ? Colors.tealAccent : accentColor,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: isDark ? Colors.tealAccent : accentColor,
        ),
      );
    }

    return MaterialApp(
      scaffoldMessengerKey: snackbarKey,
      title: 'CoPal',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _themeMode,
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        final isLoggedIn = FirebaseAuth.instance.currentUser != null;

        // Handle Dynamic Routes for Notifications (e.g., /posts/123)
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
              : const LoginScreen(),
          settings: settings,
        );
      },
    );
  }
}