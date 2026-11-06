import 'package:flutter/material.dart';
import 'package:starlink_app/features/subscription/subscription_details_view.dart';

class AdminSubscriptionDetailsPage extends StatelessWidget {
  const AdminSubscriptionDetailsPage({
    super.key,
    required this.serviceLineNumber,
    required this.title,
  });

  final String serviceLineNumber;
  final String title;

  @override
  Widget build(BuildContext context) => SubscriptionDetailsView(
    serviceLineNumber: serviceLineNumber,
    title: title,
    canEditEndDate: true,
    canManageKits: true,
    canViewRouter: true,
  );
}
