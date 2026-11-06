import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/utils/sheet_export.dart';

/// Exports the billing cycle shown on a subscription's usage section to
/// Excel, like the web portal: a "Daily usage" sheet (the graph's daily
/// figures plus a total row) and a "Summary" sheet.
///
/// [cycle] is the billing-cycle payload (GET /subscriptions/billing-cycle or
/// the subscription's billingCycle): dailyUsage.graphs[].data has one
/// dataset per day holding [priority, optInPriority, standard, nonBillable].
Future<void> exportUsage(
  BuildContext context, {
  required String serviceLineNumber,
  required Map<String, dynamic>? cycle,
  String? nickname,
  String? account,
  String? plan,
  String? start,
  String? end,
}) async {
  final days = usageRows(cycle);
  if (cycle == null || days.isEmpty) {
    AppToast.info(context, 'No usage data to export for this cycle');
    return;
  }
  double r2(num v) => (v * 100).round() / 100;
  List<Object?> cols(List<double> v) => [
    r2(v[0]),
    r2(v[1]),
    r2(v[2]),
    r2(v[3]),
    r2(v[0] + v[1] + v[2] + v[3]),
  ];
  final sum = [0.0, 0.0, 0.0, 0.0];
  for (final d in days) {
    for (var i = 0; i < 4; i++) {
      sum[i] += d.values[i];
    }
  }
  Object? n(dynamic v) => num.tryParse('${v ?? ''}') ?? '';
  final from = _ymd(start ?? cycle['startDate']);
  final to = _ymd(end ?? cycle['endDate']);

  await exportSheets(context, 'usage-$serviceLineNumber-$from-to-$to.xlsx', [
    ExportSheet(
      'Daily usage',
      const [
        'Date',
        'Priority (GB)',
        'Opt-in priority (GB)',
        'Standard (GB)',
        'Non-billable (GB)',
        'Total (GB)',
      ],
      [
        for (final d in days) [d.date, ...cols(d.values)],
        ['Total', ...cols(sum)],
      ],
    ),
    ExportSheet(
      'Summary',
      const ['Field', 'Value'],
      [
        ['Service line number', serviceLineNumber],
        ['Nickname', nickname ?? ''],
        ['Account', account ?? ''],
        ['Plan', plan ?? ''],
        ['Billing cycle start', from],
        ['Billing cycle end', to],
        ['Consumed (GB)', n(cycle['consumedAmountGB'])],
        ['Usage limit (GB)', n(cycle['usageLimitGB'])],
        ['Priority (GB)', n(cycle['totalPriorityGB'])],
        ['Opt-in priority (GB)', n(cycle['totalOptInPriorityGB'])],
        ['Standard (GB)', n(cycle['totalStandardGB'])],
        ['Non-billable (GB)', n(cycle['totalNonBillableGB'])],
        ['Days with usage data', days.length],
        ['Exported', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())],
      ],
    ),
  ]);
}

class UsageDay {
  const UsageDay(this.date, this.values);
  final String date;
  final List<double>
  values; // priority, opt-in priority, standard, non-billable
}

/// The days behind a cycle's usage graph, oldest first.
List<UsageDay> usageRows(Map<String, dynamic>? cycle) {
  final graphs =
      cycle?['dailyUsage'] is Map ? cycle!['dailyUsage']['graphs'] : null;
  final out = <UsageDay>[];
  if (graphs is! List) return out;
  for (final g in graphs) {
    final data = g is Map ? g['data'] : null;
    if (data is! Map) continue;
    final labels = data['labels'] is List ? data['labels'] as List : const [];
    final sets = data['datasets'] is List ? data['datasets'] as List : const [];
    for (var i = 0; i < labels.length; i++) {
      final v =
          i < sets.length && sets[i] is Map && sets[i]['data'] is List
              ? sets[i]['data'] as List
              : const [];
      double at(int k) => k < v.length ? (double.tryParse('${v[k]}') ?? 0) : 0;
      out.add(UsageDay(_ymd(labels[i]), [at(0), at(1), at(2), at(3)]));
    }
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

String _ymd(dynamic v) {
  final s = '${v ?? ''}';
  final d = DateTime.tryParse(s);
  return d == null
      ? s.split('T').first
      : DateFormat('yyyy-MM-dd').format(d.toLocal());
}
