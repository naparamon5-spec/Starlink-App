import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';

class AdminBillingDetailsPage extends StatefulWidget {
  final String customerCode;
  final String cpoNumber;
  final String sidrNumber;
  final String? customerName;
  final Map<String, dynamic>? prefetchedData;

  const AdminBillingDetailsPage({
    super.key,
    required this.customerCode,
    required this.cpoNumber,
    required this.sidrNumber,
    this.customerName,
    this.prefetchedData,
  });

  @override
  State<AdminBillingDetailsPage> createState() =>
      _AdminBillingDetailsPageState();
}

class _AdminBillingDetailsPageState extends State<AdminBillingDetailsPage> {
  bool _loading = false;
  Map<String, dynamic>? _billing;

  // ── Brand colors ───────────────────────────────────────────────────────────
  static const _brandRed = Color(0xFFEB1E23);
  static const _brandDark = Color(0xFF760F12);

  @override
  void initState() {
    super.initState();
    if (widget.prefetchedData != null) {
      _billing = Map<String, dynamic>.from(widget.prefetchedData!);
    }
    _tryFetchFromApi();
  }

  Future<void> _tryFetchFromApi() async {
    final code = widget.customerCode.trim();
    final cpo = widget.cpoNumber.trim();
    final sidr = widget.sidrNumber.trim();
    if (code.isEmpty || cpo.isEmpty || sidr.isEmpty) return;

    if (mounted) setState(() => _loading = true);

    try {
      final result = await ApiService.getBillingDetails(
        customerCode: code,
        cpoNumber: cpo,
        sidrNumber: sidr,
      );
      if (!mounted) return;

      if (result['status'] == 'success') {
        dynamic data = result['data'];
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          data = data['data'];
        }
        if (data is List && data.isNotEmpty) data = data.first;

        if (data is Map && (data as Map).isNotEmpty) {
          setState(() {
            _billing = {
              ...?_billing,
              ...Map<String, dynamic>.from(data as Map),
            };
          });
        }
      }
    } catch (_) {
      // Silently ignore — we already have prefetched data to show
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    if (widget.prefetchedData != null) {
      setState(
        () => _billing = Map<String, dynamic>.from(widget.prefetchedData!),
      );
    }
    await _tryFetchFromApi();
  }

  String _str(dynamic v) =>
      (v == null || v.toString() == 'null' || v.toString().trim().isEmpty)
          ? '—'
          : v.toString().trim();

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null' || raw == '0000-00-00')
      return '—';
    try {
      final dt = DateTime.parse(raw);
      if (dt.year < 1900) return '—';
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      if (raw.contains('T')) return raw.split('T').first;
      return raw;
    }
  }

  String _formatAmount(dynamic raw) {
    if (raw == null) return '0.00';
    final d = double.tryParse(raw.toString());
    return d != null ? d.toStringAsFixed(2) : raw.toString();
  }

  double _parseAmount(dynamic raw) =>
      double.tryParse(raw?.toString() ?? '0') ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final title =
        (widget.customerName?.isNotEmpty == true)
            ? widget.customerName!
            : widget.customerCode;

    if (_billing == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: _buildAppBar(title),
        body: Center(
          child: CircularProgressIndicator(color: _brandRed, strokeWidth: 2.5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(title),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _reload,
            color: _brandRed,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _buildSummaryRow(),
                const SizedBox(height: 14),
                _buildInfoCard(),
                const SizedBox(height: 14),
                _buildPaymentCard(),
              ],
            ),
          ),
          if (_loading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                color: _brandRed,
                backgroundColor: _brandRed.withOpacity(0.15),
                minHeight: 3,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildMakePaymentButton(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String title) => AppBar(
    backgroundColor: Colors.white,
    foregroundColor: const Color(0xFF000000),
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
          ),
        ),
        Text(
          'CPO: ${widget.cpoNumber} · SIDR: ${widget.sidrNumber}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF8A96A3)),
        ),
      ],
    ),
    actions: [
      IconButton(
        icon: Icon(Icons.refresh_rounded, color: _brandRed),
        onPressed: _loading ? null : _reload,
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: const Color(0xFFE8ECF0)),
    ),
  );

  Widget _buildMakePaymentButton() {
    final b = _billing ?? {};
    final amount = _parseAmount(b['amount']);
    final paid = _parseAmount(b['paid_amount'] ?? b['paidAmount']);
    final balance = amount - paid;
    final isPaid = balance <= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: isPaid ? null : _showMakePaymentSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandRed,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE8ECF0),
            disabledForegroundColor: const Color(0xFF8A96A3),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: Icon(
            isPaid ? Icons.verified_rounded : Icons.payment_rounded,
            size: 20,
          ),
          label: Text(
            isPaid ? 'Already Paid' : 'Make Payment',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  void _showMakePaymentSheet() {
    final b = _billing ?? {};
    final amount = _parseAmount(b['amount']);
    final paid = _parseAmount(b['paid_amount'] ?? b['paidAmount']);
    final balance = (amount - paid).abs();
    final controller = TextEditingController(text: _formatAmount(balance));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool submitting = false;
        String? sheetError;

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> confirmPayment() async {
              final entered = double.tryParse(controller.text.trim()) ?? 0;
              if (entered <= 0) {
                setSheet(() => sheetError = 'Please enter a valid amount.');
                return;
              }
              setSheet(() {
                submitting = true;
                sheetError = null;
              });
              try {
                final result = await ApiService.makePayment(
                  customerCode: widget.customerCode,
                  cpoNumber: widget.cpoNumber,
                  sidrNumber: widget.sidrNumber,
                  amount: entered,
                );
                if (!ctx.mounted) return;
                if (result['status'] != 'success') {
                  setSheet(() {
                    submitting = false;
                    sheetError =
                        result['message']?.toString() ?? 'Payment failed.';
                  });
                  return;
                }
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            result['message']?.toString() ??
                                'Payment recorded successfully.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                  _reload();
                }
              } catch (e) {
                setSheet(() {
                  submitting = false;
                  sheetError = 'An unexpected error occurred.';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _brandRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.payment_rounded,
                            color: _brandRed,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Make Payment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF000000),
                              ),
                            ),
                            Text(
                              'Enter the amount to record',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A96A3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Outstanding Balance',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8A96A3),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '₱${_formatAmount(balance)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _brandRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment Amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      enabled: !submitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000000),
                      ),
                      decoration: InputDecoration(
                        prefixText: '₱ ',
                        prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _brandRed,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _brandRed, width: 1.5),
                        ),
                      ),
                    ),
                    if (sheetError != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: _brandRed,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sheetError!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _brandRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: submitting ? null : confirmPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandRed,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _brandRed.withOpacity(0.6),
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child:
                            submitting
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                                : const Text(
                                  'Confirm Payment',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryRow() {
    final b = _billing ?? {};
    final amount = _parseAmount(b['amount']);
    final paid = _parseAmount(b['paid_amount'] ?? b['paidAmount']);
    final balance = amount - paid;
    final isPaid = balance <= 0;
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'Total Amount',
            value: '₱${_formatAmount(amount)}',
            icon: Icons.receipt_long_outlined,
            color: _brandRed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            label: 'Paid',
            value: '₱${_formatAmount(paid)}',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            label: 'Balance',
            value: '₱${_formatAmount(balance.abs())}',
            icon: isPaid ? Icons.verified_rounded : Icons.pending_outlined,
            color: isPaid ? const Color(0xFF10B981) : _brandRed,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final b = _billing ?? {};
    final customerName = _str(b['customer_name'] ?? b['customerName']);
    final customerCode = _str(b['customer_code'] ?? b['customerCode']);
    final cpoNumber = _str(b['cpo_number'] ?? b['cpoNumber']);
    final cpoDate = _formatDate((b['cpo_date'] ?? b['cpoDate'])?.toString());
    final sidrNumber = _str(b['sidr_number'] ?? b['sidrNumber']);
    final sidrDate = _formatDate((b['sidr_date'] ?? b['sidrDate'])?.toString());
    final dateUploaded = _formatDate(
      (b['date_uploaded'] ?? b['dateUploaded'])?.toString(),
    );
    final uploadedBy = _str(b['uploaded_by'] ?? b['uploadedBy']);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.info_outline_rounded,
            iconColor: _brandRed,
            label: 'Billing Information',
          ),
          const _HDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                if (customerName != '—') ...[
                  _KVRow(label: 'Customer Name', value: customerName),
                  const SizedBox(height: 8),
                ],
                _KVRow(label: 'Customer Code', value: customerCode),
                const SizedBox(height: 8),
                _KVRow(label: 'CPO Number', value: cpoNumber),
                const SizedBox(height: 8),
                _KVRow(label: 'CPO Date', value: cpoDate),
                const SizedBox(height: 8),
                _KVRow(label: 'SIDR Number', value: sidrNumber),
                const SizedBox(height: 8),
                _KVRow(label: 'SIDR Date', value: sidrDate),
                const SizedBox(height: 8),
                _KVRow(label: 'Date Uploaded', value: dateUploaded),
                const SizedBox(height: 8),
                _KVRow(label: 'Uploaded By', value: uploadedBy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    final b = _billing ?? {};
    final amount = _parseAmount(b['amount']);
    final paid = _parseAmount(b['paid_amount'] ?? b['paidAmount']);
    final balance = amount - paid;
    final progress = amount > 0 ? (paid / amount).clamp(0.0, 1.0) : 0.0;
    final isPaid = balance <= 0;
    final progressColor =
        progress >= 1.0
            ? const Color(0xFF10B981)
            : progress >= 0.5
            ? const Color(0xFFF59E0B)
            : _brandRed;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF10B981),
            label: 'Payment Summary',
            trailing: _StatusBadge(
              label: isPaid ? 'PAID' : 'OUTSTANDING',
              color: isPaid ? const Color(0xFF10B981) : _brandRed,
            ),
          ),
          const _HDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% paid',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: progressColor,
                      ),
                    ),
                    Text(
                      isPaid
                          ? 'Fully paid'
                          : 'Balance: ₱${_formatAmount(balance.abs())}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A96A3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE8ECF0),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(height: 16),
                const _HDivider(),
                const SizedBox(height: 12),
                _AmountRow(
                  label: 'Total Amount',
                  value: '₱${_formatAmount(amount)}',
                  bold: true,
                  color: const Color(0xFF000000),
                ),
                const SizedBox(height: 8),
                _AmountRow(
                  label: 'Amount Paid',
                  value: '₱${_formatAmount(paid)}',
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 8),
                _AmountRow(
                  label: isPaid ? 'Overpayment' : 'Outstanding Balance',
                  value: '₱${_formatAmount(balance.abs())}',
                  color: isPaid ? const Color(0xFF10B981) : _brandRed,
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8ECF0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  const _CardHeader({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF000000),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: const Color(0xFFF0F4F8));
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8ECF0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Color(0xFF8A96A3)),
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4), width: 1.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );
}

class _KVRow extends StatelessWidget {
  final String label;
  final String value;
  const _KVRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 120,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8A96A3),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF000000),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _AmountRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: bold ? const Color(0xFF000000) : const Color(0xFF8A96A3),
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
    ],
  );
}
