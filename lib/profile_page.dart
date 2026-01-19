import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hyellow_w/profile_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'custom_input_decoration.dart';

class ProfilePage extends StatefulWidget {
  final String name;
  final String interest;
  final String about;
  final String title;
  final String phone;
  final String email;
  final String profileImage;

  ProfilePage({
    required this.name,
    required this.interest,
    required this.about,
    required this.title,
    required this.phone,
    required this.email,
    required this.profileImage,
  });

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _aboutController;
  late TextEditingController _titleController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  String? _selectedInterest;

  final List<String> _interests = [
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

  File? _profileImageFile;
  Uint8List? _profileImageWeb;
  String? currentProfileImage;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _aboutController = TextEditingController(text: widget.about);
    _titleController = TextEditingController(text: widget.title);
    _phoneController = TextEditingController(text: widget.phone);
    _emailController = TextEditingController(text: widget.email);


    if (_interests.contains(widget.interest)) {
      _selectedInterest = widget.interest;
    } else {
      _selectedInterest = null; // or a default like _interests.first
    }


    currentProfileImage = (widget.profileImage.isNotEmpty && !widget.profileImage.contains('assets/'))
        ? widget.profileImage
        : 'assets/default_profile_image.png';
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.first.bytes != null) {
        _profileImageWeb = result.files.first.bytes;
        setState(() {});
      }
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        _profileImageFile = File(pickedFile.path);
        setState(() {});
      }
    }
  }

  Future<void> _saveProfile() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User is not authenticated");

      String uid = currentUser.uid;
      String? imageUrl;

      if (_profileImageWeb != null || _profileImageFile != null) {
        String fileName = 'profile_images/$uid/${DateTime.now().millisecondsSinceEpoch}.png';
        final ref = FirebaseStorage.instance.ref().child(fileName);

        if (kIsWeb && _profileImageWeb != null) {
          await ref.putData(_profileImageWeb!);
        } else if (_profileImageFile != null) {
          await ref.putFile(_profileImageFile!);
        }

        imageUrl = await ref.getDownloadURL();
      }

      DocumentReference profileRef = FirebaseFirestore.instance.collection('profiles').doc(uid);
      DocumentSnapshot docSnapshot = await profileRef.get();

      String previousImage = docSnapshot.exists && docSnapshot['profileImage'] != null
          ? docSnapshot['profileImage']
          : 'assets/default_profile_image.png';

      String finalImageUrl = imageUrl ?? previousImage;

      // ✅ Update 'profiles' collection
      await profileRef.set({
        'userId': uid,
        'name': _nameController.text,
        'name_lower': _nameController.text.toLowerCase(),
        'interest': _selectedInterest ?? "Not specified",
        'about': _aboutController.text,
        'title': _titleController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'profileImage': finalImageUrl,
      });

      // ✅ Update 'users' collection
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text,
        'name_lower': _nameController.text.toLowerCase(),
        'interest': _selectedInterest ?? "Not specified",
      }, SetOptions(merge: true));

      // ✅ Navigate to ProfileView with updated data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileView(
            name: _nameController.text,
            interest: _selectedInterest ?? "Not specified",
            about: _aboutController.text,
            title: _titleController.text,
            phone: _phoneController.text,
            email: _emailController.text,
            profileImage: finalImageUrl,
          ),
        ),
      );
    } catch (error) {
      print("Error saving profile: $error");
    }
  }

  // New helper method for responsive layout
  double _getContentWidth(double screenWidth) {
    if (screenWidth >= 1200) {
      return 600; // Fixed width for large desktops
    } else if (screenWidth >= 800) {
      return screenWidth * 0.65; // 65% for tablets
    } else {
      return screenWidth; // Full width for mobile
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(color: Color(0xFF106C70), fontSize: 13)),
      ),
      body: Center( // Centers the entire content horizontally
        child: SizedBox(
          width: isDesktop ? _getContentWidth(screenWidth) : screenWidth,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Theme(
              data: Theme.of(context).copyWith(inputDecorationTheme: customInputDecorationTheme),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Profile image
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 55,
                          backgroundImage: _profileImageWeb != null
                              ? MemoryImage(_profileImageWeb!)
                              : (_profileImageFile != null
                              ? FileImage(_profileImageFile!)
                              : (currentProfileImage!.contains('assets/')
                              ? AssetImage('assets/default_profile_image.png')
                              : NetworkImage(currentProfileImage!)
                          )) as ImageProvider,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: "Full Name", icon: Icon(Icons.person)),
                      validator: (value) => value == null || value.isEmpty ? 'Enter your full name' : null,
                    ),
                    SizedBox(height: 20),

                    // Interest dropdown
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedInterest,
                      onChanged: (String? newValue) {
                        setState(() => _selectedInterest = newValue);
                      },
                      decoration: InputDecoration(labelText: "Interest", icon: Icon(Icons.star)),
                      items: _interests.map((String interest) {
                        return DropdownMenuItem<String>(
                          value: interest,
                          child: Text(interest),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20),

                    // About
                    TextFormField(
                      controller: _aboutController,
                      decoration: InputDecoration(labelText: "About", icon: Icon(Icons.info)),
                      maxLines: 3,
                    ),
                    SizedBox(height: 20),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: "Title", icon: Icon(Icons.work)),
                    ),
                    SizedBox(height: 20),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: "Phone", icon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                      validator: (value) => value == null || value.isEmpty ? 'Enter your phone number' : null,
                    ),
                    SizedBox(height: 20),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: "Email", icon: Icon(Icons.email)),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value == null || value.isEmpty ? 'Enter your email' : null,
                    ),
                    SizedBox(height: 30),

                    // Save button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15.0),
                        backgroundColor: Color(0xFF106C70),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _saveProfile();
                        }
                      },
                      child: Text("Save", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}