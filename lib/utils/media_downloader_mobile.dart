// lib/util/media_downloader.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaDownloader {
  /// Handles permission requests based on Android version and media type
  static Future<bool> _requestPermissions(String mediaType) async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13+ (Tiramisu) uses granular permissions
        Permission permission;
        if (mediaType == 'video') {
          permission = Permission.videos;
        } else if (mediaType == 'image') {
          permission = Permission.photos;
        } else if (mediaType == 'audio') {
          // CORRECT: Use the specific audio permission for Android 13+
          permission = Permission.audio;
          final status = await permission.request();
          // Check if permission is permanently denied to guide the user to settings
          if (status.isPermanentlyDenied) {
            return await _showPermissionSettingsDialog();
          }
          return status.isGranted;
        } else {
          // CORRECT: For documents and other non-media files on Android 13+,
          // a runtime permission is not required to write to the 'Downloads'
          // directory. The manifest declaration is sufficient.
          return true;
        }
        final status = await permission.request();
        if (status.isPermanentlyDenied) {
          return await _showPermissionSettingsDialog();
        }
        if (!status.isGranted) return false;
      } else {
        // Android 12 and below, storage permission is sufficient
        final status = await Permission.storage.request();
        if (!status.isGranted) return false;
      }
    }

    // iOS + PhotoManager-specific permission for photos/videos
    if (mediaType == 'image' || mediaType == 'video') {
      final status = await PhotoManager.requestPermissionExtend();
      if (!status.isAuth && status != PermissionState.limited) return false;
    }

    // For iOS, storage permission for other files is not needed as they are handled in the app sandbox
    return true;
  }

  static Future<void> downloadMedia(
      BuildContext context,
      String? mediaUrl,
      String? mediaType,
      ) async {
    if (mediaUrl == null || mediaUrl.isEmpty) {
      _showSnackBar(context, 'No media to download.');
      return;
    }

    // Determine permissions to request based on media type
    final hasPermissions = await _requestPermissions(mediaType ?? 'any');
    if (!hasPermissions) {
      _showSnackBar(context, 'Permission denied. Please allow access.');
      debugPrint('❌ Permission request failed.');
      return;
    }

    final progressController = StreamController<double>();
    _showProgressBar(context, 'Downloading...', progressController.stream);

    try {
      debugPrint('⬇ Starting download from: $mediaUrl');
      final request = http.Request('GET', Uri.parse(mediaUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        _showSnackBar(context, 'Download failed: ${response.statusCode}');
        debugPrint('❌ HTTP error: ${response.statusCode}');
        progressController.close();
        return;
      }

      final contentLength = response.contentLength ?? 0;
      int bytesReceived = 0;

      // FIX: Properly extract only the filename, without the directory path from the URL.
      String urlFileName = Uri.decodeComponent(Uri.parse(mediaUrl).pathSegments.last).split('?').first;
      String fileName = urlFileName.split('/').last;

      if (fileName.isEmpty) fileName = 'file_${DateTime.now().millisecondsSinceEpoch}';

      switch (mediaType) {
        case 'image':
        case 'video':
        // For images and videos, use PhotoManager to save to gallery
          final buffer = <int>[];
          await for (final chunk in response.stream) {
            bytesReceived += chunk.length;
            buffer.addAll(chunk);
            if (contentLength > 0) {
              progressController.add(bytesReceived / contentLength);
            }
          }
          Uint8List uint8Buffer = Uint8List.fromList(buffer);

          AssetEntity? savedFile;
          if (mediaType == 'image') {
            savedFile = await PhotoManager.editor.saveImage(
              uint8Buffer,
              title: fileName,
              filename: fileName,
              relativePath: 'Pictures/HYellow Posts',
            );
          } else {
            // Write video to temp file before saving with PhotoManager
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/$fileName');
            await tempFile.writeAsBytes(uint8Buffer);
            savedFile = await PhotoManager.editor.saveVideo(
              tempFile,
              title: fileName,
              relativePath: 'Movies/HYellow Posts',
            );
          }

          if (savedFile != null) {
            _showSnackBar(context, 'Media saved to gallery successfully!');
            debugPrint('✅ Saved asset ID: ${savedFile.id}');
          } else {
            _showSnackBar(context, 'Failed to save media to gallery.');
            debugPrint('❌ Failed to save media — PhotoManager returned null.');
          }
          break;
        case 'audio':
        case 'document':
        case 'any':
        default:
          Directory? baseDir;
          if (Platform.isAndroid) {
            // On Android, we will save to the public 'Download' directory.
            // This is a more reliable and accessible location for the user.
            baseDir = Directory('/storage/emulated/0/Download');
          } else {
            // On iOS, we will continue to use the application's document directory.
            baseDir = await getApplicationDocumentsDirectory();
          }

          if (baseDir == null) {
            _showSnackBar(context, 'Could not find a valid save directory.');
            progressController.close();
            return;
          }

          final subDirName = mediaType == 'audio' ? 'chat_media/audio' : 'chat_media/documents';
          final saveDir = Directory('${baseDir.path}/Hyellow/$subDirName');

          if (!await saveDir.exists()) {
            await saveDir.create(recursive: true);
          }

          // Get a unique file name to avoid overwriting existing files
          String uniqueName = fileName;
          final noExt = uniqueName.contains('.') ? uniqueName.substring(0, uniqueName.lastIndexOf('.')) : uniqueName;
          final ext = uniqueName.contains('.') ? uniqueName.substring(uniqueName.lastIndexOf('.')) : '';
          int i = 1;
          while (await File('${saveDir.path}/$uniqueName').exists()) {
            uniqueName = '$noExt ($i)$ext';
            i++;
          }

          final finalFile = File('${saveDir.path}/$uniqueName');
          final sink = finalFile.openWrite();
          await for (final chunk in response.stream) {
            bytesReceived += chunk.length;
            sink.add(chunk);
            if (contentLength > 0) {
              progressController.add(bytesReceived / contentLength);
            }
          }
          await sink.close();

          _showSnackBar(context, 'File downloaded to: ${finalFile.path}');
          debugPrint('✅ Saved file to: ${finalFile.path}');
          break;
      }

      progressController.close();
    } catch (e, stack) {
      progressController.close();
      debugPrint('💥 Download error: $e');
      debugPrint('$stack');
      _showSnackBar(context, 'An error occurred while downloading.');
    }
  }



  static Future<bool> _showPermissionSettingsDialog() async {
    return await launchUrl(Uri.parse('app-settings:'));
  }

  static void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static void _showProgressBar(
      BuildContext context,
      String message,
      Stream<double> progressStream,
      ) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5),
        content: StreamBuilder<double>(
          stream: progressStream,
          initialData: 0,
          builder: (context, snapshot) {
            final progress = (snapshot.data ?? 0).clamp(0.0, 1.0);
            final percent = (progress * 100).toStringAsFixed(0);

            // Auto-dismiss when progress reaches 100%
            if (progress >= 1.0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                }
              });
            }

            return Row(
              children: [
                Expanded(child: Text('$message ($percent%)')),
                const SizedBox(width: 20),
                SizedBox(
                  height: 5,
                  width: 100,
                  child: LinearProgressIndicator(value: progress),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}