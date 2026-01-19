// lib/messaging/media_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

// Media file wrapper to handle both mobile (File) and web (Uint8List) scenarios
class MediaFile {
  final File? file;           // For mobile platforms
  final Uint8List? bytes;     // For web platform
  final String name;          // File name
  final String? mimeType;     // MIME type (optional)

  MediaFile({
    this.file,
    this.bytes,
    required this.name,
    this.mimeType,
  }) : assert(file != null || bytes != null, 'Either file or bytes must be provided');

  bool get isWeb => bytes != null;
  bool get isMobile => file != null;
}

// The MediaService class handles all media-related operations,
// such as picking files from the device, uploading them to Firebase Storage,
// and managing local caching for offline access.
class MediaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

  // A generic method to pick a file from the device based on its type.
  // This method now properly handles both web and mobile platforms.
  Future<MediaFile?> pickFile(FileType fileType) async {
    try {
      if (kIsWeb) {
        // For web, use FilePicker for all file types
        final result = await FilePicker.platform.pickFiles(
          type: fileType,
          withData: true, // This is crucial for web - loads file bytes
        );

        if (result != null && result.files.isNotEmpty) {
          final platformFile = result.files.first;
          if (platformFile.bytes != null) {
            return MediaFile(
              bytes: platformFile.bytes!,
              name: platformFile.name,
              mimeType: platformFile.extension,
            );
          }
        }
      } else {
        // For mobile platforms
        if (fileType == FileType.image || fileType == FileType.video) {
          final picker = ImagePicker();
          // pickMedia allows selecting both images and videos from gallery/camera
          final pickedFile = await picker.pickMedia();
          if (pickedFile != null) {
            final file = File(pickedFile.path);
            return MediaFile(
              file: file,
              name: file.path.split('/').last,
              mimeType: pickedFile.mimeType,
            );
          }
        } else {
          // For audio and documents, use FilePicker to access device storage.
          final result = await FilePicker.platform.pickFiles(type: fileType);
          if (result != null && result.files.single.path != null) {
            final file = File(result.files.single.path!);
            return MediaFile(
              file: file,
              name: result.files.single.name,
              mimeType: result.files.single.extension,
            );
          }
        }
      }
    } catch (e) {
      print('Error picking file: $e');
    }
    return null;
  }

  // Uploads a file to Firebase Storage and returns its download URL.
  // This method now handles both File objects (mobile) and Uint8List (web).
  Future<String?> uploadFile(MediaFile mediaFile, String mediaType) async {
    try {
      final String fileName = '${_uuid.v4()}_${mediaFile.name}';
      // Store files in a structured way: chat_media/image/uuid_filename.jpg
      final Reference storageRef = _storage.ref().child('chat_media/$mediaType/$fileName');

      UploadTask uploadTask;

      if (mediaFile.isWeb && mediaFile.bytes != null) {
        // For web: upload bytes directly
        uploadTask = storageRef.putData(
          mediaFile.bytes!,
          SettableMetadata(
            contentType: _getContentType(mediaType, mediaFile.mimeType),
          ),
        );
      } else if (mediaFile.isMobile && mediaFile.file != null) {
        // For mobile: upload file
        uploadTask = storageRef.putFile(mediaFile.file!);
      } else {
        print('Invalid MediaFile: neither bytes nor file available');
        return null;
      }

      // Listen to the task to get the download URL once the upload is complete.
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('File uploaded successfully. URL: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Firebase Storage Error: $e');
      return null;
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }

  // Helper method to determine content type based on media type and extension
  String? _getContentType(String mediaType, String? extension) {
    if (extension == null) return null;

    switch (mediaType.toLowerCase()) {
      case 'image':
        switch (extension.toLowerCase()) {
          case 'jpg':
          case 'jpeg':
            return 'image/jpeg';
          case 'png':
            return 'image/png';
          case 'gif':
            return 'image/gif';
          case 'webp':
            return 'image/webp';
        }
        break;
      case 'video':
        switch (extension.toLowerCase()) {
          case 'mp4':
            return 'video/mp4';
          case 'mov':
            return 'video/quicktime';
          case 'avi':
            return 'video/x-msvideo';
          case 'webm':
            return 'video/webm';
        }
        break;
      case 'audio':
        switch (extension.toLowerCase()) {
          case 'mp3':
            return 'audio/mpeg';
          case 'wav':
            return 'audio/wav';
          case 'ogg':
            return 'audio/ogg';
          case 'm4a':
            return 'audio/mp4';
        }
        break;
    }
    return null;
  }

  // Caches a file from a given URL for offline access.
  Future<File?> cacheFile(String url) async {
    try {
      // Use the DefaultCacheManager to download and cache the file.
      // This will store the file locally and return its path.
      final File file = await _cacheManager.getSingleFile(url);
      print('File cached: ${file.path}');
      return file;
    } catch (e) {
      print('Error caching file from URL $url: $e');
      return null;
    }
  }

  // Retrieves a cached file from a given URL.
  Future<File?> getCachedFile(String url) async {
    try {
      // Check if the file is already in the cache.
      final FileInfo? fileInfo = await _cacheManager.getFileFromCache(url);
      if (fileInfo != null && fileInfo.file.existsSync()) {
        print('File retrieved from cache: ${fileInfo.file.path}');
        return fileInfo.file;
      }
      print('File not found in cache for URL: $url');
      return null;
    } catch (e) {
      print('Error retrieving cached file for URL $url: $e');
      return null;
    }
  }

  // Clears the entire cache. Use with caution.
  Future<void> clearCache() async {
    try {
      await _cacheManager.emptyCache();
      print('Cache cleared successfully.');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}