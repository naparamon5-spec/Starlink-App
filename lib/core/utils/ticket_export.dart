import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/services/api_service.dart';

const ticketExportHeaders = [
  'Ticket #',
  'Subject',
  'Type',
  'Status',
  'Created by',
  'Requester',
  'Created',
  'Description',
];

/// Rows for the same columns as the web portal's ticket export. List screens
/// may wrap the API's ticket in `full_data`; that original is what's read.
List<List<Object?>> ticketExportRows(List<Map<String, dynamic>> tickets) {
  String text(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s == 'null' ? '' : s;
  }

  String status(dynamic v) => text(v)
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  String created(dynamic v) {
    final d = DateTime.tryParse(text(v));
    return d == null
        ? text(v)
        : DateFormat('yyyy-MM-dd HH:mm').format(d.toLocal());
  }

  return [
    for (final item in tickets)
      () {
        final t = item['full_data'] is Map ? item['full_data'] as Map : item;
        return <Object?>[
          t['id'],
          text(t['subject']),
          text(t['ticket_type'] ?? t['type']),
          status(t['status']),
          text(t['created_by']),
          text(t['requester']),
          created(t['created_at']),
          text(t['description']),
        ];
      }(),
  ];
}

/// Every ticket this user may see, across all pages.
Future<List<Map<String, dynamic>>> fetchAllTickets({
  Future<Map<String, dynamic>> Function(int page, int limit)? fetchPage,
}) => fetchAllRows(
  fetchPage:
      fetchPage ??
      (page, limit) => ApiService.getTickets(page: page, limit: limit),
  keyOf: (row) => '${row['id']}',
);

class ExportTicketsButton extends StatelessWidget {
  const ExportTicketsButton({super.key, required this.controller});

  final ListExportController controller;

  @override
  Widget build(BuildContext context) => ListExportButton(
    controller: controller,
    tooltip: 'Export tickets to Excel',
    emptyMessage: 'No tickets match your filters',
    filePrefix: 'tickets',
    sheetName: 'Tickets',
    headers: ticketExportHeaders,
    rowsOf: ticketExportRows,
  );
}
