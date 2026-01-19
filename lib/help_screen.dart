import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  final String supportEmail = "infocopal8@gmail.com";
  final String landingPageUrl = 'https://bomehd.github.io/copal-landing/';

  // Function to launch URLs
  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception("Could not launch $urlString");
      }
    } catch (e) {
      _showSnackbar(context, "Failed to open link: $e");
    }
  }

  // Function to launch email client
  Future<void> _launchEmail(BuildContext context, String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Copal App Support Inquiry',
    );

    try {
      if (!await launchUrl(emailUri)) {
        throw Exception("Could not launch email client for $email");
      }
    } catch (e) {
      _showSnackbar(context, "Failed to launch email client: $e");
    }
  }

  // Helper function for showing snackbars
  void _showSnackbar(BuildContext context, String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: theme.colorScheme.onPrimary)),
        backgroundColor: theme.colorScheme.primary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurfaceColor = colorScheme.onSurface;
    final accentColor = colorScheme.primary;

    // Responsive logic
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final contentWidth =
    isDesktop ? (screenWidth >= 1200 ? 700.0 : screenWidth * 0.7) : screenWidth;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Help & Support",
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.brightness == Brightness.dark
                ? Colors.white
                : theme.primaryColor, // teal in light, white in dark
            fontSize: 13,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0.5,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: theme.brightness == Brightness.dark
                ? Colors.grey[800] // darker divider in dark mode
                : Colors.grey[300], // lighter divider in light mode
            height: 1.0,
          ),
        ),
      ),

      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SizedBox(
          width: contentWidth,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Information Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: accentColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Text(
                          "About CoPal",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: onSurfaceColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        "CoPal is designed to connect individuals through shared interests and passions. "
                            "Users can create detailed profiles, discover others with complementary skills or hobbies, "
                            "and foster meaningful connections for networking, collaboration, and community building.",
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.7,
                          color: onSurfaceColor.withOpacity(0.8),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: TextButton.icon(
                        onPressed: () => _launchUrl(context, landingPageUrl),
                        icon: const Icon(Icons.language, size: 20),
                        label: const Text("Visit Our Website"),
                        style: TextButton.styleFrom(
                          foregroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // Contact Us Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.support_agent,
                            color: accentColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Text(
                          "Contact Support",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: onSurfaceColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        "We're here to assist you. For any inquiries, feedback, or technical support, please contact us via email:",
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.7,
                          color: onSurfaceColor.withOpacity(0.8),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: InkWell(
                        onTap: () => _launchEmail(context, supportEmail),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.email,
                                color: accentColor,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                supportEmail,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Additional spacing at bottom
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
