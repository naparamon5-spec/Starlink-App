import 'dart:typed_data';

Future<String?> saveBytesAsFileImpl({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  throw UnsupportedError('saveBytesAsFile is not supported on this platform.');
}
