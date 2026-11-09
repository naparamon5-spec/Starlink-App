import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/file_download/file_downloader.dart';

/// One sheet of an export: a header row and data rows.
class ExportSheet {
  const ExportSheet(this.name, this.headers, this.rows);
  final String name;
  final List<String> headers;
  final List<List<Object?>> rows;
}

bool _exporting = false;

/// Covers the whole app with an "Exporting…" spinner until [task] finishes, so
/// nothing can be tapped meanwhile. Nested calls share the outer overlay.
Future<void> withExportOverlay(
  BuildContext context,
  Future<void> Function() task,
) async {
  if (_exporting) return task();
  _exporting = true;
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (_) => const _ExportOverlay(),
  );
  navigator.push(route);
  try {
    // Building a large workbook blocks the UI, so paint the spinner first.
    await WidgetsBinding.instance.endOfFrame;
    await task();
  } finally {
    _exporting = false;
    // A sign-out during the export may already have removed it.
    if (navigator.mounted && route.isActive) navigator.removeRoute(route);
  }
}

class _ExportOverlay extends StatelessWidget {
  const _ExportOverlay();

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Center(
      child: Material(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Exporting…',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Please wait while your file is saved.',
                style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Builds an .xlsx from [sheets], saves it like other downloads in the app,
/// and tells the user where it went. Mirrors the web portal's Excel exports.
Future<void> exportSheets(
  BuildContext context,
  String filename,
  List<ExportSheet> sheets,
) async {
  final toast = AppToast.of(context);
  try {
    String? path;
    await withExportOverlay(context, () async {
      path = await saveBytesAsFile(
        bytes: Uint8List.fromList(buildWorkbook(sheets)),
        filename: filename,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });
    final saved = path;
    // The web build downloads and returns no path; on a phone no path means
    // the file couldn't be written.
    toast.showResult(saved != null
              ? 'Saved ${saved.split('/').last} to ${savedLocationLabel(saved)}'
              : kIsWeb
              ? 'Export downloaded'
              : "Couldn't save $filename. Check storage access and try again.", ok: saved != null || kIsWeb);
  } catch (e) {
    toast.showError('Export failed: ${e.toString()}');
  }
}

/// The .xlsx bytes for [sheets].
List<int> buildWorkbook(List<ExportSheet> sheets) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  final names = <String>[];
  for (final s in sheets) {
    final name = _sheetName(s.name);
    names.add(name);
    final sheet = excel[name];
    sheet.appendRow([for (final h in s.headers) _cell(h)]);
    for (final r in s.rows) {
      sheet.appendRow([for (final v in r) _cell(v)]);
    }
  }
  if (defaultSheet != null && !names.contains(defaultSheet)) {
    excel.delete(defaultSheet);
  }
  final bytes = excel.encode();
  if (bytes == null) throw Exception('Could not build the file');
  return bytes;
}

// Excel refuses to open a file that breaks these limits.
const _maxSheetName = 31;
const _maxCellText = 32767;
final _sheetNameIllegal = RegExp(r'[\[\]:*?/\\]');
final _xmlIllegal = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F￾￿]');

String _sheetName(String raw) {
  final name = raw.replaceAll(_sheetNameIllegal, ' ').trim();
  if (name.isEmpty) return 'Sheet';
  return name.length > _maxSheetName ? name.substring(0, _maxSheetName) : name;
}

CellValue? _cell(Object? v) {
  if (v == null) return null;
  if (v is int) return IntCellValue(v);
  if (v is num) return v.isFinite ? DoubleCellValue(v.toDouble()) : null;
  if (v is bool) return BoolCellValue(v);
  final text = v.toString().replaceAll(_xmlIllegal, '');
  return TextCellValue(
    text.length > _maxCellText ? text.substring(0, _maxCellText) : text,
  );
}
