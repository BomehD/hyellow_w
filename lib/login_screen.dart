import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_validator/email_validator.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'home_screen.dart';
import 'registration_form.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();

  final String? redirectTo;

  const LoginScreen({this.redirectTo, Key? key}) : super(key: key);
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers for text fields, better for managing text input
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // GlobalKey for form validation
  final _formKey = GlobalKey<FormState>();

  // State variables for form data and password visibility
  String email = '';
  String password = '';
  bool _obscureText = true;


  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '476459213996-iqscnlhtr3cidtmrhru9o60pio3lde58.apps.googleusercontent.com' : null,
  );


  @override
  void dispose() {
    // Dispose controllers to free up resources
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Asynchronous method to handle user login with email/password
  Future<void> login() async {
    email = _emailController.text.trim();
    password = _passwordController.text.trim();

    if (_formKey.currentState!.validate()) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logging in...')),
        );

        // Sign in
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = userCredential.user;
        if (user != null) {
          await ensureNotificationFieldsExist(user.uid);
        }

        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // ✅ Redirect to original destination if provided, or home
        Navigator.pushReplacementNamed(
          context,
          widget.redirectTo ?? '/',
        );

      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          message = 'Incorrect email or password. Please try again.';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is invalid.';
        } else {
          message = 'Login failed: ${e.message}';
        }
        _showErrorDialog(message);
      } catch (e) {
        _showErrorDialog('An unexpected error occurred. Please try again.');
        print(e.toString());
      }
    }
  }



  Future<void> ensureNotificationFieldsExist(String userId) async {
    final docRef = FirebaseFirestore.instance.collection('Friends').doc(userId);
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data()!;
      final Map<String, Object?> updates = {};

      if (!data.containsKey('notificationsRead')) {
        updates['notificationsRead'] = [];
      }
      if (!data.containsKey('notificationsMuted')) {
        updates['notificationsMuted'] = false;
      }

      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
    }
  }


  Future<void> _signInWithGoogle() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signing in with Google...')),
      );

      await _googleSignIn.signOut(); // Ensure a fresh Google login prompt
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        print('DEBUG: Google Sign-In cancelled by user.');
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential;

      try {
        userCredential = await _auth.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (userCredential.additionalUserInfo?.isNewUser == true) {
          print('DEBUG: New user created via Google, but should be rejected.');
          await user?.delete();
          await _googleSignIn.signOut();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showErrorDialog('No account found for this Google email. Please register first with email/password.');
          return;
        }

        // ✅ Ensure notification fields exist after successful login
        await ensureNotificationFieldsExist(user!.uid);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Navigator.pushReplacementNamed(context, '/');


      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          print('DEBUG: Account exists with different credential. Showing linking dialog.');
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showLinkAccountDialog(googleUser.email!, credential);
        } else {
          print('DEBUG: FirebaseAuthException during Google sign-in: ${e.code} - ${e.message}');
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showErrorDialog('Google login failed: ${e.message}');
          await _googleSignIn.signOut();
        }
      }

    } catch (e) {
      print('DEBUG: General exception during Google sign-in: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showErrorDialog('An unexpected error occurred during Google sign-in. Please manually '
          'log into your CoPal account.');
    }
  }


  // Method to display an error dialog
  void _showErrorDialog(String message) {
    // Ensure any existing snackbar is hidden before showing dialog
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Login Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Method to display a dialog for account linking, now uses StatefulBuilder
  Future<void> _showLinkAccountDialog(String email, AuthCredential googleCredential) async {
    final TextEditingController _linkPasswordController = TextEditingController();
    String? _dialogErrorMessage; // State variable for error message within the dialog

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( // Use StatefulBuilder to manage dialog's internal state
          builder: (context, setDialogState) { // setDialogState is like setState for the dialog
            return AlertDialog(
              title: Text('Account Linking Required'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('An account with this email ($email) already exists using email/password. Please enter your password to link your Google account.'),
                  SizedBox(height: 16),
                  TextField(
                    controller: _linkPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_dialogErrorMessage != null) // Display error if present
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_dialogErrorMessage!, style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _googleSignIn.signOut(); // Sign out from Google if canceled
                  },
                ),
                ElevatedButton(
                  child: Text('Link Account'),
                  onPressed: () async {
                    // Reset previous error message
                    setDialogState(() {
                      _dialogErrorMessage = null;
                    });

                    // Basic validation
                    if (_linkPasswordController.text.trim().isEmpty) {
                      setDialogState(() {
                        _dialogErrorMessage = 'Password cannot be empty.';
                      });
                      return;
                    }

                    try {
                      // 1. Re-authenticate the user with their email/password.
                      // This is required before linking a new provider.
                      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
                        email: email,
                        password: _linkPasswordController.text.trim(),
                      );

                      // Ensure a user is obtained
                      if (userCredential.user == null) {
                        setDialogState(() {
                          _dialogErrorMessage = 'Failed to retrieve user for linking.';
                        });
                        return;
                      }

                      // 2. Link the Google credential to the currently signed-in user.
                      await userCredential.user!.linkWithCredential(googleCredential);

                      // Successfully linked and logged in!
                      Navigator.of(dialogContext).pop(); // Close dialog
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Account linked and logged in successfully!')),
                      );
                      Navigator.pushReplacementNamed(context, '/');



                    } on FirebaseAuthException catch (e) {
                      String msg;
                      if (e.code == 'wrong-password') {
                        msg = 'Incorrect password. Please try again.';
                      } else if (e.code == 'user-disabled') {
                        msg = 'This user account has been disabled.';
                      } else if (e.code == 'credential-already-in-use') {
                        msg = 'This Google account is already linked to another Firebase account.';
                      }
                      else {
                        msg = 'Failed to link account: ${e.message}';
                      }
                      setDialogState(() { // Use setDialogState to update dialog's UI
                        _dialogErrorMessage = msg;
                      });
                    } catch (e) {
                      setDialogState(() {
                        _dialogErrorMessage = 'An unexpected error occurred during linking.';
                      });
                      print(e);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _linkPasswordController.dispose(); // Dispose controller after dialog closes
    });
  }

  // Asynchronous method to handle password reset
  Future<void> _resetPassword() async {
    email = _emailController.text.trim();

    // Validate email format before sending reset email
    if (!EmailValidator.validate(email)) {
      _showErrorDialog('Please enter a valid email address to reset password.');
      return;
    }

    try {
      // Send password reset email
      await _auth.sendPasswordResetEmail(email: email);
      _showSuccessDialog('Password reset email sent. Check your inbox.');
    } on FirebaseAuthException catch (e) {
      // Handle Firebase errors during password reset
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else {
        message = 'Failed to send reset email: ${e.message}';
      }
      _showErrorDialog(message);
    } catch (e) {
      // Handle any other unexpected errors
      _showErrorDialog('An unexpected error occurred while sending reset email.');
      print(e.toString()); // Print the error for debugging
    }
  }

  // Method to display a success dialog for password reset
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        // Background color aligned with app theme
        backgroundColor: const Color(0xFF106C70).withOpacity(0.95),
        title: const Text('Reset Password', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: isDark
            ? null
            : const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF88D490),
              Color(0xFF106C70),
            ],
          ),
        ),
        color: isDark ? Colors.black : null, // fallback for dark mode
        child: Center(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24.0),
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: isDark
                        ? []
                        : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 5,
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open_outlined,
                            size: 50,
                            color: isDark ? Colors.tealAccent : const Color(0xFF106C70)),
                        const SizedBox(height: 10),
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 40.0,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF106C70),
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Login to your CoPal account',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        TextFormField(
                          controller: _emailController,
                          cursorColor: isDark ? Colors.tealAccent : const Color(0xFF106C70),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: _inputDecoration('Email', Icons.email, isDark),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            } else if (!EmailValidator.validate(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          cursorColor: isDark ? Colors.tealAccent : const Color(0xFF106C70),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          obscureText: _obscureText,
                          decoration: _inputDecoration('Password', Icons.lock, isDark).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText ? Icons.visibility_off : Icons.visibility,
                                color: isDark ? Colors.grey[400] : Colors.grey[500],
                              ),
                              onPressed: () => setState(() => _obscureText = !_obscureText),
                            ),
                          ),
                          validator: (value) => value!.length < 6
                              ? 'Password must be at least 6 characters'
                              : null,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: login,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: isDark ? Colors.tealAccent[700] : const Color(0xFF106C70),
                            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 16.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                            elevation: isDark ? 2 : 8,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Row(
                            children: [
                              Expanded(child: Divider(color: isDark ? Colors.grey[700] : Colors.grey[300])),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                child: Text('OR',
                                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                              ),
                              Expanded(child: Divider(color: isDark ? Colors.grey[700] : Colors.grey[300])),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        ElevatedButton(
                          onPressed: _signInWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                            foregroundColor: isDark ? Colors.white : Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50.0),
                            ),
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/2048px-Google_%22G%22_logo.svg.png',
                                height: 22.0,
                                width: 22.0,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.g_mobiledata, size: 22, color: Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 1),
                        TextButton(
                          onPressed: _resetPassword,
                          child: Text(
                            'Forgot your password?',
                            style: TextStyle(
                              fontSize: 16.0,
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: TextStyle(
                                fontSize: 16.0,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                    context, MaterialPageRoute(builder: (_) => RegistrationForm()));
                              },
                              child: Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: isDark ? Colors.tealAccent : const Color(0xFF106C70),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Updated input decoration to adapt for dark mode
  InputDecoration _inputDecoration(String label, IconData iconData, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15.0),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      prefixIcon: Icon(iconData, color: isDark ? Colors.tealAccent : const Color(0xFF106C70)),
      filled: true,
      fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: isDark ? Colors.tealAccent : const Color(0xFF106C70), width: 2.0),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    );
  }


}