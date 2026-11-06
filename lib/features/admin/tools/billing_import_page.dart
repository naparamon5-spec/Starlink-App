import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle, TextSpan;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// Billing import (admins) — the web portal's Import: read an Excel (.xlsx)
/// or CSV file, let the API check every row (POST /billing/import dryRun:
/// nothing saved), show what would be new / updated / unchanged / wrong,
/// then save all rows or none.
class BillingImportPage extends StatefulWidget {
  const BillingImportPage({super.key});

  @override
  State<BillingImportPage> createState() => _BillingImportPageState();
}

const _statusInfo = {
  'new': ('New', AppColors.success),
  'update': ('Update', AppColors.info),
  'unchanged': ('No change', AppColors.inkFaint),
  'error': ('Problem', AppColors.brand),
};

class _BillingImportPageState extends State<BillingImportPage> {
  String? _fileName;
  List<Map<String, dynamic>>? _rows;
  Map<String, dynamic>? _plan;
  bool _checking = false;
  bool _saving = false;
  String? _error;
  String _filter = 'all';

  Map<String, int> get _counts {
    final c = _plan?['counts'];
    int n(String k) => c is Map ? int.tryParse('${c[k] ?? 0}') ?? 0 : 0;
    return {for (final k in _statusInfo.keys) k: n(k)};
  }

  List<String> get _fileErrors =>
      ((_plan?['fileErrors'] as List?) ?? const []).map((e) => '$e').toList();

  int get _problems => _counts['error']! + _fileErrors.length;
  int get _toSave => _counts['new']! + _counts['update']!;

  List<Map<String, dynamic>> get _planRows =>
      ((_plan?['rows'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = "Couldn't read the file.");
      return;
    }
    List<Map<String, dynamic>> rows;
    try {
      rows =
          file.extension?.toLowerCase() == 'csv'
              ? _readCsv(bytes)
              : _readXlsx(bytes);
    } catch (e) {
      setState(() {
        _fileName = file.name;
        _rows = null;
        _plan = null;
        _error =
            "Couldn't read the file. Save it as .xlsx or .csv and try again.";
      });
      return;
    }
    setState(() {
      _fileName = file.name;
      _rows = rows;
      _plan = null;
      _error = rows.isEmpty ? 'The file has no rows.' : null;
    });
    if (rows.isNotEmpty) _check();
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
        final v =
            i < r.length && r[i]?.value != null ? _value(r[i]!.value) : '';
        if ('$v'.trim().isNotEmpty) any = true;
        row[headers[i]] = v;
      }
      if (any) out.add(row);
    }
    return out;
  }

  static dynamic _value(CellValue? v) {
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

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      _plan = null;
    });
    final res = await ApiService.importBilling(_rows!, dryRun: true);
    if (!mounted) return;
    final data = res['data'];
    setState(() {
      _checking = false;
      if (res['status'] == 'success' && data is Map) {
        _plan = Map<String, dynamic>.from(data);
        _filter = _counts['error']! > 0 ? 'error' : 'all';
      } else {
        _error = res['message']?.toString() ?? "The file couldn't be checked.";
      }
    });
  }

  Future<void> _save() async {
    if (_rows == null || _problems > 0 || _toSave == 0) return;
    setState(() => _saving = true);
    final res = await ApiService.importBilling(_rows!, dryRun: false);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['status'] == 'success') {
      final c = _counts;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Billing imported: ${c['new']} new, ${c['update']} updated',
          ),
        ),
      );
      Navigator.pop(context, true);
      return;
    }
    // A 400 carries the up-to-date check (records may have changed meanwhile).
    final raw = res['raw'];
    if (raw is Map && raw['data'] is Map) {
      setState(() => _plan = Map<String, dynamic>.from(raw['data']));
    }
    setState(
      () =>
          _error =
              res['message']?.toString() ??
              "The import couldn't be saved. Nothing was changed.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        _planRows
            .where((r) => _filter == 'all' || r['status'] == _filter)
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Import Billing')),
      bottomNavigationBar:
          _plan == null
              ? null
              : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ElevatedButton(
                    onPressed:
                        _problems > 0 || _toSave == 0 || _saving ? null : _save,
                    child:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              _problems > 0
                                  ? 'Fix the problems to import'
                                  : _toSave == 0
                                  ? 'Nothing to import'
                                  : 'Import $_toSave record${_toSave == 1 ? '' : 's'}',
                            ),
                  ),
                ),
              ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Columns: Customer Code, CPO #, SI/DR #, CPO Date, SI/DR Date, Amount, Paid. '
                  'Dates as YYYY-MM-DD or MM/DD/YYYY. Existing records keep their Paid total; '
                  'nothing is saved while any row has a problem.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _checking || _saving ? null : _pick,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(
                    _fileName == null
                        ? 'Choose .xlsx or .csv file'
                        : 'Choose another file',
                  ),
                ),
                if (_fileName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$_fileName${_rows == null ? '' : ' · ${_rows!.length} row${_rows!.length == 1 ? '' : 's'}'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_checking) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Checking every row…',
                style: TextStyle(color: AppColors.inkMuted),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.dangerInk,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
          if (_plan != null) ...[
            const SizedBox(height: 16),
            for (final e in _fileErrors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• $e',
                  style: const TextStyle(
                    color: AppColors.dangerInk,
                    fontSize: 12.5,
                  ),
                ),
              ),
            PillChips<String>(
              options: [
                PillOption('all', 'All', count: _planRows.length),
                for (final e in _statusInfo.entries)
                  PillOption(
                    e.key,
                    e.value.$1,
                    count: _counts[e.key],
                    dotColor: e.value.$2,
                  ),
              ],
              selected: _filter,
              onSelected: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 10),
            for (final r in rows.take(300)) _rowTile(r),
            if (rows.length > 300)
              Text(
                'Showing 300 of ${rows.length} rows.',
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
          ],
        ],
      ),
    );
  }

  Widget _rowTile(Map<String, dynamic> r) {
    final info = _statusInfo[r['status']] ?? ('—', AppColors.inkFaint);
    final errors =
        ((r['errors'] as List?) ?? const []).map((e) => '$e').toList();
    final changes =
        ((r['changes'] as List?) ?? const []).whereType<Map>().toList();
    final money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    String amt(dynamic v) =>
        num.tryParse('${v ?? ''}') == null
            ? '—'
            : money.format(num.parse('$v'));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Line ${r['line']}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.inkFaint,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: info.$2.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  info.$1.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: info.$2,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                amt(r['amount']),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              r['customer_name'] ?? r['customer_code'],
              'CPO ${r['cpo_number'] ?? '—'}',
              'SI/DR ${r['sidr_number'] ?? '—'}',
            ].where((e) => '${e ?? ''}'.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• $e',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.dangerInk,
                ),
              ),
            ),
          for (final c in changes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                c['field'] == 'amount'
                    ? 'Amount ${amt(c['from'])} → ${amt(c['to'])}'
                    : '${c['field'] == 'cpo_date' ? 'CPO date' : 'SI/DR date'} ${c['from'] ?? '—'} → ${c['to'] ?? '—'}',
                style: const TextStyle(fontSize: 12, color: AppColors.infoInk),
              ),
            ),
          if (r['status'] == 'update' && r['paid_kept'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Paid stays ${amt(r['paid_kept'])}',
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}
