import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class DownloadProfileImage {
  static Future<void> downloadAndSaveImage(
      BuildContext context, String imageUrl) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    const String filename = 'hyellow_profile_image.jpg';

    // 1. Request Photos permission
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text('Permission to save media is required.')),
      );
      return;
    }

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Downloading image...')),
    );

    try {
      // 2. Download the image from the URL
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image.');
      }

      // 3. Save the image to the gallery using photo_manager with the byte data
      final result = await PhotoManager.editor.saveImage(
        response.bodyBytes,
        filename: filename,
      );

      // 4. Check the result from photo_manager
      if (result != null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Profile image saved to gallery!')),
        );
      } else {
        throw Exception('Failed to save image to gallery.');
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to download image: $e')),
      );
    }
  }
}