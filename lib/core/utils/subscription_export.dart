import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/core/utils/status_labels.dart';
import 'package:starlink_app/services/api_service.dart';

const subscriptionExportHeaders = [
  'Nickname',
  'Service Line Number',
  'Company',
  'End User',
  'Service Location',
  'Kit Number',
  'Status',
  'Plan',
  'Priority Used (GB)',
  'Plan Data (GB)',
  'Start Date',
  'End Date',
];

/// Rows for the same columns as the web portal's subscription export.
List<List<Object?>> subscriptionExportRows(
  List<Map<String, dynamic>> subscriptions,
) {
  String text(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s == 'null' ? '' : s;
  }

  Object number(dynamic v) => num.tryParse(text(v)) ?? '';

  String date(dynamic v) {
    final d = DateTime.tryParse(text(v));
    return d == null ? text(v) : DateFormat('yyyy-MM-dd').format(d.toLocal());
  }

  String status(dynamic v) {
    final label = subscriptionStatusLabel(v);
    return label == '—' ? '' : label[0] + label.substring(1).toLowerCase();
  }

  String plan(dynamic v) {
    final code = text(v);
    return const {'NOR': 'Normal', 'IMP': 'IMPACT'}[code.toUpperCase()] ?? code;
  }

  return [
    for (final s in subscriptions)
      [
        text(s['nickname']),
        text(s['serviceLineNumber']),
        text(s['company_name']),
        text(s['end_user_name']),
        text(s['address']),
        text(s['kit_number']),
        status(s['active']),
        plan(s['subscriptionPlan']),
        number(s['totalPriorityGB']),
        number(s['dataplan']),
        date(s['startDate']),
        date(s['endDate']),
      ],
  ];
}

/// Every subscription matching [search] that this user may see (the API
/// scopes the list by role).
Future<List<Map<String, dynamic>>> fetchAllSubscriptions(String search) =>
    fetchAllRows(
      fetchPage:
          (page, limit) => ApiService.getSubscriptionsPaginated(
            page: page,
            limit: limit,
            search: search,
          ),
      keyOf: subscriptionExportKey,
    );

/// Identifies one exported row. The API returns a row per terminal, so a
/// service line with several kits appears several times and each one counts.
String subscriptionExportKey(Map<dynamic, dynamic> row) =>
    '${row['serviceLineNumber']}|${row['kit_number']}';

class ExportSubscriptionsButton extends StatelessWidget {
  const ExportSubscriptionsButton({super.key, required this.controller});

  final ListExportController controller;

  @override
  Widget build(BuildContext context) => ListExportButton(
    controller: controller,
    tooltip: 'Export subscriptions to Excel',
    emptyMessage: 'No subscriptions match your search',
    filePrefix: 'subscriptions',
    sheetName: 'Subscriptions',
    headers: subscriptionExportHeaders,
    rowsOf: subscriptionExportRows,
  );
}
