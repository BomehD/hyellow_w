import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;

class DownloadProfileImage {
  static Future<void> downloadAndSaveImage(
      BuildContext context, String imageUrl) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    const String filename = 'hyellow_profile_image.jpg';

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Downloading image...')),
    );

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image.');
      }

      // --- Web-specific logic ---
      final blob = html.Blob([response.bodyBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();

      html.Url.revokeObjectUrl(url);

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Profile image downloaded!')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to download image: $e')),
      );
    }
  }
}