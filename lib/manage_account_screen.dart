import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hyellow_w/app_options.dart'; // Assuming this contains `availableInterests` and `countries`
import 'registration_form.dart'; // Assuming this is your registration form

class ManageAccountScreen extends StatefulWidget {
  const ManageAccountScreen({Key? key}) : super(key: key);

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedCountry;
  final List<String> _interests = availableInterests;
  String? _selectedInterest;
  bool _isLoading = true;
  bool _isSaving = false;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data != null) {
        _nameController.text = data['name'] ?? '';

        final interestData = data['interest'];
        if (interestData is List && interestData.isNotEmpty) {
          _selectedInterest = interestData.first.toString();
        } else if (interestData is String) {
          _selectedInterest = interestData;
        }

        final countryData = data['country'];
        if (countryData is List && countryData.isNotEmpty) {
          _selectedCountry = countryData.first.toString();
        } else if (countryData is String) {
          _selectedCountry = countryData;
        }

        if (_selectedInterest != null && !_interests.contains(_selectedInterest)) {
          _selectedInterest = null;
        }
        if (_selectedCountry != null && !countries.contains(_selectedCountry)) {
          _selectedCountry = null;
        }
      }
    } catch (e) {
      _showSnack("Error loading data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Manage Account",
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

      body: Center(
        child: SizedBox(
          width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
          child: _isLoading ? _buildLoadingView(theme) : _buildFormContent(context, theme),
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }

  Widget _buildLoadingView(ThemeData theme) {
    return Center(
      child: CircularProgressIndicator(color: theme.primaryColor),
    );
  }

  Widget _buildFormContent(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, "Personal Details"),
            const SizedBox(height: 20),
            _buildTextField(_nameController, "Full Name", Icons.person_outline, theme),
            const SizedBox(height: 16),
            _buildCountryDropdown(theme),
            const SizedBox(height: 16),
            _buildInterestDropdown(theme),
            const SizedBox(height: 32),
            _buildSaveButton(theme),
            const SizedBox(height: 40),
            Divider(height: 1, color: Colors.grey[300]),
            const SizedBox(height: 20),
            _sectionTitle(context, "Account Management"),
            const SizedBox(height: 16),
            _buildDeleteTile(theme),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          isDense: true,
        ),
        validator: (value) => value == null || value.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildInterestDropdown(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: _selectedInterest,
        items: _interests.map((e) {
          return DropdownMenuItem<String>(
            value: e,
            child: Text(
              e,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[800]),
            ),
          );
        }).toList(),
        onChanged: (val) => setState(() => _selectedInterest = val),
        decoration: InputDecoration(
          labelText: "Interest",
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.category_outlined, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          isDense: true,
        ),
        validator: (value) => value == null ? "Please select an interest" : null,
      ),
    );
  }

  Widget _buildCountryDropdown(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: _selectedCountry,
        items: countries.map((name) {
          return DropdownMenuItem<String>(
            value: name,
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[800]),
            ),
          );
        }).toList(),
        onChanged: (val) => setState(() => _selectedCountry = val),
        decoration: InputDecoration(
          labelText: "Country",
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          isDense: true,
        ),
        validator: (value) => value == null ? "Please select a country" : null,
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveChanges,
        icon: _isSaving
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        )
            : const Icon(Icons.check_circle_outline),
        label: Text(_isSaving ? "Saving..." : "Save Changes"),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 2,
          textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDeleteTile(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error, size: 28),
        title: Text(
          "Delete Account",
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          "This action is irreversible and will delete all your data.",
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[500], size: 18),
        onTap: _handleDeleteFlow,
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final newName = _nameController.text.trim();
    final newCountry = _selectedCountry;
    final newInterest = _selectedInterest;

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: user!.uid)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.update(userDoc, {
        'name': newName,
        'country': newCountry,
        'interest': newInterest,
      });

      for (var doc in postsQuery.docs) {
        batch.update(doc.reference, {
          'country': newCountry,
        });
      }

      await batch.commit();

      _showSnack("Profile and posts updated successfully!");
    } catch (e) {
      _showSnack("Failed to update profile: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDeleteFlow() async {
    bool confirm = await _showConfirmDialog();
    if (!confirm) return;

    String? password = await _promptPassword();
    if (password == null || password.isEmpty) {
      _showSnack("Password is required to delete account.");
      return;
    }

    await _deleteAccount(password);
  }

  Future<void> _deleteAccount(String password) async {
    try {
      _showSnack("Deleting account...");

      final providers = user!.providerData.map((p) => p.providerId).toList();

      if (providers.contains('password')) {
        final cred = EmailAuthProvider.credential(
          email: user!.email!,
          password: password,
        );
        await user!.reauthenticateWithCredential(cred);
      } else if (providers.contains('google.com')) {
        final googleUser = await GoogleSignIn().signIn();
        final googleAuth = await googleUser?.authentication;

        if (googleAuth == null) {
          _showSnack("Google reauthentication failed.");
          return;
        }

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await user!.reauthenticateWithCredential(credential);
      } else {
        _showSnack("Unsupported authentication provider.");
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();
      await FirebaseFirestore.instance.collection('profiles').doc(user!.uid).delete();
      await FirebaseFirestore.instance.collection('Friends').doc(user!.uid).delete();

      final posts = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: user!.uid)
          .get();

      for (var post in posts.docs) {
        final mediaUrl = post['mediaUrl'];
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
          } catch (e) {
            debugPrint("Error deleting post media: $e");
          }
        }
        await post.reference.delete();
      }

      final comments = await FirebaseFirestore.instance
          .collection('comments')
          .where('userId', isEqualTo: user!.uid)
          .get();

      for (var comment in comments.docs) {
        await comment.reference.delete();
      }

      try {
        final profileImages =
        await FirebaseStorage.instance.ref("profile_images/${user!.uid}").listAll();
        for (var item in profileImages.items) {
          await item.delete();
        }
      } catch (e) {
        debugPrint("Error deleting profile images: $e");
      }

      await user!.delete();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => RegistrationForm()),
              (_) => false,
        );
      }

      _showSnack("Account deleted successfully!");
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'wrong-password') {
        message = 'Incorrect password. Please try again.';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please reauthenticate and try again.';
      } else {
        message = 'Deletion failed: ${e.message}';
      }
      _showSnack(message);
    } catch (e) {
      _showSnack("An unexpected error occurred: $e");
    }
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog() async {
    final theme = Theme.of(context);
    return await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text("Confirm Deletion", style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text(
          "Are you sure you want to permanently delete your account? This action cannot be undone.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: theme.primaryColor,
              textStyle: const TextStyle(fontWeight: FontWeight.w500),
            ),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              elevation: 2,
              textStyle: const TextStyle(fontWeight: FontWeight.w500),
            ),
            child: const Text("Delete Account"),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<String?> _promptPassword() async {
    return await showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return const _PasswordInputDialog();
      },
    );
  }
}

class _PasswordInputDialog extends StatefulWidget {
  const _PasswordInputDialog({Key? key}) : super(key: key);

  @override
  State<_PasswordInputDialog> createState() => _PasswordInputDialogState();
}

class _PasswordInputDialogState extends State<_PasswordInputDialog> {
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text("Re-authenticate", style: TextStyle(fontWeight: FontWeight.w600)),
      content: TextField(
        controller: _passwordController,
        obscureText: true,
        decoration: InputDecoration(
          labelText: "Enter your password",
          labelStyle: TextStyle(color: Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
          ),
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          style: TextButton.styleFrom(
            foregroundColor: theme.primaryColor,
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _passwordController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 2,
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
          child: const Text("Confirm"),
        ),
      ],
    );
  }
}
