import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<String?> saveBytesAsFileImpl({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  try {
    final file = await _resolveFile(filename);
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('[FileDownloader] Saved to: ${file.path}');
    return file.path;
  } catch (e) {
    debugPrint('[FileDownloader] Error saving file: $e');
    return null;
  }
}

// ── Platform file resolution ──────────────────────────────────────────────────

Future<File> _resolveFile(String filename) async {
  final safe = _sanitizeFilename(filename);

  if (Platform.isAndroid) {
    return _resolveAndroid(safe);
  }

  if (Platform.isIOS) {
    return _resolveIos(safe);
  }

  // macOS / Linux / Windows
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return _uniqueFile(downloads.path, safe);
    }
  } catch (_) {}

  final docs = await getApplicationDocumentsDirectory();
  return _uniqueFile(docs.path, safe);
}

// ── Android ───────────────────────────────────────────────────────────────────
//
// Target: /storage/emulated/0/Download/<filename>
// This is the standard public Downloads folder — visible in the Files app
// and accessible by any file manager.
//
// Android 9 and below : needs WRITE_EXTERNAL_STORAGE permission.
// Android 10+         : no permission needed for public Downloads folder.
// Android 13+         : WRITE_EXTERNAL_STORAGE is permanently denied but
//                       writing to /storage/emulated/0/Download still works.
Future<File> _resolveAndroid(String filename) async {
  // Request legacy write permission for Android <= 9.
  // On Android 10+ this is a no-op.
  final status = await Permission.storage.request();
  if (status.isPermanentlyDenied) {
    debugPrint(
      '[FileDownloader] Storage permission permanently denied, '
      'falling back to internal storage.',
    );
    return _resolveAndroidInternal(filename);
  }

  // Standard public Downloads path — always present on real devices.
  const publicDownloads = '/storage/emulated/0/Download';
  final dir = Directory(publicDownloads);

  if (await dir.exists()) {
    return _uniqueFile(publicDownloads, filename);
  }

  // Emulator / rare device: try getExternalStorageDirectory but only if it
  // resolves to emulated storage (never SD card / 0000-0000).
  try {
    final ext = await getExternalStorageDirectory();
    if (ext != null && ext.path.contains('emulated')) {
      final parts = ext.path.split('/');
      final idx = parts.indexOf('emulated');
      if (idx >= 0 && parts.length > idx + 1) {
        final base = parts.sublist(0, idx + 2).join('/');
        final downloadsDir = Directory('$base/Download');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return _uniqueFile(downloadsDir.path, filename);
      }
    }
  } catch (_) {}

  return _resolveAndroidInternal(filename);
}

/// Internal fallback when public storage is unavailable.
Future<File> _resolveAndroidInternal(String filename) async {
  final appFiles = await getApplicationSupportDirectory();
  final dir = Directory('${appFiles.path}/Downloads');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return _uniqueFile(dir.path, filename);
}

// ── iOS ───────────────────────────────────────────────────────────────────────
//
// iOS has no shared public Downloads folder.
// Documents directory is visible in Files app under "On My iPhone → <AppName>"
// when your Info.plist contains:
//   UIFileSharingEnabled  = YES
//   LSSupportsOpeningDocumentsInPlace = YES
Future<File> _resolveIos(String filename) async {
  final docs = await getApplicationDocumentsDirectory();
  return _uniqueFile(docs.path, filename);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns a [File] that does not yet exist, appending _1, _2 … as needed.
File _uniqueFile(String dirPath, String filename) {
  var file = File('$dirPath/$filename');
  if (!file.existsSync()) return file;

  final dot = filename.lastIndexOf('.');
  final base = dot >= 0 ? filename.substring(0, dot) : filename;
  final ext = dot >= 0 ? filename.substring(dot) : '';

  var counter = 1;
  while (file.existsSync()) {
    file = File('$dirPath/${base}_$counter$ext');
    counter++;
  }
  return file;
}

/// Strips characters that are illegal in file names on common OSes.
String _sanitizeFilename(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'download';
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|\x00]'), '_');
}
