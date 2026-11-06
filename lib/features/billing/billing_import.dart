import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/services/api_service.dart';

/// Rows of an .xlsx or .csv file, as header -> value maps.
List<Map<String, dynamic>> readBillingFile(
  Uint8List bytes,
  String? extension,
) => extension?.toLowerCase() == 'csv' ? _readCsv(bytes) : _readXlsx(bytes);

/// What happened to an upload. [message] is ready to show.
class BillingUploadResult {
  const BillingUploadResult(this.message, {required this.saved});
  final String message;
  final bool saved;
}

/// Asks for a file and uploads it. Null if nothing was picked. The API checks
/// every row and saves all of them or none, keeping existing Paid totals.
Future<BillingUploadResult?> pickAndUploadBilling({
  void Function()? onPicked,
}) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx', 'csv'],
    withData: true,
  );
  final file = picked?.files.single;
  if (file == null) return null;
  onPicked?.call();
  final bytes = file.bytes;
  if (bytes == null) {
    return const BillingUploadResult("Couldn't read the file.", saved: false);
  }
  List<Map<String, dynamic>> rows;
  try {
    rows = readBillingFile(bytes, file.extension);
  } catch (_) {
    return const BillingUploadResult(
      "Couldn't read the file. Save it as .xlsx or .csv and try again.",
      saved: false,
    );
  }
  if (rows.isEmpty) {
    return const BillingUploadResult('The file has no rows.', saved: false);
  }
  final res = await ApiService.importBilling(rows, dryRun: false);
  if (res['status'] != 'success') {
    return BillingUploadResult(
      res['message']?.toString() ??
          "The import couldn't be saved. Nothing was changed.",
      saved: false,
    );
  }
  final data = res['data'];
  final counts = data is Map ? data['counts'] : null;
  if (counts is! Map) {
    return const BillingUploadResult('Billing imported', saved: true);
  }
  return BillingUploadResult(
    'Billing imported: ${counts['new'] ?? 0} new, '
    '${counts['update'] ?? 0} updated',
    saved: true,
  );
}

/// First sheet; the first row is the header. Values like the web's
/// sheet_to_json(defval: ''): text, numbers, and dates as YYYY-MM-DD.
List<Map<String, dynamic>> _readXlsx(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return [];
  final sheet = excel.tables[excel.tables.keys.first]!;
  if (sheet.rows.isEmpty) return [];
  final headers = [
    for (final c in sheet.rows.first)
      c?.value == null ? '' : '${_value(c!.value)}'.trim(),
  ];
  final out = <Map<String, dynamic>>[];
  for (final r in sheet.rows.skip(1)) {
    final row = <String, dynamic>{};
    var any = false;
    for (var i = 0; i < headers.length; i++) {
      if (headers[i].isEmpty) continue;
      final v = i < r.length && r[i]?.value != null ? _value(r[i]!.value) : '';
      if ('$v'.trim().isNotEmpty) any = true;
      row[headers[i]] = v;
    }
    if (any) out.add(row);
  }
  return out;
}

dynamic _value(CellValue? v) {
  if (v == null) return '';
  if (v is IntCellValue) return v.value;
  if (v is DoubleCellValue) return v.value;
  if (v is DateCellValue) {
    return DateFormat('yyyy-MM-dd').format(DateTime(v.year, v.month, v.day));
  }
  if (v is DateTimeCellValue) {
    return DateFormat('yyyy-MM-dd').format(DateTime(v.year, v.month, v.day));
  }
  if (v is BoolCellValue) return v.value;
  if (v is FormulaCellValue) return v.formula;
  return v.toString();
}

List<Map<String, dynamic>> _readCsv(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');
  final table = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(text.replaceAll('\r\n', '\n'));
  if (table.isEmpty) return [];
  final headers = table.first.map((h) => '$h'.trim()).toList();
  return [
    for (final r in table.skip(1))
      if (r.any((v) => '$v'.trim().isNotEmpty))
        {
          for (var i = 0; i < headers.length; i++)
            if (headers[i].isNotEmpty)
              headers[i]: i < r.length ? '${r[i]}' : '',
        },
  ];
}
