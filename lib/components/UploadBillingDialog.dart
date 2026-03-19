import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import '../../../../services/api_service.dart';

// Required columns that must exist in the uploaded file
const _requiredColumns = [
  'customer_code',
  'customer_name',
  'cpo_number',
  'sidr_number',
  'service_line_number',
  'nickname',
  'service_plan',
  'service_plan_fee',
  'billing_period_from',
  'billing_period_to',
  'total_amount',
  'paid_amount',
];

class UploadBillingDialog extends StatefulWidget {
  const UploadBillingDialog({super.key});

  @override
  State<UploadBillingDialog> createState() => _UploadBillingDialogState();
}

class _UploadBillingDialogState extends State<UploadBillingDialog> {
  static const _primary = Color(0xFFEB1E23);
  static const _success = Color(0xFF24A148);
  static const _warning = Color(0xFFFF832B);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  // State
  _UploadStep _step = _UploadStep.idle;
  String? _fileName;
  String? _errorMessage;
  List<String> _missingColumns = [];
  List<Map<String, String>> _parsedRows = [];
  bool _submitting = false;
  int _submittedCount = 0;
  List<String> _submitErrors = [];

  Future<void> _pickFile() async {
    setState(() {
      _step = _UploadStep.idle;
      _errorMessage = null;
      _missingColumns = [];
      _parsedRows = [];
      _submitErrors = [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileName = file.name.toLowerCase();
      final bytes = file.bytes;

      if (bytes == null) {
        setState(() {
          _step = _UploadStep.error;
          _errorMessage = 'Could not read file data. Please try again.';
        });
        return;
      }

      setState(() => _step = _UploadStep.parsing);

      List<Map<String, String>> rows = [];

      if (fileName.endsWith('.csv')) {
        rows = _parseCsv(String.fromCharCodes(bytes));
      } else if (fileName.endsWith('.xlsx') || fileName.endsWith('.xls')) {
        rows = _parseExcel(bytes);
      } else {
        setState(() {
          _step = _UploadStep.error;
          _errorMessage =
              'Unsupported file type. Please upload a CSV or Excel file.';
        });
        return;
      }

      if (rows.isEmpty) {
        setState(() {
          _step = _UploadStep.error;
          _errorMessage = 'The file appears to be empty or has no data rows.';
        });
        return;
      }

      // Validate columns
      final fileColumns = rows.first.keys.toSet();
      final missing =
          _requiredColumns.where((c) => !fileColumns.contains(c)).toList();

      if (missing.isNotEmpty) {
        setState(() {
          _step = _UploadStep.error;
          _fileName = file.name;
          _missingColumns = missing;
          _errorMessage =
              'File is missing ${missing.length} required column(s).';
        });
        return;
      }

      setState(() {
        _step = _UploadStep.preview;
        _fileName = file.name;
        _parsedRows = rows;
      });
    } catch (e) {
      setState(() {
        _step = _UploadStep.error;
        _errorMessage =
            'Failed to read file: ${e.toString().replaceAll("Exception: ", "")}';
      });
    }
  }

  List<Map<String, String>> _parseCsv(String content) {
    final rows = _parseCsvRows(content);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((e) => e.trim().toLowerCase()).toList();
    final data = <Map<String, String>>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      final map = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        map[headers[j]] = j < row.length ? row[j].trim() : '';
      }
      data.add(map);
    }
    return data;
  }

  /// Pure Dart RFC 4180-compliant CSV row parser — no external packages.
  List<List<String>> _parseCsvRows(String input) {
    final rows = <List<String>>[];
    final src = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    int pos = 0;
    while (pos < src.length) {
      final row = <String>[];
      while (pos <= src.length) {
        if (pos == src.length) {
          row.add('');
          break;
        }
        final ch = src[pos];
        if (ch == '"') {
          pos++;
          final buf = StringBuffer();
          while (pos < src.length) {
            final c = src[pos];
            if (c == '"') {
              pos++;
              if (pos < src.length && src[pos] == '"') {
                buf.write('"');
                pos++;
              } else {
                break;
              }
            } else {
              buf.write(c);
              pos++;
            }
          }
          row.add(buf.toString());
          if (pos < src.length && src[pos] == ',') {
            pos++;
          } else {
            break;
          }
        } else if (ch == ',') {
          row.add('');
          pos++;
        } else if (ch == '\n') {
          row.add('');
          pos++;
          break;
        } else {
          final start = pos;
          while (pos < src.length && src[pos] != ',' && src[pos] != '\n') {
            pos++;
          }
          row.add(src.substring(start, pos));
          if (pos < src.length && src[pos] == ',') {
            pos++;
          } else {
            if (pos < src.length) pos++;
            break;
          }
        }
      }
      if (row.isNotEmpty && !(row.length == 1 && row[0].isEmpty)) rows.add(row);
    }
    return rows;
  }

  List<Map<String, String>> _parseExcel(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null || sheet.rows.isEmpty) return [];

    final headers =
        sheet.rows.first
            .map((c) => (c?.value?.toString() ?? '').trim().toLowerCase())
            .toList();

    final data = <Map<String, String>>[];
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((c) => (c?.value?.toString() ?? '').trim().isEmpty)) {
        continue;
      }
      final map = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        map[headers[j]] =
            j < row.length ? (row[j]?.value?.toString().trim() ?? '') : '';
      }
      data.add(map);
    }
    return data;
  }

  Future<void> _submitRecords() async {
    setState(() {
      _submitting = true;
      _submittedCount = 0;
      _submitErrors = [];
    });

    int successCount = 0;
    final errors = <String>[];

    for (int i = 0; i < _parsedRows.length; i++) {
      final row = _parsedRows[i];
      try {
        final result = await ApiService.uploadBillingRecord(row);
        if (result['status'] == 'success') {
          successCount++;
        } else {
          errors.add(
            'Row ${i + 1} (${row['customer_name'] ?? ''}): ${result['message'] ?? 'Failed'}',
          );
        }
      } catch (e) {
        errors.add(
          'Row ${i + 1}: ${e.toString().replaceAll("Exception: ", "")}',
        );
      }
      setState(() => _submittedCount = successCount);
    }

    setState(() {
      _submitting = false;
      _submittedCount = successCount;
      _submitErrors = errors;
      _step = _UploadStep.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      backgroundColor: _surface,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case _UploadStep.idle:
      case _UploadStep.parsing:
        return _buildPickerView();
      case _UploadStep.error:
        return _buildErrorView();
      case _UploadStep.preview:
        return _buildPreviewView();
      case _UploadStep.done:
        return _buildDoneView();
    }
  }

  // ── Step 1: Pick file ──────────────────────────────────────────────────────

  Widget _buildPickerView() {
    final isParsing = _step == _UploadStep.parsing;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogHeader(
            title: 'Upload Billing Records',
            onClose: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 24),

          // Drop zone
          GestureDetector(
            onTap: isParsing ? null : _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.03),
                border: Border.all(
                  color: isParsing ? _primary : _primary.withOpacity(0.25),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (isParsing) ...[
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: _primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Reading file…',
                      style: TextStyle(
                        fontSize: 13,
                        color: _inkSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.upload_file_rounded,
                        color: _primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tap to select a file',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Supports CSV and Excel (.xlsx, .xls)',
                      style: TextStyle(fontSize: 12, color: _inkTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Required columns hint
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Required columns',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _inkSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      _requiredColumns
                          .map(
                            (col) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _border),
                              ),
                              child: Text(
                                col,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: _ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundColor: _inkSecondary,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Error view ─────────────────────────────────────────────────────

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogHeader(
            title: 'Upload Billing Records',
            onClose: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: _primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage ?? 'An error occurred.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_missingColumns.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Missing columns:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        _missingColumns
                            .map(
                              (col) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  col,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: _primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
                if (_fileName != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'File: $_fileName',
                    style: const TextStyle(fontSize: 11, color: _inkTertiary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: _inkSecondary,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 3: Preview ────────────────────────────────────────────────────────

  Widget _buildPreviewView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
          child: Row(
            children: [
              _DialogHeader(
                title: 'Preview — $_fileName',
                onClose: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),

        // File summary bar
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _success.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _success.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: _success,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'File validated · ${_parsedRows.length} record${_parsedRows.length != 1 ? "s" : ""} ready to upload',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Preview table
        SizedBox(
          height: 280,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _buildPreviewTable(),
            ),
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickFile,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: _inkSecondary,
                  ),
                  child: const Text(
                    'Change File',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitRecords,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: _primary.withOpacity(0.5),
                  ),
                  child:
                      _submitting
                          ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Uploading $_submittedCount/${_parsedRows.length}…',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                          : Text(
                            'Upload ${_parsedRows.length} Record${_parsedRows.length != 1 ? "s" : ""}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTable() {
    const colStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: _inkSecondary,
      letterSpacing: 0.3,
    );
    const cellStyle = TextStyle(fontSize: 11, color: _ink);

    // Show max 5 preview rows
    final previewRows = _parsedRows.take(5).toList();
    final hasMore = _parsedRows.length > 5;

    return Table(
      border: TableBorder.all(color: _border, width: 0.5),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(color: _surfaceSubtle),
          children:
              _requiredColumns
                  .map(
                    (col) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text(col, style: colStyle),
                    ),
                  )
                  .toList(),
        ),
        // Data rows
        ...previewRows.map(
          (row) => TableRow(
            children:
                _requiredColumns
                    .map(
                      (col) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          row[col] ?? '—',
                          style: cellStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        // "and X more rows" row
        if (hasMore)
          TableRow(
            decoration: BoxDecoration(color: _primary.withOpacity(0.04)),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Text(
                  '+ ${_parsedRows.length - 5} more row${_parsedRows.length - 5 != 1 ? "s" : ""}…',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _primary,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              ...List.generate(
                _requiredColumns.length - 1,
                (_) => const SizedBox.shrink(),
              ),
            ],
          ),
      ],
    );
  }

  // ── Step 4: Done ───────────────────────────────────────────────────────────

  Widget _buildDoneView() {
    final hasErrors = _submitErrors.isNotEmpty;
    final allFailed = _submittedCount == 0 && hasErrors;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: (allFailed ? _primary : _success).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              allFailed
                  ? Icons.error_outline_rounded
                  : hasErrors
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color:
                  allFailed
                      ? _primary
                      : hasErrors
                      ? _warning
                      : _success,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            allFailed
                ? 'Upload Failed'
                : hasErrors
                ? 'Partially Uploaded'
                : 'Upload Complete!',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            allFailed
                ? 'No records were uploaded. Please check the errors below.'
                : '$_submittedCount of ${_parsedRows.length} record${_parsedRows.length != 1 ? "s" : ""} uploaded successfully.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _inkSecondary),
          ),

          if (_submitErrors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primary.withOpacity(0.15)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Errors:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._submitErrors.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $e',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _inkSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _submittedCount > 0),
              style: ElevatedButton.styleFrom(
                backgroundColor: allFailed ? _inkSecondary : _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dialog header reusable widget ────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _DialogHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEB1E23).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: Color(0xFFEB1E23),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF000000),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onClose,
            color: const Color(0xFF6F6F6F),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

enum _UploadStep { idle, parsing, error, preview, done }
