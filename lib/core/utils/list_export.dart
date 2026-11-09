import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/utils/sheet_export.dart';

/// Lets a home screen's app bar export what its list tab is showing. The tab
/// sets [loader]; the tab's search and filters are its own business.
class ListExportController {
  Future<List<Map<String, dynamic>>> Function()? loader;
}

/// Every row across all pages (a list screen may only have the first few
/// loaded). Throws rather than returning a partial list.
Future<List<Map<String, dynamic>>> fetchAllRows({
  required Future<Map<String, dynamic>> Function(int page, int limit) fetchPage,
  required String Function(Map<dynamic, dynamic> row) keyOf,
}) async {
  const limit = 100;
  final seen = <String>{};
  final all = <Map<String, dynamic>>[];
  for (var page = 1; ; page++) {
    final res = await fetchPage(page, limit);
    if (res['status'] != 'success') {
      throw Exception(res['message']?.toString() ?? 'Could not load the list');
    }
    final data = res['data'];
    if (data is! List || data.isEmpty) break;
    var added = 0;
    for (final row in data.whereType<Map>()) {
      if (seen.add(keyOf(row))) {
        all.add(Map<String, dynamic>.from(row));
        added++;
      }
    }
    // A server that repeats the last page must not loop forever.
    if (added == 0) break;
  }
  return all;
}

/// Saves the controller's rows as a dated Excel file, and says so if there
/// is nothing to save or it fails.
Future<void> runListExport(
  BuildContext context, {
  required ListExportController controller,
  required String emptyMessage,
  required String filePrefix,
  required String sheetName,
  required List<String> headers,
  required List<List<Object?>> Function(List<Map<String, dynamic>>) rowsOf,
}) async {
  final toast = AppToast.of(context);
  try {
    final load = controller.loader;
    if (load == null) {
      toast.showInfo('This list is still loading. Try again in a moment.');
      return;
    }
    await withExportOverlay(context, () async {
      final rows = await load();
      if (!context.mounted) return;
      if (rows.isEmpty) {
        toast.showInfo(emptyMessage);
        return;
      }
      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await exportSheets(context, '$filePrefix-$stamp.xlsx', [
        ExportSheet(sheetName, headers, rowsOf(rows)),
      ]);
    });
  } catch (e) {
    toast.showError(e.toString().replaceAll('Exception: ', ''));
  }
}

/// Export icon for the app bar, beside the notification bell.
class ListExportButton extends StatefulWidget {
  const ListExportButton({
    super.key,
    required this.controller,
    required this.tooltip,
    required this.emptyMessage,
    required this.filePrefix,
    required this.sheetName,
    required this.headers,
    required this.rowsOf,
  });

  final ListExportController controller;
  final String tooltip;
  final String emptyMessage;
  final String filePrefix;
  final String sheetName;
  final List<String> headers;
  final List<List<Object?>> Function(List<Map<String, dynamic>>) rowsOf;

  @override
  State<ListExportButton> createState() => _ListExportButtonState();
}

class _ListExportButtonState extends State<ListExportButton> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    await runListExport(
      context,
      controller: widget.controller,
      emptyMessage: widget.emptyMessage,
      filePrefix: widget.filePrefix,
      sheetName: widget.sheetName,
      headers: widget.headers,
      rowsOf: widget.rowsOf,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _busy ? null : _export,
      icon:
          _busy
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : const Icon(Icons.download_rounded, color: Colors.white),
    );
  }
}
