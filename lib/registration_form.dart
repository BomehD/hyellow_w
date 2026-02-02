import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hyellow_w/home_screen.dart'; // Adjust path if necessary
import 'login_screen.dart'; // Adjust path if necessary
import 'package:dropdown_button2/dropdown_button2.dart';

class RegistrationForm extends StatefulWidget {
  @override
  _RegistrationFormState createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String name = ''; // User's display name
  String? selectedCountry;
  String? _selectedInterest;
  bool _isLoading = false; // Loading state

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> availableInterests = [
    'Podcasts', 'Creative Art | Design', 'Health | Fitness', 'Mindfulness | Meditation',
    'Entrepreneurship', 'Sports', 'Photography', 'Fashion | Beauty', 'Film | Cinema',
    'Technology', 'Reality Gaming', 'Startup Building | Indie Hacking', 'Animals | Pets',
    'AI Art | Tools', 'Nature | Outdoors', 'Gardening', 'Music | Sound Culture',
    'Memes', 'Dance | Choreography', 'History', 'Science', 'Spirituality | Wellness',
    'Finance | Investing', 'Education | Learning', 'Business', 'Automobiles',
    'Social Media | Blogging', 'Home Improvement | DIY', 'Crypto', 'Real Estate',
    'Cooking Techniques | Recipes', 'Community Service', 'Space | Astronomy',
    'Languages | Linguistics', 'Day In The Life', 'Love', 'Entertainment',
    'Environmental Sustainability', 'Parenting | Family', 'Travel',
    'Theater | Performing Arts', 'Professional Development', 'Writing | Publishing'
  ];

  bool _obscureText = true;

  // --- Generate Unique Handle ---
  Future<String> _generateUniqueHandle(String displayName) async {
    // 1. Create a base handle from the display name: lowercase, remove spaces and non-alphanumeric/underscore chars
    String baseHandle = displayName.toLowerCase()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    // Fallback if the name results in an empty string (e.g., "!")
    if (baseHandle.isEmpty) {
      baseHandle = 'user';
    }

    String finalHandle = baseHandle;
    int counter = 0;
    bool handleExists = true;

    // 2. Check for uniqueness in Firestore
    while (handleExists) {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('handle', isEqualTo: finalHandle)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Handle is unique, we can use it
        handleExists = false;
      } else {
        // Handle exists, append a number and try again
        counter++;
        finalHandle = '$baseHandle$counter';
      }
    }
    return finalHandle;
  }

  Future<void> register() async {
    // Validate FIRST before any async operations
    if (!_formKey.currentState!.validate()) {
      return; // Stop here if validation fails
    }

    // Prevent multiple submissions
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Register user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Generate unique handle before storing user data
      final String uniqueHandle = await _generateUniqueHandle(name);

      // Store user data in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'name_lower': name.toLowerCase(),
        'handle': uniqueHandle,
        'email': email,
        'country': selectedCountry,
        'interest': _selectedInterest,
        'welcomeShown': false,
        'joinedAt': FieldValue.serverTimestamp(),
        'last_seen': FieldValue.serverTimestamp(),
      });

      // Navigate to HomeScreen
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }

      print('User registered successfully!');
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'email-already-in-use') {
        message = 'This email is already in use.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is invalid.';
      } else if (e.code == 'weak-password') {
        message = 'The password is too weak.';
      } else {
        message = 'Registration failed: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      // Fallback for unexpected errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred.')),
        );
      }
      print(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  // Helper method for consistent InputDecoration styling for text fields
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


  final List<Map<String, String>> countries = [
    {'name': 'Afghanistan', 'flag': '🇦🇫'}, {'name': 'Albania', 'flag': '🇦🇱'},
    {'name': 'Algeria', 'flag': '🇩🇿'}, {'name': 'Andorra', 'flag': '🇦🇩'},
    {'name': 'Angola', 'flag': '🇦🇴'}, {'name': 'Antigua and Barbuda', 'flag': '🇦🇬'},
    {'name': 'Argentina', 'flag': '🇦🇷'}, {'name': 'Armenia', 'flag': '🇦🇲'},
    {'name': 'Australia', 'flag': '🇦🇺'}, {'name': 'Austria', 'flag': '🇦🇹'},
    {'name': 'Azerbaijan', 'flag': '🇦🇿'}, {'name': 'Bahamas', 'flag': '🇧🇸'},
    {'name': 'Bahrain', 'flag': '🇧🇭'}, {'name': 'Bangladesh', 'flag': '🇧🇩'},
    {'name': 'Barbados', 'flag': '🇧🇧'}, {'name': 'Belarus', 'flag': '🇧🇾'},
    {'name': 'Belgium', 'flag': '🇧🇪'}, {'name': 'Belize', 'flag': '🇧🇿'},
    {'name': 'Benin', 'flag': '🇧🇯'}, {'name': 'Bhutan', 'flag': '🇧🇹'},
    {'name': 'Bolivia', 'flag': '🇧🇴'}, {'name': 'Bosnia and Herzegovina', 'flag': '🇧🇦'},
    {'name': 'Botswana', 'flag': '🇧🇼'}, {'name': 'Brazil', 'flag': '🇧🇷'},
    {'name': 'Brunei', 'flag': '🇧🇳'}, {'name': 'Bulgaria', 'flag': '🇧🇬'},
    {'name': 'Burkina Faso', 'flag': '🇧🇫'}, {'name': 'Burundi', 'flag': '🇧🇮'},
    {'name': 'Cabo Verde', 'flag': '🇨🇻'}, {'name': 'Cambodia', 'flag': '🇰🇭'},
    {'name': 'Cameroon', 'flag': '🇨🇲'}, {'name': 'Canada', 'flag': '🇨🇦'},
    {'name': 'Central African Republic', 'flag': '🇨🇫'}, {'name': 'Chad', 'flag': '🇹🇩'},
    {'name': 'Chile', 'flag': '🇨🇱'}, {'name': 'China', 'flag': '🇨🇳'},
    {'name': 'Colombia', 'flag': '🇨🇴'}, {'name': 'Comoros', 'flag': '🇰🇲'},
    {'name': 'Congo (Brazzaville)', 'flag': '🇨🇬'}, {'name': 'Congo (Kinshasa)', 'flag': '🇨🇩'},
    {'name': 'Costa Rica', 'flag': '🇨🇷'}, {'name': 'Croatia', 'flag': '🇭🇷'},
    {'name': 'Cuba', 'flag': '🇨🇺'}, {'name': 'Cyprus', 'flag': '🇨🇾'},
    {'name': 'Czech Republic', 'flag': '🇨🇿'}, {'name': 'Denmark', 'flag': '🇩🇰'},
    {'name': 'Djibouti', 'flag': '🇩🇯'}, {'name': 'Dominica', 'flag': '🇩🇲'},
    {'name': 'Dominican Republic', 'flag': '🇩🇴'}, {'name': 'Ecuador', 'flag': '🇪🇨'},
    {'name': 'Egypt', 'flag': '🇪🇬'}, {'name': 'El Salvador', 'flag': '🇸🇻'},
    {'name': 'Equatorial Guinea', 'flag': '🇬🇶'}, {'name': 'Eritrea', 'flag': '🇪🇷'},
    {'name': 'Estonia', 'flag': '🇪🇪'}, {'name': 'Eswatini', 'flag': '🇸🇿'},
    {'name': 'Ethiopia', 'flag': '🇪🇹'}, {'name': 'Fiji', 'flag': '🇫🇯'},
    {'name': 'Finland', 'flag': '🇫🇮'}, {'name': 'France', 'flag': '🇫🇷'},
    {'name': 'Gabon', 'flag': '🇬🇦'}, {'name': 'Gambia', 'flag': '🇬🇲'},
    {'name': 'Georgia', 'flag': '🇬🇪'}, {'name': 'Germany', 'flag': '🇩🇪'},
    {'name': 'Ghana', 'flag': '🇬🇭'}, {'name': 'Greece', 'flag': '🇬🇷'},
    {'name': 'Grenada', 'flag': '🇬🇩'}, {'name': 'Guatemala', 'flag': '🇬🇹'},
    {'name': 'Guinea', 'flag': '🇬🇳'}, {'name': 'Guinea-Bissau', 'flag': '🇬🇼'},
    {'name': 'Guyana', 'flag': '🇬🇾'}, {'name': 'Haiti', 'flag': '🇭🇹'},
    {'name': 'Honduras', 'flag': '🇭🇳'}, {'name': 'Hungary', 'flag': '🇭🇺'},
    {'name': 'Iceland', 'flag': '🇮🇸'}, {'name': 'India', 'flag': '🇮🇳'},
    {'name': 'Indonesia', 'flag': '🇮🇩'}, {'name': 'Iran', 'flag': '🇮🇷'},
    {'name': 'Iraq', 'flag': '🇮🇶'}, {'name': 'Ireland', 'flag': '🇮🇪'},
    {'name': 'Israel', 'flag': '🇮🇱'}, {'name': 'Italy', 'flag': '🇮🇹'},
    {'name': 'Jamaica', 'flag': '🇯🇲'}, {'name': 'Japan', 'flag': '🇯🇵'},
    {'name': 'Jordan', 'flag': '🇯🇴'}, {'name': 'Kazakhstan', 'flag': '🇰🇿'},
    {'name': 'Kenya', 'flag': '🇰🇪'}, {'name': 'Kiribati', 'flag': '🇰🇮'},
    {'name': 'Kuwait', 'flag': '🇰🇼'}, {'name': 'Kyrgyzstan', 'flag': '🇰🇬'},
    {'name': 'Laos', 'flag': '🇱🇦'}, {'name': 'Latvia', 'flag': '🇱🇻'},
    {'name': 'Lebanon', 'flag': '🇱🇧'}, {'name': 'Lesotho', 'flag': '🇱🇸'},
    {'name': 'Liberia', 'flag': '🇱🇷'}, {'name': 'Libya', 'flag': '🇱🇾'},
    {'name': 'Liechtenstein', 'flag': '🇱🇮'}, {'name': 'Lithuania', 'flag': '🇱🇹'},
    {'name': 'Luxembourg', 'flag': '🇱🇺'}, {'name': 'Madagascar', 'flag': '🇲🇬'},
    {'name': 'Malawi', 'flag': '🇲🇼'}, {'name': 'Malaysia', 'flag': '🇲🇾'},
    {'name': 'Maldives', 'flag': '🇲🇻'}, {'name': 'Mali', 'flag': '🇲🇱'},
    {'name': 'Malta', 'flag': '🇲🇹'}, {'name': 'Marshall Islands', 'flag': '🇲🇭'},
    {'name': 'Mauritania', 'flag': '🇲🇷'}, {'name': 'Mauritius', 'flag': '🇲🇺'},
    {'name': 'Mexico', 'flag': '🇲🇽'}, {'name': 'Micronesia', 'flag': '🇫🇲'},
    {'name': 'Moldova', 'flag': '🇲🇩'}, {'name': 'Monaco', 'flag': '🇲🇨'},
    {'name': 'Mongolia', 'flag': '🇲🇳'}, {'name': 'Montenegro', 'flag': '🇲🇪'},
    {'name': 'Morocco', 'flag': '🇲🇦'}, {'name': 'Mozambique', 'flag': '🇲🇿'},
    {'name': 'Myanmar', 'flag': '🇲🇲'}, {'name': 'Namibia', 'flag': '🇳🇦'},
    {'name': 'Nauru', 'flag': '🇳🇷'}, {'name': 'Nepal', 'flag': '🇳🇵'},
    {'name': 'Netherlands', 'flag': '🇳🇱'}, {'name': 'New Zealand', 'flag': '🇳🇿'},
    {'name': 'Nicaragua', 'flag': '🇳🇮'}, {'name': 'Niger', 'flag': '🇳🇪'},
    {'name': 'Nigeria', 'flag': '🇳🇬'}, {'name': 'North Korea', 'flag': '🇰🇵'},
    {'name': 'North Macedonia', 'flag': '🇲🇰'}, {'name': 'Norway', 'flag': '🇳🇴'},
    {'name': 'Oman', 'flag': '🇴🇲'}, {'name': 'Pakistan', 'flag': '🇵🇰'},
    {'name': 'Palau', 'flag': '🇵🇼'}, {'name': 'Palestine', 'flag': '🇵🇸'},
    {'name': 'Panama', 'flag': '🇵🇦'}, {'name': 'Papua New Guinea', 'flag': '🇵🇬'},
    {'name': 'Paraguay', 'flag': '🇵🇾'}, {'name': 'Peru', 'flag': '🇵🇪'},
    {'name': 'Philippines', 'flag': '🇵🇭'}, {'name': 'Poland', 'flag': '🇵🇱'},
    {'name': 'Portugal', 'flag': '🇵🇹'}, {'name': 'Qatar', 'flag': '🇶🇦'},
    {'name': 'Romania', 'flag': '🇷🇴'}, {'name': 'Russia', 'flag': '🇷🇺'},
    {'name': 'Rwanda', 'flag': '🇷🇼'}, {'name': 'Saint Kitts and Nevis', 'flag': '🇰🇳'},
    {'name': 'Saint Lucia', 'flag': '🇱🇨'}, {'name': 'Saint Vincent and the Grenadines', 'flag': '🇻🇨'},
    {'name': 'Samoa', 'flag': '🇼🇸'}, {'name': 'San Marino', 'flag': '🇸🇲'},
    {'name': 'Sao Tome and Principe', 'flag': '🇸🇹'}, {'name': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'name': 'Senegal', 'flag': '🇸🇳'}, {'name': 'Serbia', 'flag': '🇷🇸'},
    {'name': 'Seychelles', 'flag': '🇸🇨'}, {'name': 'Sierra Leone', 'flag': '🇸🇱'},
    {'name': 'Singapore', 'flag': '🇸🇬'}, {'name': 'Slovakia', 'flag': '🇸🇰'},
    {'name': 'Slovenia', 'flag': '🇸🇮'}, {'name': 'Solomon Islands', 'flag': '🇸🇧'},
    {'name': 'Somalia', 'flag': '🇸🇴'}, {'name': 'South Africa', 'flag': '🇿🇦'},
    {'name': 'South Korea', 'flag': '🇰🇷'}, {'name': 'South Sudan', 'flag': '🇸🇸'},
    {'name': 'Spain', 'flag': '🇪🇸'}, {'name': 'Sri Lanka', 'flag': '🇱🇰'},
    {'name': 'Sudan', 'flag': '🇸🇩'}, {'name': 'Suriname', 'flag': '🇸🇷'},
    {'name': 'Sweden', 'flag': '🇸🇪'}, {'name': 'Switzerland', 'flag': '🇨🇭'},
    {'name': 'Syria', 'flag': '🇸🇾'}, {'name': 'Taiwan', 'flag': '🇹🇼'},
    {'name': 'Tajikistan', 'flag': '🇹🇯'}, {'name': 'Tanzania', 'flag': '🇹🇿'},
    {'name': 'Thailand', 'flag': '🇹🇭'}, {'name': 'Timor-Leste', 'flag': '🇹🇱'},
    {'name': 'Togo', 'flag': '🇹🇬'}, {'name': 'Tonga', 'flag': '🇹🇴'},
    {'name': 'Trinidad and Tobago', 'flag': '🇹🇹'}, {'name': 'Tunisia', 'flag': '🇹🇳'},
    {'name': 'Turkey', 'flag': '🇹🇷'}, {'name': 'Turkmenistan', 'flag': '🇹🇲'},
    {'name': 'Tuvalu', 'flag': '🇹🇻'}, {'name': 'Uganda', 'flag': '🇺🇬'},
    {'name': 'Ukraine', 'flag': '🇺🇦'}, {'name': 'United Arab Emirates', 'flag': '🇦🇪'},
    {'name': 'United Kingdom', 'flag': '🇬🇧'}, {'name': 'United States', 'flag': '🇺🇸'},
    {'name': 'Uruguay', 'flag': '🇺🇾'}, {'name': 'Uzbekistan', 'flag': '🇺🇿'},
    {'name': 'Vanuatu', 'flag': '🇻🇺'}, {'name': 'Vatican City', 'flag': '🇻🇦'},
    {'name': 'Venezuela', 'flag': '🇻🇪'}, {'name': 'Vietnam', 'flag': '🇻🇳'},
    {'name': 'Yemen', 'flag': '🇾🇪'}, {'name': 'Zambia', 'flag': '🇿🇲'},
    {'name': 'Zimbabwe', 'flag': '🇿🇼'},
  ];


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
        color: isDark ? Colors.black : null,
        child: Center(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  margin: const EdgeInsets.all(24.0),
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
                        Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 42.0,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF106C70),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Join ',
                                style: TextStyle(fontSize: 16.0, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                              ),
                              TextSpan(
                                text: 'CoPal',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: isDark ? Colors.tealAccent : const Color(0xFF106C70),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: ' and find your people!',
                                style: TextStyle(fontSize: 16.0, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        // Email
                        TextFormField(
                          cursorColor: isDark ? Colors.tealAccent : const Color(0xFF106C70),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: _inputDecoration('Email', Icons.email, isDark),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) => email = value.trim(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Please enter your email';
                            final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                            if (!emailRegex.hasMatch(value.trim())) return 'Please enter a valid email address';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password
                        TextFormField(
                          cursorColor: isDark ? Colors.tealAccent : const Color(0xFF106C70),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: _inputDecoration('Password', Icons.lock, isDark).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText ? Icons.visibility_off : Icons.visibility,
                                color: isDark ? Colors.grey[400] : Colors.grey[500],
                              ),
                              onPressed: () => setState(() => _obscureText = !_obscureText),
                            ),
                          ),
                          obscureText: _obscureText,
                          onChanged: (value) => password = value,
                          validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
                        ),
                        const SizedBox(height: 20),

                        // Name
                        TextFormField(
                          cursorColor: isDark ? Colors.tealAccent : const Color(0xFF106C70),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: _inputDecoration('Name', Icons.person, isDark),
                          onChanged: (value) => name = value,
                          validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
                        ),
                        const SizedBox(height: 20),

                        // Country
                        DropdownButtonFormField2<String>(
                          isExpanded: true,
                          value: selectedCountry,
                          decoration: InputDecoration(
                            labelText: 'Country',
                            labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15.0),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            prefixIcon: Icon(Icons.language, color: isDark ? Colors.tealAccent : const Color(0xFF106C70)),
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          ),
                          items: countries.map((country) {
                            final name = country['name']!;
                            final flag = country['flag']!;
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Row(
                                children: [
                                  Text(flag, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCountry = value!;
                            });
                          },
                          validator: (value) => value == null ? 'Please select a country' : null,
                          dropdownStyleData: DropdownStyleData(
                            maxHeight: 300,
                            width: 340,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            offset: const Offset(0, -5),
                            scrollbarTheme: ScrollbarThemeData(
                              thumbColor: MaterialStateProperty.all(isDark ? Colors.tealAccent : const Color(0xFF106C70)),
                              radius: const Radius.circular(8),
                              thickness: MaterialStateProperty.all(6),
                            ),
                          ),
                          menuItemStyleData: const MenuItemStyleData(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Interest Dropdown (Single-select)
                        DropdownButtonFormField<String>(
                          value: _selectedInterest,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Select Interest',
                            labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15.0),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            prefixIcon: Icon(Icons.interests, color: isDark ? Colors.tealAccent : const Color(0xFF106C70)),
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          ),
                          items: availableInterests.map((interest) {
                            return DropdownMenuItem(
                              value: interest,
                              child: Text(interest, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedInterest = value;
                            });
                          },
                          validator: (value) => value == null || value.isEmpty ? 'Please select an interest' : null,
                        ),

                        const SizedBox(height: 10),

                        if (_selectedInterest != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Chip(
                              label: Text(_selectedInterest!),
                              labelStyle: const TextStyle(color: Colors.white, fontSize: 13.0),
                              backgroundColor: isDark ? Colors.tealAccent[700] : const Color(0xFF106C70),
                              deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
                              onDeleted: () {
                                setState(() {
                                  _selectedInterest = null;
                                });
                              },
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),

                        const SizedBox(height: 30),

                        // Register Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : () async => await register(),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: isDark ? Colors.tealAccent[700] : const Color(0xFF106C70),
                            disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[400],
                            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 16.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                            elevation: isDark ? 2 : 8,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text(
                            'Register',
                            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: TextStyle(fontSize: 16.0, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => LoginScreen()),
                                );
                              },
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: isDark ? Colors.tealAccent : const Color(0xFF106C70),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
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
}