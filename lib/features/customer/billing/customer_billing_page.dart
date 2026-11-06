import 'package:flutter/material.dart';
import 'package:starlink_app/features/customer/billing/customer_billing_details_page.dart';
import 'package:starlink_app/features/billing/billing_actions_button.dart';
import 'package:starlink_app/features/billing/billing_list_view.dart';

class CustomerBillingPage extends StatelessWidget {
  const CustomerBillingPage({
    super.key,
    this.showAppBar = true,
    this.actionsController,
  });

  final bool showAppBar;
  final BillingListController? actionsController;

  void _open(BuildContext context, Map<String, dynamic> r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CustomerBillingDetailsPage(
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
  Widget build(BuildContext context) =>
      BillingListView(onOpen: (r) => _open(context, r), showAppBar: showAppBar);
}
