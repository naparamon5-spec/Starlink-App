import 'dart:typed_data';

import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart'
    if (dart.library.io) 'file_downloader_io.dart';

/// Saves [bytes] as a file in a platform-appropriate way.
///
/// - **Web**: triggers a browser download and returns `null`.
/// - **Mobile/Desktop**: writes into system temp and returns the saved path.
Future<String?> saveBytesAsFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) =>
    saveBytesAsFileImpl(bytes: bytes, filename: filename, mimeType: mimeType);

