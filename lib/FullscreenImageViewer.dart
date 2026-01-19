// lib/full_screen_image_viewer.dart
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:hyellow_w/utils/download_profile_image.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Wrap PhotoView with a GestureDetector to detect long-press
          GestureDetector(
            onLongPress: () {
              // Call the download function on long press
              DownloadProfileImage.downloadAndSaveImage(context, imageUrl);
            },
            child: PhotoView(
              imageProvider: NetworkImage(imageUrl),
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale: PhotoViewComputedScale.covered * 2,
              heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
            ),
          ),
          // Positioned close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}