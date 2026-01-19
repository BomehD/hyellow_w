import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyellow_w/app_options.dart'; // Assuming this contains your `countries` list

class PeopleAndPostsScreen extends StatefulWidget {
  const PeopleAndPostsScreen({Key? key}) : super(key: key);

  @override
  State<PeopleAndPostsScreen> createState() => _PeopleAndPostsScreenState();
}

class _PeopleAndPostsScreenState extends State<PeopleAndPostsScreen> {
  String sortBy = 'recent';
  Set<String> selectedPostCountries = {'United States'};
  Set<String> selectedUserCountries = {'United States'};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('post_sort_by', sortBy);
    await prefs.setStringList('post_country_filter', selectedPostCountries.toList());
    await prefs.setStringList('user_country_filter', selectedUserCountries.toList());
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final storedSortBy = prefs.getString('post_sort_by') ?? 'recent';
    final List<String> postCountries = prefs.getStringList('post_country_filter') ?? [];
    final List<String> userCountries = prefs.getStringList('user_country_filter') ?? [];

    setState(() {
      sortBy = storedSortBy;
      selectedPostCountries = postCountries.toSet();
      selectedUserCountries = userCountries.toSet();
    });
  }

  void _showMultiSelectDialog({
    required String title,
    required List<String> selectedList,
    required void Function(List<String>) onSelected,
  }) {
    List<String> tempSelected = List.from(selectedList);

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                height: 400,
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: countries.length,
                  itemBuilder: (context, index) {
                    final country = countries[index];
                    return CheckboxListTile(
                      title: Text(country),
                      value: tempSelected.contains(country),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            tempSelected.add(country);
                          } else {
                            tempSelected.remove(country);
                          }
                        });
                      },
                      activeColor: theme.colorScheme.primary,
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7)),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                onSelected(tempSelected);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text("Apply Filters"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCountrySelector({
    required String label,
    required Set<String> selected,
    required Function(Set<String>) onChanged,
    required String dialogTitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[200] : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showMultiSelectDialog(
            title: dialogTitle,
            selectedList: selected.toList(),
            onSelected: (value) => onChanged(value.toSet()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1.5),
              borderRadius: BorderRadius.zero, // Sharp edges here
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selected.isEmpty ? "Select countries" : selected.join(', '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: selected.isEmpty
                          ? (isDark ? Colors.grey[400] : Colors.grey)
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.grey[300] : Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Discovery Controls",
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

      body: Container(
        child: Center(
          child: SizedBox(
            width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sort Posts By:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[200] : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1.5),
                      borderRadius: BorderRadius.zero,
                      color: theme.cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: sortBy,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: isDark ? Colors.grey[300] : Colors.grey),
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'recent', child: Text("Most Recent")),
                          DropdownMenuItem(value: 'popular', child: Text("Most Popular")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => sortBy = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildCountrySelector(
                    label: "Filter Posts by Country:",
                    selected: selectedPostCountries,
                    dialogTitle: "Select Countries for Posts",
                    onChanged: (set) => setState(() => selectedPostCountries = set),
                  ),
                  const SizedBox(height: 25),
                  _buildCountrySelector(
                    label: "Filter Users by Country:",
                    selected: selectedUserCountries,
                    dialogTitle: "Select Countries for Users",
                    onChanged: (set) => setState(() => selectedUserCountries = set),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _savePreferences();
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        elevation: 3,
                      ),
                      child: const Text(
                        "Save Filters",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
