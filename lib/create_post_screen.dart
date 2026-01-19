// All necessary imports for the class
import 'dart:io'; // Required for File on mobile
import 'dart:typed_data'; // Required for Uint8List for web

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:dotted_border/dotted_border.dart';
import 'package:video_player/video_player.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  String _postContent = '';
  // NEW: Separate variables for images and video
  final List<XFile> _pickedImages = [];
  XFile? _pickedVideo;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  String? _selectedInterest;
  final List<String> _availableInterests = [
    'Podcasts',
    'Creative Art | Design',
    'Health | Fitness',
    'Mindfulness | Meditation',
    'Entrepreneurship',
    'Sports',
    'Photography',
    'Fashion | Beauty',
    'Film | Cinema',
    'Technology',
    'Reality Gaming',
    'Startup Building | Indie Hacking',
    'Animals | Pets',
    'AI Art | Tools',
    'Nature | Outdoors',
    'Gardening',
    'Music | Sound Culture',
    'Memes',
    'Dance | Choreography',
    'History',
    'Science',
    'Spirituality | Wellness',
    'Finance | Investing',
    'Education | Learning',
    'Business ',
    'Automobiles',
    'Social Media | Blogging',
    'Home Improvement | DIY',
    'Crypto',
    'Real Estate',
    'Cooking Techniques | Recipes',
    'Community Service',
    'Space | Astronomy',
    'Languages | Linguistics',
    'Day In The Life',
    'Love',
    'Entertainment',
    'Environmental Sustainability',
    'Parenting | Family',
    'Travel',
    'Theater | Performing Arts',
    'Professional Development',
    'Writing | Publishing'
  ];
  VideoPlayerController? _videoController;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // Helper methods for responsive layout
  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 800;
  }

  bool _isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 800;
  }

  double _getContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1200) {
      return 600; // Fixed width for large screens
    } else if (screenWidth >= 800) {
      return screenWidth * 0.65; // 65% for medium screens
    } else if (screenWidth >= 600) {
      return screenWidth * 0.8; // 80% for tablets
    } else {
      return screenWidth - 40; // Full width minus padding for mobile
    }
  }

  EdgeInsets _getContentPadding(BuildContext context) {
    if (_isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0);
    } else if (_isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0);
    }
  }

  // Responsive media picker bottom sheet
  void _showMediaPicker() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Media Source',
                  style: TextStyle(
                    fontSize: _isDesktop(context) ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onBackground,
                  ),
                ),
                const SizedBox(height: 20),
                _buildMediaOption(
                  icon: Icons.photo_library,
                  title: 'Pick Images from Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickMediaFromSource(ImageSource.gallery, isImage: true);
                  },
                ),
                _buildMediaOption(
                  icon: Icons.camera_alt,
                  title: 'Take Photo with Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickMediaFromSource(ImageSource.camera, isImage: true);
                  },
                ),
                const Divider(height: 32),
                _buildMediaOption(
                  icon: Icons.video_library,
                  title: 'Pick Video from Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickMediaFromSource(ImageSource.gallery, isImage: false);
                  },
                ),
                _buildMediaOption(
                  icon: Icons.videocam,
                  title: 'Record Video with Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickMediaFromSource(ImageSource.camera, isImage: false);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: cs.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: _isDesktop(context) ? 16 : 14,
            fontWeight: FontWeight.w500,
            color: cs.onBackground,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: theme.cardColor,
      ),
    );
  }

  Widget _buildResponsiveContent(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isDesktop(context)) {
          return Center(
            child: SizedBox(
              width: _getContentWidth(context),
              child: child,
            ),
          );
        }
        return child;
      },
    );
  }

  Future<void> _pickMediaFromSource(ImageSource source, {required bool isImage}) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      if (mounted) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You must be logged in to upload media.'),
            backgroundColor: cs.primary,
          ),
        );
      }
      return;
    }

    try {
      if (isImage) {
        final List<XFile> pickedFiles = await _picker.pickMultiImage();
        if (pickedFiles.isNotEmpty) {
          setState(() {
            _pickedImages.addAll(pickedFiles);
          });
        }
      } else {
        final XFile? pickedFile = await _picker.pickVideo(source: source);
        if (pickedFile != null) {
          setState(() {
            _pickedVideo = pickedFile;
            _videoController?.dispose();
            _videoController = VideoPlayerController.file(File(pickedFile.path))
              ..initialize().then((_) {
                if (mounted) {
                  setState(() {});
                }
              });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick media: $e'),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  Future<String?> _uploadSingleFile(XFile file, String storagePath) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.name)}';
      final Reference storageRef = _storage.ref().child(storagePath).child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        final Uint8List data = await file.readAsBytes();
        uploadTask = storageRef.putData(data);
      } else {
        uploadTask = storageRef.putFile(File(file.path));
      }

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload media: $e'), backgroundColor: cs.error),
        );
      }
      return null;
    }
  }

  Future<List<String>> _uploadMultipleFiles(List<XFile> files, String storagePath) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    List<String> downloadUrls = [];
    for (XFile file in files) {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.name)}';
      final Reference storageRef = _storage.ref().child(storagePath).child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        final Uint8List data = await file.readAsBytes();
        uploadTask = storageRef.putData(data);
      } else {
        uploadTask = storageRef.putFile(File(file.path));
      }
      try {
        final TaskSnapshot snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        downloadUrls.add(url);
      } catch (e) {
        print('Failed to upload file ${file.name}: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload one of the media files: ${file.name}'), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
    }
    return downloadUrls;
  }

  Future<void> _savePost() async {
    if (!mounted || !_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    if (_postContent.isEmpty && _pickedImages.isEmpty && _pickedVideo == null) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add some content or media to your post.'),
          backgroundColor: cs.primary,
        ),
      );
      return;
    }

    final int totalFilesToUpload = _pickedImages.length + (_pickedVideo != null ? 1 : 0);

    if (totalFilesToUpload > 0) {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });
    }

    List<String> imageUrls = [];
    String? videoUrl;

    try {
      if (_pickedImages.isNotEmpty) {
        final List<String> uploadedImageUrls = await _uploadMultipleFiles(_pickedImages, 'post_media/${_auth.currentUser!.uid}/images');
        imageUrls.addAll(uploadedImageUrls);
        setState(() {
          _uploadProgress = (imageUrls.length / totalFilesToUpload) * 100;
        });
      }

      if (_pickedVideo != null) {
        videoUrl = await _uploadSingleFile(_pickedVideo!, 'post_media/${_auth.currentUser!.uid}/videos');
        setState(() {
          _uploadProgress = (_pickedImages.length + 1) / totalFilesToUpload * 100;
        });
      }

      final User? user = _auth.currentUser;

      if (user == null) {
        throw 'User not logged in';
      }

      DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(user.uid).get();
      DocumentSnapshot profileSnapshot = await _firestore.collection('profiles').doc(user.uid).get();

      if (!userSnapshot.exists) {
        throw 'User data not found';
      }

      final userData = userSnapshot.data() as Map<String, dynamic>;
      final profileData = profileSnapshot.data() as Map<String, dynamic>? ?? {};

      final authorName = userData['name'] ?? 'Unknown User';
      final authorProfileImage = profileData['profileImage'] ?? 'https://via.placeholder.com/150';

      dynamic rawInterest = userData['interest'] ?? userData['interests'];
      String defaultInterest;

      if (rawInterest is List && rawInterest.isNotEmpty) {
        defaultInterest = rawInterest.first.toString();
      } else if (rawInterest is String && rawInterest.isNotEmpty) {
        defaultInterest = rawInterest;
      } else {
        defaultInterest = 'General';
      }

      String interestField = _selectedInterest ?? defaultInterest;

      final countryData = userData['country'];
      List<String> userCountries;

      if (countryData is String) {
        userCountries = [countryData];
      } else if (countryData is List) {
        userCountries = List<String>.from(countryData);
      } else {
        userCountries = ['Unknown'];
      }

      // FIX: Ensure only one of 'imageUrls' or 'videoUrl' is saved.
      // This is a crucial fix to avoid conflicting data types in Firestore.
      final Map<String, dynamic> postData = {
        'content': _postContent,
        'timestamp': Timestamp.now(),
        'authorId': user.uid,
        'authorName': authorName,
        'authorProfileImage': authorProfileImage,
        'likeCount': 0,
        'commentCount': 0,
        'interest': interestField,
        'userDefaultInterest': defaultInterest,
        'country': userCountries,
        'commentsEnabled': true,
        'visibility': 'public',
      };

      if (imageUrls.isNotEmpty) {
        postData['imageUrls'] = imageUrls;
      }
      if (videoUrl != null) {
        postData['videoUrl'] = videoUrl;
      }

      await _firestore.collection('posts').add(postData);

      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post published successfully!'),
            backgroundColor: cs.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving post: $e');
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to publish post. Please try again.'),
            backgroundColor: cs.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildPickedMedia() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool hasImages = _pickedImages.isNotEmpty;
    final bool hasVideo = _pickedVideo != null;

    if (!hasImages && !hasVideo) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo,
              size: _isDesktop(context) ? 50 : 40,
              color: cs.onPrimary,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to upload image(s) or video',
              style: TextStyle(
                color: cs.onPrimary,
                fontSize: _isDesktop(context) ? 16 : 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (hasImages)
          Padding(
            padding: EdgeInsets.only(bottom: hasVideo ? 12 : 0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _pickedImages.length > 1 ? 2 : 1,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 1.0,
              ),
              itemCount: _pickedImages.length,
              itemBuilder: (context, index) {
                final file = _pickedImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: kIsWeb
                            ? Image.network(
                          file.path,
                          fit: BoxFit.cover,
                        )
                            : Image.file(
                          File(file.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _pickedImages.removeAt(index);
                          });
                        },
                        child: CircleAvatar(
                          radius: _isDesktop(context) ? 18 : 15,
                          backgroundColor: cs.onSurface.withOpacity(0.6),
                          child: Icon(
                            Icons.close,
                            color: cs.surface,
                            size: _isDesktop(context) ? 20 : 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        if (hasVideo)
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 100,
                alignment: Alignment.center,
                color: cs.onPrimary.withOpacity(0.06),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_file,
                      size: _isDesktop(context) ? 50 : 40,
                      color: cs.onPrimary.withOpacity(0.95),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      path.basename(_pickedVideo!.name),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onPrimary.withOpacity(0.95),
                        fontSize: _isDesktop(context) ? 16 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _pickedVideo = null;
                      _videoController?.dispose();
                      _videoController = null;
                    });
                  },
                  child: CircleAvatar(
                    radius: _isDesktop(context) ? 18 : 15,
                    backgroundColor: cs.onSurface.withOpacity(0.6),
                    child: Icon(
                      Icons.close,
                      color: cs.surface,
                      size: _isDesktop(context) ? 20 : 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.primary,
      appBar: AppBar(
        title: Text(
          'Create New Post',
          style: TextStyle(
            color: cs.onPrimary,
            fontSize: _isDesktop(context) ? 20 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onPrimary),
      ),
      body: _buildResponsiveContent(
        SingleChildScrollView(
          padding: _getContentPadding(context),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.onPrimary.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: cs.onPrimary.withOpacity(0.9),
                        size: _isDesktop(context) ? 24 : 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Share content that aligns with your selected field of interest. This helps others connect with you more meaningfully and keeps CoPal vibrant and focused.',
                          style: TextStyle(
                            fontSize: _isDesktop(context) ? 14 : 13,
                            fontStyle: FontStyle.italic,
                            color: cs.onPrimary.withOpacity(0.95),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: _isDesktop(context) ? 30 : 25),
                DropdownButtonFormField<String>(
                  value: _selectedInterest,
                  items: _availableInterests.map((String interest) {
                    return DropdownMenuItem<String>(
                      value: interest,
                      child: Text(
                        interest,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: _isDesktop(context) ? 15 : 14,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedInterest = newValue;
                    });
                  },
                  decoration: InputDecoration(
                    labelStyle: TextStyle(
                      color: cs.onSurface.withOpacity(0.9),
                      fontSize: _isDesktop(context) ? 16 : 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: theme.dividerColor, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: cs.primary, width: 2.0),
                    ),
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: _isDesktop(context) ? 18 : 16,
                      horizontal: 18,
                    ),
                    hintText: 'Post To (Optional)',
                    hintStyle: TextStyle(
                      color: cs.onSurface.withOpacity(0.6),
                      fontSize: _isDesktop(context) ? 15 : 14,
                    ),
                  ),
                  icon: Icon(Icons.arrow_drop_down, color: cs.primary),
                ),
                SizedBox(height: _isDesktop(context) ? 25 : 20),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'What\'s on your mind?',
                    labelStyle: TextStyle(
                      color: cs.onSurface.withOpacity(0.9),
                      fontSize: _isDesktop(context) ? 17 : 16,
                    ),
                    alignLabelWithHint: true,
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: theme.dividerColor, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: cs.primary, width: 2.0),
                    ),
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: _isDesktop(context) ? 20 : 18,
                      horizontal: 18,
                    ),
                    hintText: 'Type your post...',
                    hintStyle: TextStyle(
                      color: cs.onSurface.withOpacity(0.6),
                      fontSize: _isDesktop(context) ? 15 : 14,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: _isDesktop(context) ? 16 : 15,
                    height: 1.4,
                    color: cs.onSurface,
                  ),
                  maxLines: _isDesktop(context) ? 8 : 7,
                  minLines: _isDesktop(context) ? 4 : 3,
                  onChanged: (value) {
                    _postContent = value;
                  },
                  validator: (value) {
                    if ((value == null || value.isEmpty) && _pickedImages.isEmpty && _pickedVideo == null) {
                      return 'Please enter some content or select media.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: _isDesktop(context) ? 30 : 25),
                Text(
                  'Add Photos or Videos',
                  style: TextStyle(
                    fontSize: _isDesktop(context) ? 20 : 18,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimary,
                  ),
                ),
                SizedBox(height: _isDesktop(context) ? 20 : 15),
                GestureDetector(
                  onTap: _showMediaPicker,
                  child: DottedBorder(
                    borderType: BorderType.RRect,
                    radius: const Radius.circular(15),
                    padding: const EdgeInsets.all(6),
                    dashPattern: const [8, 4],
                    color: cs.onPrimary.withOpacity(0.6),
                    strokeWidth: 1.5,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.onPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: _buildPickedMedia(),
                    ),
                  ),
                ),
                SizedBox(height: _isDesktop(context) ? 25 : 20),
                if (_isUploading)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: (_uploadProgress / 100).clamp(0.0, 1.0),
                        backgroundColor: cs.onPrimary.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Uploading media: ${_uploadProgress.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: _isDesktop(context) ? 15 : 14,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: _isDesktop(context) ? 25 : 20),
                Center(
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _savePost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.onPrimary,
                      foregroundColor: cs.primary,
                      padding: EdgeInsets.symmetric(
                        horizontal: _isDesktop(context) ? 40 : 30,
                        vertical: _isDesktop(context) ? 18 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUploading
                        ? Text(
                      'Posting...',
                      style: TextStyle(
                        fontSize: _isDesktop(context) ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                        : Text(
                      'Publish Post',
                      style: TextStyle(
                        fontSize: _isDesktop(context) ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}