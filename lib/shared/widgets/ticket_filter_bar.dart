import 'package:flutter/material.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// The ticket as the API sent it (list screens may wrap it in `full_data`).
Map<dynamic, dynamic> _rawTicket(Map<String, dynamic> t) =>
    t['full_data'] is Map ? t['full_data'] as Map : t;

String _ticketField(Map<String, dynamic> t, String key) =>
    (_rawTicket(t)[key]?.toString() ?? '').trim();

/// Whether a ticket passes the Type and Requester dropdowns ('' = any).
bool ticketMatchesDropdowns(
  Map<String, dynamic> ticket, {
  required String type,
  required String requester,
}) =>
    (type.isEmpty || _ticketField(ticket, 'ticket_type') == type) &&
    (requester.isEmpty || _ticketField(ticket, 'requester') == requester);

/// Status, Type and Requester dropdowns for lists that already hold all their
/// tickets (customer, end user). Choices come from those tickets, so only this
/// account's people are ever listed, and a choice always has results.
class TicketFilterBar extends StatelessWidget {
  const TicketFilterBar({
    super.key,
    required this.tickets,
    required this.status,
    required this.type,
    required this.requester,
    required this.onStatus,
    required this.onType,
    required this.onRequester,
    this.padding = EdgeInsets.zero,
  });

  final List<Map<String, dynamic>> tickets;

  /// 'All', 'Open', 'In Progress', 'Resolved' or 'Closed'.
  final String status;
  final String type;
  final String requester;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onType;
  final ValueChanged<String> onRequester;
  final EdgeInsets padding;

  List<SelectOption<String>> _choices(String key, String anyLabel) {
    final values =
        tickets
            .map((t) => _ticketField(t, key))
            .where((v) => v.isNotEmpty && v != 'null')
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      SelectOption('', anyLabel),
      for (final v in values) SelectOption(v, v),
    ];
  }

  Widget _select({
    required double width,
    required String title,
    required String value,
    required List<SelectOption<String>> options,
    required ValueChanged<String> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: SizedBox(
      width: width,
      child: AppSelect<String>(
        dense: true,
        sheetTitle: title,
        value: value,
        options: options,
        onChanged: onChanged,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadingHScroll(
      padding: padding,
      child: Row(
        children: [
          _select(
            width: 138,
            title: 'Status',
            value: status,
            options: const [
              SelectOption('All', 'All statuses'),
              SelectOption('Open', 'Open'),
              SelectOption('In Progress', 'In Progress'),
              SelectOption('Resolved', 'Resolved'),
              SelectOption('Closed', 'Closed'),
            ],
            onChanged: onStatus,
          ),
          _select(
            width: 138,
            title: 'Type',
            value: type,
            options: _choices('ticket_type', 'All types'),
            onChanged: onType,
          ),
          _select(
            width: 148,
            title: 'Requester',
            value: requester,
            options: _choices('requester', 'Any requester'),
            onChanged: onRequester,
          ),
        ],
      ),
    );
  }
}
