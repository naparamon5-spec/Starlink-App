import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:starlink_app/core/utils/file_download/file_downloader_stub.dart'
    if (dart.library.html) 'package:starlink_app/core/utils/file_download/file_downloader_web.dart'
    if (dart.library.io) 'package:starlink_app/core/utils/file_download/file_downloader_io.dart';

/// Saves [bytes] as a file in a platform-appropriate way.
///
/// - **Web**: triggers a browser download and returns `null`.
/// - **Android**: writes to the public Downloads folder.
/// - **iOS**: writes to Documents, which the Files app shows.
///
/// Returns the saved path, or `null` when it couldn't be written.
Future<String?> saveBytesAsFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) =>
    saveBytesAsFileImpl(bytes: bytes, filename: filename, mimeType: mimeType);

/// Where the user can find a file saved at [path], for messages.
String savedLocationLabel(String path) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return 'the Files app, in the Ardent Dashboard folder';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'your Downloads folder';
  }
  return path;
}

