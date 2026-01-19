import 'package:flutter/material.dart';

class MediaDownloader {
  static Future<bool> requestMediaPermission({required String mediaType}) async {
    throw UnsupportedError("Media download not supported on this platform.");
  }

  static Future<void> downloadMedia(
      BuildContext context,
      String? mediaUrl,
      String? mediaType, // Updated parameter to match other versions
      ) async {
    throw UnsupportedError("Media download not supported on this platform.");
  }
}