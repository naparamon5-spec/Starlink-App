import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/billing_export.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';

/// One billing record, like the web portal's: references, then amount, paid
/// and balance. Admins and billers can record a payment.
class BillingDetailsView extends StatefulWidget {
  const BillingDetailsView({
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
  State<BillingDetailsView> createState() => _BillingDetailsViewState();
}

class _BillingDetailsViewState extends State<BillingDetailsView> {
  late Map<String, dynamic>? _record = widget.prefetchedData;
  bool _loading = true;
  bool _canPay = false;

  String _text(String key, [String fallback = '']) {
    final t = _record?[key]?.toString().trim() ?? '';
    return t.isEmpty || t == 'null' ? fallback : t;
  }

  @override
  void initState() {
    super.initState();
    _loadRole();
    _load();
  }

  Future<void> _loadRole() async {
    final me = await ApiService.getMe();
    if (!mounted) return;
    final data = me['data'];
    final role =
        data is Map ? (data['role']?.toString() ?? '').toLowerCase() : '';
    setState(() => _canPay = role == 'admin' || role == 'biller');
  }

  Future<void> _load() async {
    final res = await ApiService.getBillingDetails(
      customerCode: widget.customerCode.trim(),
      cpoNumber: widget.cpoNumber.trim(),
      sidrNumber: widget.sidrNumber.trim(),
    );
    if (!mounted) return;
    var data = res['data'];
    if (data is Map && data['data'] != null) data = data['data'];
    if (data is List && data.isNotEmpty) data = data.first;
    setState(() {
      _loading = false;
      if (res['status'] == 'success' && data is Map && data.isNotEmpty) {
        // This route has no customer name; the list's row does.
        _record = {...?_record, ...Map<String, dynamic>.from(data)};
      }
    });
  }

  Future<void> _openPayment() async {
    final recorded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: true,
      useSafeArea: true,
      builder:
          (_) => _PaymentSheet(
            customerCode: widget.customerCode.trim(),
            cpoNumber: widget.cpoNumber.trim(),
            sidrNumber: widget.sidrNumber.trim(),
            amount: billingNumber(_record?['amount']),
            paid: billingNumber(_record?['paid_amount']),
          ),
    );
    if (recorded != true || !mounted) return;
    AppToast.success(context, 'Payment recorded');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperSubtle,
      appBar: AppBar(title: const Text('Billing')),
      body:
          _record == null
              ? Center(
                child:
                    _loading
                        ? const CircularProgressIndicator()
                        : const _NotFound(),
              )
              : RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final code = _text('customer_code', widget.customerCode);
    final name = _text('customer_name', widget.customerName ?? '');
    final balance = billingBalance(_record!);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Text(
          name.isNotEmpty ? name : code,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.4,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Field(
                      'CPO #',
                      _text('cpo_number', widget.cpoNumber),
                      sub: billingDate(_record!['cpo_date']),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Field(
                      'SI/DR #',
                      _text('sidr_number', widget.sidrNumber),
                      sub: billingDate(_record!['sidr_date']),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _Field('Customer code', code)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Field(
                      'Uploaded',
                      billingDate(_record!['date_uploaded']),
                      light: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Money(
                      'Amount',
                      billingNumber(_record!['amount']),
                      AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Money(
                      'Paid',
                      billingNumber(_record!['paid_amount']),
                      AppColors.successInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Money(
                'Balance',
                balance,
                balance > 0 ? AppColors.dangerInk : AppColors.successInk,
                size: 26,
              ),
            ],
          ),
        ),
        if (_canPay) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _openPayment,
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: const Text('Make Payment'),
          ),
        ],
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 34, color: AppColors.inkFaint),
        SizedBox(height: 10),
        Text(
          'Billing record not found',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 4),
        Text(
          "This record is unavailable or you don't have access.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
      ],
    ),
  );
}

const _labelStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
  color: AppColors.inkMuted,
);

class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.sub, this.light = false});
  final String label;
  final String value;
  final String? sub;
  final bool light;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: _labelStyle),
      const SizedBox(height: 3),
      Text(
        value.isEmpty ? '—' : value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: light ? FontWeight.w400 : FontWeight.w600,
          color: light ? AppColors.inkMuted : AppColors.ink,
        ),
      ),
      if (sub != null) ...[
        const SizedBox(height: 1),
        Text(
          sub!,
          style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
        ),
      ],
    ],
  );
}

class _Money extends StatelessWidget {
  const _Money(this.label, this.value, this.color, {this.size = 19});
  final String label;
  final num value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: _labelStyle),
      const SizedBox(height: 3),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          billingMoney(value),
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    ],
  );
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.customerCode,
    required this.cpoNumber,
    required this.sidrNumber,
    required this.amount,
    required this.paid,
  });
  final String customerCode;
  final String cpoNumber;
  final String sidrNumber;
  final num amount;
  final num paid;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _input = TextEditingController();
  bool _saving = false;

  num get _balance => widget.amount - widget.paid;

  /// Rounded to centavos, or null when it isn't a positive amount.
  double? get _value {
    final n = double.tryParse(_input.text.trim());
    if (n == null || !n.isFinite || n <= 0) return null;
    return (n * 100).round() / 100;
  }

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = _value;
    if (amount == null || _saving) return;
    setState(() => _saving = true);
    final res = await ApiService.makePayment(
      customerCode: widget.customerCode,
      cpoNumber: widget.cpoNumber,
      sidrNumber: widget.sidrNumber,
      amount: amount,
    );
    if (!mounted) return;
    if (res['status'] == 'success') {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _saving = false);
    AppToast.error(
      context,
      res['message']?.toString() ?? "Couldn't record the payment.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final paidAfter = value == null ? null : widget.paid + value;
    final balanceAfter = paidAfter == null ? null : widget.amount - paidAfter;
    return UnsavedChangesGuard(
      isDirty: () => _input.text.trim().isNotEmpty && !_saving,
      listenTo: _input,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Make Payment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Current balance',
                    style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                  ),
                ),
                Text(
                  billingMoney(_balance),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        _balance > 0
                            ? AppColors.dangerInk
                            : AppColors.successInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('Payment amount (₱)'),
            TextField(
              controller: _input,
              autofocus: true,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
              ),
            ),
            if (_balance > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed:
                      _saving
                          ? null
                          : () => _input.text = _balance.toStringAsFixed(2),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    foregroundColor: AppColors.brand,
                  ),
                  child: Text(
                    'Pay the full balance (${billingMoney(_balance)})',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            if (paidAfter != null && balanceAfter != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.paperSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'After this payment: paid ${billingMoney(paidAfter)}, '
                      'balance ${billingMoney(balanceAfter < 0 ? 0 : balanceAfter)}.',
                      style: const TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                    if (balanceAfter < 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'This is ${billingMoney(-balanceAfter)} more than the balance.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warningInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'This amount is added to the existing paid total.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed:
                        _saving ? null : () => Navigator.maybePop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: value == null || _saving ? null : _submit,
                    child:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'Record payment',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
