import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/utils/file_download/file_downloader.dart';

/// One sheet of an export: a header row and data rows.
class ExportSheet {
  const ExportSheet(this.name, this.headers, this.rows);
  final String name;
  final List<String> headers;
  final List<List<Object?>> rows;
}

/// Builds an .xlsx from [sheets], saves it like other downloads in the app,
/// and tells the user where it went. Mirrors the web portal's Excel exports.
Future<void> exportSheets(
  BuildContext context,
  String filename,
  List<ExportSheet> sheets,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    for (final s in sheets) {
      final sheet = excel[s.name];
      sheet.appendRow([for (final h in s.headers) TextCellValue(h)]);
      for (final r in s.rows) {
        sheet.appendRow([for (final v in r) _cell(v)]);
      }
    }
    if (defaultSheet != null && !sheets.any((s) => s.name == defaultSheet)) {
      excel.delete(defaultSheet);
    }
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Could not build the file');
    final path = await saveBytesAsFile(
      bytes: Uint8List.fromList(bytes),
      filename: filename,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'Export downloaded' : 'Saved $filename to $path',
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Export failed: ${e.toString()}')),
    );
  }
}

CellValue? _cell(Object? v) {
  if (v == null) return null;
  if (v is int) return IntCellValue(v);
  if (v is double) return DoubleCellValue(v);
  if (v is num) return DoubleCellValue(v.toDouble());
  if (v is bool) return BoolCellValue(v);
  return TextCellValue(v.toString());
}
