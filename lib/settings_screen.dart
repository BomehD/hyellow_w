import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hyellow_w/people_and_posts_screen.dart';
import 'package:hyellow_w/personalize_home_screen.dart';
import 'package:hyellow_w/theme_preference_screen.dart';
import 'package:hyellow_w/user_join_tracker_screen.dart';
import 'package:hyellow_w/manage_account_screen.dart';
import 'package:hyellow_w/help_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hyellow_w/post_screen_settings.dart';
import 'ai_assistant/regulatory_page.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsScreen({
    Key? key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final String privacyPolicyUrl = "https://bomehd.github.io/privacy-policy/";
  late ThemeMode _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentThemeMode;
  }

  void _launchPrivacyPolicy() async {
    final Uri url = Uri.parse(privacyPolicyUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $privacyPolicyUrl");
    }
  }

  void _navigateToThemePreferences() async {
    // Navigate to the enhanced theme screen with callback
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ThemePreferenceScreen(
          currentTheme: _selectedTheme,
          onThemeChanged: (ThemeMode newTheme) {
            // Handle theme change immediately
            if (newTheme != _selectedTheme) {
              setState(() {
                _selectedTheme = newTheme;
              });
              // Notify the app to update the theme globally
              widget.onThemeChanged(newTheme);
            }
          },
        ),
      ),
    );
  }

  String _getThemeDisplayName(ThemeMode theme) {
    switch (theme) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF106C70),
            fontSize: 13,
          ),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Manage Account', style: TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageAccountScreen()),
              );
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help', style: TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) =>  HelpScreen()),
              );
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy', style: TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: _launchPrivacyPolicy,
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Personalize', style: TextStyle(fontSize: 16)),
            subtitle: const Text('Customize your home screen',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) =>  PersonalizeHomeScreen()),
              );

              if (changed == true) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.filter_alt_outlined),
            title: const Text('Discovery Controls', style: TextStyle(fontSize: 16)),
            subtitle: const Text('Filter by country, trending, etc.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PeopleAndPostsScreen()),
              );
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.hide_source_outlined),
            title: const Text('Post Screen Settings', style: TextStyle(fontSize: 16)),
            subtitle: const Text('Muted Content Control',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostScreenSettings()),
              );
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('AI Data and Privacy', style: TextStyle(fontSize: 16)),
            subtitle: const Text(
              'Manage your data consent for the AI assistant',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const RegulatoryPage()),
              );
            },
          ),
          const Divider(height: 1),

          // Theme Selector - Updated to work with enhanced theme screen
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme', style: TextStyle(fontSize: 16)),
            subtitle: Text(
              _getThemeDisplayName(_selectedTheme),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _navigateToThemePreferences,
          ),
          const Divider(height: 1),

          if (currentUser?.uid == 'AQrqqjBKreRSwYv623qvBHtvGQe2')
            Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings,
                      color: Colors.deepPurple),
                  title: const Text('User Join Tracker',
                      style: TextStyle(fontSize: 16)),
                  subtitle: const Text('Developer Feature',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UserJoinTrackerScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
              ],
            ),
        ],
      ),
    );
  }
}