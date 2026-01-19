import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:path/path.dart' as path;

class EditPostScreen extends StatefulWidget {
  final String postId;
  final String initialContent;
  final String? initialImageUrl;
  final String? initialVideoUrl;
  final List<String>? initialImageUrls;

  const EditPostScreen({
    super.key,
    required this.postId,
    required this.initialContent,
    this.initialImageUrl,
    this.initialVideoUrl,
    this.initialImageUrls,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _contentController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoading = false;
  bool _isUploadingMedia = false;
  VideoPlayerController? _videoController;

  List<String> _initialImageUrls = [];
  List<XFile> _newPickedImages = [];
  XFile? _newPickedVideo;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);

    _initialImageUrls = widget.initialImageUrls ?? [];
    if (widget.initialImageUrl != null) {
      if (!_initialImageUrls.contains(widget.initialImageUrl!)) {
        _initialImageUrls.add(widget.initialImageUrl!);
      }
    }

    if (widget.initialVideoUrl != null) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.initialVideoUrl!))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
          }
        });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  double _getContentWidth(double screenWidth) {
    if (screenWidth >= 1200) {
      return 800;
    } else if (screenWidth >= 800) {
      return screenWidth * 0.75;
    } else {
      return screenWidth;
    }
  }

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
                    fontSize: 18,
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
            fontSize: 14,
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

  Future<void> _pickMediaFromSource(ImageSource source, {required bool isImage}) async {
    if (isImage) {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newPickedImages.addAll(pickedFiles);
        });
      }
    } else {
      if (widget.initialVideoUrl != null || _newPickedVideo != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please remove the existing video before adding a new one.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      final XFile? pickedFile = await _picker.pickVideo(source: source);
      if (pickedFile != null) {
        setState(() {
          _newPickedVideo = pickedFile;
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
  }

  Future<String?> _uploadFile(XFile file, String path) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final Reference storageRef = _storage.ref().child(path).child(fileName);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload media: $e')),
        );
      }
      return null;
    }
  }

  // UPDATED: Now performs file uploads concurrently
  Future<void> _saveChanges() async {
    if (!mounted || _currentUser == null) return;

    setState(() {
      _isLoading = true;
      _isUploadingMedia = _newPickedImages.isNotEmpty || _newPickedVideo != null;
    });

    try {
      final updatedContent = _contentController.text.trim();
      final Map<String, dynamic> updates = {
        'content': updatedContent,
        'lastModified': FieldValue.serverTimestamp(),
      };

      // Create a list of futures for all image uploads
      final List<Future<String?>> uploadImageFutures = _newPickedImages
          .map((file) => _uploadFile(file, 'post_media/${_currentUser!.uid}/images'))
          .toList();

      // Wait for all image uploads to complete concurrently
      final List<String?> uploadedImageUrls = (await Future.wait(uploadImageFutures)).whereType<String>().toList();

      // Combine initial URLs with the newly uploaded ones
      final finalImageUrls = [..._initialImageUrls, ...uploadedImageUrls];

      // Handle video upload separately as it's a single file
      String? finalVideoUrl;
      if (_newPickedVideo != null) {
        finalVideoUrl = await _uploadFile(_newPickedVideo!, 'post_media/${_currentUser!.uid}/videos');
      } else {
        // If the user removed the video but didn't add a new one, delete the field.
        finalVideoUrl = widget.initialVideoUrl;
      }

      // Explicitly set or delete imageUrls and videoUrl
      if (finalImageUrls.isNotEmpty) {
        updates['imageUrls'] = finalImageUrls;
      } else {
        updates['imageUrls'] = FieldValue.delete();
      }

      // Handle the video field, removing it if the user deleted the video.
      if (_newPickedVideo != null) {
        updates['videoUrl'] = finalVideoUrl;
      } else if (widget.initialVideoUrl != null && _newPickedVideo == null) {
        updates['videoUrl'] = FieldValue.delete();
      } else {
        updates['videoUrl'] = widget.initialVideoUrl;
      }

      // Handle the legacy 'imageUrl' field for backward compatibility, if it exists.
      updates['imageUrl'] = FieldValue.delete();

      await _firestore.collection('posts').doc(widget.postId).update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingMedia = false;
        });
      }
    }
  }

  Widget _buildMediaPreview() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool hasImages = _initialImageUrls.isNotEmpty || _newPickedImages.isNotEmpty;
    final bool hasVideo = widget.initialVideoUrl != null || _newPickedVideo != null;

    if (!hasImages && !hasVideo) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 50, color: cs.onSurface.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text(
              'Tap to upload image(s) or video',
              style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasImages)
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _initialImageUrls.length + _newPickedImages.length,
              itemBuilder: (context, index) {
                final isInitialImage = index < _initialImageUrls.length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 150,
                          height: 150,
                          child: isInitialImage
                              ? Image.network(_initialImageUrls[index], fit: BoxFit.cover)
                              : Image.file(File(_newPickedImages[index - _initialImageUrls.length].path), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isInitialImage) {
                                _initialImageUrls.removeAt(index);
                              } else {
                                _newPickedImages.removeAt(index - _initialImageUrls.length);
                              }
                            });
                          },
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: cs.onSurface.withOpacity(0.6),
                            child: Icon(Icons.close, color: cs.surface, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        if (hasImages && hasVideo)
          const SizedBox(height: 16),

        if (hasVideo)
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _videoController != null && _videoController!.value.isInitialized
                    ? AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
                    : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ondemand_video, size: 80, color: cs.onSurface.withOpacity(0.6)),
                      const SizedBox(height: 8),
                      Text(
                        'Video attached',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
              ),
              if (_videoController != null && _videoController!.value.isInitialized)
                Positioned.fill(
                  child: Center(
                    child: IconButton(
                      icon: Icon(
                        _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        size: 64,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                        });
                      },
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _newPickedVideo = null;
                      _videoController?.dispose();
                      _videoController = null;
                    });
                  },
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: cs.onSurface.withOpacity(0.6),
                    child: Icon(Icons.close, color: cs.surface, size: 18),
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = _getContentWidth(screenWidth);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Edit Post',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          _isLoading || _isUploadingMedia
              ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colorScheme.primary),
              ),
            ),
          )
              : IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: contentWidth,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2), width: 1),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Post Content',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contentController,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: 'What\'s on your mind?',
                            hintStyle: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.5)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.teal),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              const BorderSide(color: Colors.teal, width: 2.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              const BorderSide(color: Colors.teal, width: 1.0),
                            ),
                            fillColor: colorScheme.background,
                            filled: true,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2), width: 1),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Media Attachments',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: _showMediaPicker,
                          child: DottedBorder(
                            borderType: BorderType.RRect,
                            radius: const Radius.circular(15),
                            padding: const EdgeInsets.all(6),
                            dashPattern: const [8, 4],
                            color: colorScheme.onSurface.withOpacity(0.6),
                            strokeWidth: 1.5,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: _buildMediaPreview(),
                            ),
                          ),
                        ),
                      ],
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