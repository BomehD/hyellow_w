// lib/util/media_downloader_web.dart
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';

class MediaDownloader {
  /// NOTE: This is the web-specific implementation.
  /// It does not require any permission handling or special
  /// directory logic, as downloads are managed by the browser.
  static Future<void> downloadMedia(
      BuildContext context,
      String? mediaUrl,
      String? mediaType,
      ) async {
    if (mediaUrl == null || mediaUrl.isEmpty) {
      _showSnackBar(context, 'No media to download.');
      return;
    }

    _showSnackBar(context, 'Starting download...');

    try {
      // For web, we don't need permissions.
      // We trigger the download directly using an anchor element.
      debugPrint('⬇ Starting web download from: $mediaUrl');

      // Create a temporary anchor element
      final anchor = html.AnchorElement(href: mediaUrl)
        ..setAttribute('download', mediaUrl.split('/').last)
        ..style.display = 'none';

      // Add the anchor element to the document body
      html.document.body!.children.add(anchor);

      // Programmatically click the anchor to trigger the download
      anchor.click();

      // Clean up the anchor element
      anchor.remove();

      _showSnackBar(context, 'Download complete!');
      debugPrint('✅ Web download initiated successfully.');
    } catch (e) {
      debugPrint('💥 Web download error: $e');
      _showSnackBar(context, 'An error occurred while downloading.');
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

}
