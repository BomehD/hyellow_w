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
// 1. ADD THIS GLOBAL KEY FOR NAVIGATION
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📩 Background message received: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint("✅ Firestore persistence enabled successfully.");
  } catch (e) {
    debugPrint("⚠️ Error enabling Firestore persistence: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('themeMode') ?? 'system';

  ThemeMode initialThemeMode = savedTheme == 'dark'
      ? ThemeMode.dark
      : (savedTheme == 'light' ? ThemeMode.light : ThemeMode.system);

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

    // 2. WAIT FOR FIRST FRAME BEFORE INIT NOTIFICATIONS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPushNotifications();
    });
  }

  Future<void> _initPushNotifications() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    _getAndSaveToken();
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground message: ${message.notification?.title}');
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

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage);
    }
  }

  // 3. UPDATED NAVIGATION USING navigatorKey
  void _handleNotificationNavigation(RemoteMessage message) {
    final String? type = message.data['type'];
    final String? id = message.data['id'] ?? message.data['postId'];

    if (id != null) {
      if (type == 'comment' || type == 'like') {
        navigatorKey.currentState?.pushNamed('/posts/$id');
      } else if (type == 'follow') {
        navigatorKey.currentState?.pushNamed('/profile/$id');
      }
    }
  }

  Future<void> _getAndSaveToken() async {
    String? token = await _messaging.getToken();
    if (token != null) _saveTokenToFirestore(token);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint('✅ FCM token synced to Firestore');
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system'));
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF106C70);

    ThemeData buildTheme(Brightness brightness) {
      bool isDark = brightness == Brightness.dark;
      return ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(seedColor: accentColor, brightness: brightness),
        scaffoldBackgroundColor: isDark ? Colors.black : Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: accentColor),
      );
    }

    return MaterialApp(
      // 4. PLUG IN THE NAVIGATOR KEY HERE
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: snackbarKey,
      title: 'CoPal',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _themeMode,
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        final isLoggedIn = FirebaseAuth.instance.currentUser != null;

        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'posts') {
          return MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: uri.pathSegments[1]),
            settings: settings,
          );
        }

        if (uri.path == '/login') {
          return MaterialPageRoute(builder: (_) => LoginScreen(redirectTo: uri.queryParameters['redirectTo']), settings: settings);
        }

        return MaterialPageRoute(
          builder: (_) => isLoggedIn
              ? HomeScreen(onThemeChanged: _setThemeMode, currentThemeMode: _themeMode)
              : const LoginScreen(),
          settings: settings,
        );
      },
    );
  }
}