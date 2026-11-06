import 'package:flutter/material.dart';
import 'package:starlink_app/features/ticket/ticket_details_view.dart';

class CustomerViewScreen extends StatelessWidget {
  const CustomerViewScreen({super.key, required this.ticket});

  final Map<String, dynamic> ticket;

  @override
  Widget build(BuildContext context) => TicketDetailsView(
    ticketId: '${ticket['id'] ?? ''}',
    subject: ticket['subject']?.toString(),
  );
}
