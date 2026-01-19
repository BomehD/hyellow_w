import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

Future<bool> requestMediaPermission({required String mediaType}) async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    int sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      // Android 13+ permissions
      Permission permission;
      if (mediaType == 'image') {
        permission = Permission.photos;
      } else if (mediaType == 'video') {
        permission = Permission.videos;
      } else if (mediaType == 'audio') {
        // Correct permission for audio
        permission = Permission.audio;
        var status = await permission.request();
        return status.isGranted;
      } else {
        // FIX: For documents and other non-media files, a runtime
        // permission is not required on Android 13+ to write to
        // the 'Downloads' directory, so we can return true directly.
        return true;
      }
    } else {
      // Older Android, storage permission is sufficient
      var storage = await Permission.storage.request();
      return storage.isGranted;
    }
  } else if (Platform.isIOS) {
    if (mediaType == 'image' || mediaType == 'video') {
      var photos = await Permission.photos.request();
      return photos.isGranted;
    }
    // For audio and documents on iOS, no explicit permission is needed as they are saved in the app sandbox
    return true;
  }

  return false;
}
