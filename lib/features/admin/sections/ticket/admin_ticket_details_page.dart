import 'package:flutter/material.dart';
import 'package:starlink_app/features/ticket/ticket_details_view.dart';

class AdminTicketDetailsPage extends StatelessWidget {
  const AdminTicketDetailsPage({
    super.key,
    required this.ticketId,
    this.subject,
  });

  final String ticketId;
  final String? subject;

  @override
  Widget build(BuildContext context) =>
      TicketDetailsView(ticketId: ticketId, subject: subject);
}
