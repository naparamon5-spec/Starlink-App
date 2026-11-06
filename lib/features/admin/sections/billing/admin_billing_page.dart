import 'package:flutter/material.dart';
import 'package:starlink_app/features/billing/billing_actions_button.dart';
import 'package:starlink_app/features/admin/sections/billing/admin_billing_details_page.dart';
import 'package:starlink_app/features/billing/billing_list_view.dart';

class AdminBillingPage extends StatelessWidget {
  const AdminBillingPage({super.key, this.actionsController});

  final BillingListController? actionsController;

  void _open(BuildContext context, Map<String, dynamic> r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AdminBillingDetailsPage(
              customerCode: '${r['customer_code'] ?? ''}',
              cpoNumber: '${r['cpo_number'] ?? ''}',
              sidrNumber: '${r['sidr_number'] ?? ''}',
              customerName: r['customer_name']?.toString(),
              prefetchedData: r,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BillingListView(
    onOpen: (r) => _open(context, r),
    actionsController: actionsController,
  );
}
