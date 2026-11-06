import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/utils/sheet_export.dart';

const billingExportHeaders = [
  'Customer',
  'Customer Code',
  'CPO #',
  'CPO Date',
  'SI/DR #',
  'SI/DR Date',
  'Amount',
  'Paid',
  'Balance',
];

num billingNumber(dynamic v) => num.tryParse('${v ?? ''}'.trim()) ?? 0;

num billingBalance(Map<String, dynamic> r) =>
    billingNumber(r['amount']) - billingNumber(r['paid_amount']);

/// Same columns as the web portal's billing export.
List<List<Object?>> billingExportRows(List<Map<String, dynamic>> records) {
  String text(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s == 'null' ? '' : s;
  }

  return [
    for (final r in records)
      [
        text(r['customer_name']).isNotEmpty
            ? text(r['customer_name'])
            : text(r['customer_code']),
        text(r['customer_code']),
        text(r['cpo_number']),
        text(r['cpo_date']),
        text(r['sidr_number']),
        text(r['sidr_date']),
        billingNumber(r['amount']),
        billingNumber(r['paid_amount']),
        billingBalance(r),
      ],
  ];
}

/// Empty file with the columns Import Excel reads.
Future<void> downloadBillingTemplate(BuildContext context) =>
    exportSheets(context, 'billing-import-template.xlsx', const [
      ExportSheet('Billing', [
        'Customer Code',
        'CPO #',
        'CPO Date',
        'SI/DR #',
        'SI/DR Date',
        'Amount',
        'Paid',
      ], []),
    ]);

final _withDecimals = NumberFormat('#,##0.00');
final _noDecimals = NumberFormat('#,##0');

/// `₱63,387.10`, or `-₱3,670,553.18` when negative.
String billingMoney(num v, {bool decimals = true}) {
  final text = (decimals ? _withDecimals : _noDecimals).format(v.abs());
  return '${v < 0 ? '-' : ''}₱$text';
}

/// `Sep 05, 2025`; `—` for empty and placeholder dates.
String billingDate(dynamic raw) {
  final d = DateTime.tryParse('${raw ?? ''}'.trim());
  if (d == null || d.year < 1900) return '—';
  return DateFormat('MMM dd, y').format(d);
}
