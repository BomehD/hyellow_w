import 'package:flutter/material.dart';
import 'home_view_preference.dart'; // Assuming this provides HomeViewPreferenceFirestore

class PersonalizeHomeScreen extends StatefulWidget {
  @override
  _PersonalizeHomeScreenState createState() => _PersonalizeHomeScreenState();
}

class _PersonalizeHomeScreenState extends State<PersonalizeHomeScreen> {
  int _selectedIndex = 1; // Default or initial selected view

  @override
  void initState() {
    super.initState();
    _loadSelectedView();
  }

  // Asynchronous function to load the selected view preference
  void _loadSelectedView() async {
    final index = await HomeViewPreferenceFirestore.getSelectedView();
    setState(() {
      _selectedIndex = index;
    });
  }

  // Callback for when a radio tile's value changes
  void _onChanged(int? value) async {
    if (value != null && value != _selectedIndex) {
      setState(() {
        _selectedIndex = value;
      });

      await HomeViewPreferenceFirestore.setSelectedView(value);

      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  // New helper method for responsive layout
  double _getContentWidth(double screenWidth) {
    if (screenWidth >= 1200) {
      return 600;
    } else if (screenWidth >= 800) {
      return screenWidth * 0.65;
    } else {
      return screenWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = colorScheme.primary;
    final onSurfaceColor = colorScheme.onSurface;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Choose Home View",
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

      body: Container(
        color: theme.colorScheme.surface, // Surface adapts to light/dark
        child: Center(
          child: SizedBox(
            width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      "Select your preferred home layout.",
                      style: TextStyle(
                        fontSize: 15,
                        color: onSurfaceColor.withOpacity(0.7),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _buildOptionTile(
                    icon: Icons.view_list_rounded,
                    title: "Default List View",
                    description: "Displays interests as a vertical list.",
                    value: 1,
                    accentColor: accentColor,
                    onSurfaceColor: onSurfaceColor,
                  ),
                  const SizedBox(height: 16),
                  _buildOptionTile(
                    icon: Icons.grid_view_rounded,
                    title: "Interest Card View",
                    description: "Presents each interest as a distinct card.",
                    value: 2,
                    accentColor: accentColor,
                    onSurfaceColor: onSurfaceColor,
                  ),
                  const SizedBox(height: 16),
                  _buildOptionTile(
                    icon: Icons.dashboard_rounded,
                    title: "Interest Grid View",
                    description: "Arranges interests in a compact grid format.",
                    value: 3,
                    accentColor: accentColor,
                    onSurfaceColor: onSurfaceColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String description,
    required int value,
    required Color accentColor,
    required Color onSurfaceColor,
  }) {
    bool isSelected = _selectedIndex == value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected ? accentColor.withOpacity(0.08) : Theme.of(context).cardColor,
        border: Border.all(
          color: isSelected ? accentColor : Theme.of(context).dividerColor,
          width: isSelected ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: RadioListTile<int>(
        value: value,
        groupValue: _selectedIndex,
        onChanged: _onChanged,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: isSelected ? accentColor : onSurfaceColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? accentColor.withOpacity(0.8) : onSurfaceColor.withOpacity(0.6),
            ),
          ),
        ),
        secondary: Icon(
          icon,
          color: isSelected ? accentColor : onSurfaceColor.withOpacity(0.6),
          size: 28,
        ),
        activeColor: accentColor,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
