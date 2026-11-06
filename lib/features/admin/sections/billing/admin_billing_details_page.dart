import 'package:flutter/material.dart';
import 'package:starlink_app/features/billing/billing_details_view.dart';

class AdminBillingDetailsPage extends StatelessWidget {
  const AdminBillingDetailsPage({
    super.key,
    required this.customerCode,
    required this.cpoNumber,
    required this.sidrNumber,
    this.customerName,
    this.prefetchedData,
  });

  final String customerCode;
  final String cpoNumber;
  final String sidrNumber;
  final String? customerName;
  final Map<String, dynamic>? prefetchedData;

  @override
  Widget build(BuildContext context) => BillingDetailsView(
    customerCode: customerCode,
    cpoNumber: cpoNumber,
    sidrNumber: sidrNumber,
    customerName: customerName,
    prefetchedData: prefetchedData,
  );
}
