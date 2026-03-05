import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import 'admin_billing_details_page.dart';

class AdminBillingPage extends StatefulWidget {
  const AdminBillingPage({super.key});

  @override
  State<AdminBillingPage> createState() => _AdminBillingPageState();
}

class _AdminBillingPageState extends State<AdminBillingPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _billingList = [];
  bool _loading = false;
  String? _error;
  late AnimationController _animController;

  static const _primary = Color(0xFF0F62FE);
  static const _success = Color(0xFF24A148);
  static const _danger = Color(0xFFDA1E28);
  static const _ink = Color(0xFF161616);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadBilling();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadBilling() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getBillingList();
      if (!mounted) return;

      if (response['status'] != 'success') {
        setState(() {
          _loading = false;
          _error = response['message']?.toString() ?? 'Failed to load billing';
          _billingList = [];
        });
        return;
      }

      final data = response['data'];
      final List<dynamic> items = data is List ? data : [];

      setState(() {
        _billingList =
            items
                .whereType<Map>()
                .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e as Map),
                )
                .toList();
        _loading = false;
      });
      _animController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _billingList = [];
      });
    }
  }

  void _openDetails(Map<String, dynamic> b) {
    // Pass the full record as prefetchedData — the details page will
    // show this data immediately and optionally try the API too.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AdminBillingDetailsPage(
              customerCode:
                  (b['customer_code'] ?? b['customerCode'] ?? '').toString(),
              cpoNumber: (b['cpo_number'] ?? b['cpoNumber'] ?? '').toString(),
              sidrNumber:
                  (b['sidr_number'] ?? b['sidrNumber'] ?? '').toString(),
              customerName:
                  (b['customer_name'] ?? b['customerName'] ?? '').toString(),
              prefetchedData: b,
            ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '0000-00-00') return '—';
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
    if (raw == null || raw.toString().isEmpty) return '0.00';
    final d = double.tryParse(raw.toString());
    return d != null ? d.toStringAsFixed(2) : raw.toString();
  }

  String _formatAmountShort(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _billingList.fold<double>(
      0,
      (s, b) => s + (double.tryParse((b['amount'] ?? '0').toString()) ?? 0),
    );
    final totalPaid = _billingList.fold<double>(
      0,
      (s, b) =>
          s + (double.tryParse((b['paid_amount'] ?? '0').toString()) ?? 0),
    );
    final outstanding = totalAmount - totalPaid;

    return Scaffold(
      backgroundColor: _surface,
      body:
          _loading
              ? _buildLoader()
              : _error != null
              ? _buildError()
              : RefreshIndicator(
                onRefresh: _loadBilling,
                color: _primary,
                strokeWidth: 2,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeroBanner(
                        totalAmount,
                        totalPaid,
                        outstanding,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildStatChips(
                        totalAmount,
                        totalPaid,
                        outstanding,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                        child: Row(
                          children: [
                            const Text(
                              'Billing Records',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_billingList.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _loadBilling,
                              child: const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: _inkTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_billingList.isEmpty)
                      SliverFillRemaining(child: _buildEmpty())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) {
                                final t = (_animController.value - index * 0.07)
                                    .clamp(0.0, 1.0);
                                return Opacity(
                                  opacity: t,
                                  child: Transform.translate(
                                    offset: Offset(0, 16 * (1 - t)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildBillingCard(_billingList[index]),
                              ),
                            ),
                            childCount: _billingList.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeroBanner(
    double totalAmount,
    double totalPaid,
    double outstanding,
  ) {
    final progress =
        totalAmount > 0 ? (totalPaid / totalAmount).clamp(0.0, 1.0) : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F62FE), Color(0xFF0043CE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Billing Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Total Billed',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₱${_formatAmountShort(totalAmount)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF42BE65),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _HeroChip(
                label: 'Collected',
                value: '₱${_formatAmountShort(totalPaid)}',
                color: const Color(0xFF42BE65),
              ),
              const SizedBox(width: 10),
              _HeroChip(
                label: 'Outstanding',
                value: '₱${_formatAmountShort(outstanding)}',
                color: const Color(0xFFFFB3B8),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChips(
    double totalAmount,
    double totalPaid,
    double outstanding,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _StatPill(
            icon: Icons.receipt_long_outlined,
            label: 'Records',
            value: '${_billingList.length}',
            color: _primary,
          ),
          const SizedBox(width: 10),
          _StatPill(
            icon: Icons.check_circle_outline_rounded,
            label: 'Paid',
            value: '₱${_formatAmountShort(totalPaid)}',
            color: _success,
          ),
          const SizedBox(width: 10),
          _StatPill(
            icon: Icons.pending_outlined,
            label: 'Balance',
            value: '₱${_formatAmountShort(outstanding)}',
            color: outstanding > 0 ? _danger : _success,
          ),
        ],
      ),
    );
  }

  Widget _buildBillingCard(Map<String, dynamic> b) {
    final customerName =
        (b['customer_name'] ?? b['customerName'] ?? '—').toString();
    final customerCode =
        (b['customer_code'] ?? b['customerCode'] ?? '—').toString();
    final cpoNumber = (b['cpo_number'] ?? b['cpoNumber'] ?? '—').toString();
    final sidrNumber = (b['sidr_number'] ?? b['sidrNumber'] ?? '—').toString();
    final cpoDate = _formatDate((b['cpo_date'] ?? b['cpoDate'])?.toString());
    final uploadedBy = (b['uploaded_by'] ?? b['uploadedBy'] ?? '').toString();
    final amountD = double.tryParse((b['amount'] ?? '0').toString()) ?? 0;
    final paidD = double.tryParse((b['paid_amount'] ?? '0').toString()) ?? 0;
    final progress = amountD > 0 ? (paidD / amountD).clamp(0.0, 1.0) : 0.0;
    final isPaid = paidD >= amountD && amountD > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(b),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          customerName.isNotEmpty
                              ? customerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _ink,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusTag(isPaid: isPaid),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$customerCode · CPO: $cpoNumber',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _inkSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'SIDR: $sidrNumber${cpoDate != "—" ? " · $cpoDate" : ""}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _inkTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: _surfaceSubtle),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 10,
                                color: _inkTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₱${_formatAmount(b['amount'])}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Paid',
                              style: TextStyle(
                                fontSize: 10,
                                color: _inkTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₱${_formatAmount(b['paid_amount'])}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isPaid ? _success : _primary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (uploadedBy.isNotEmpty)
                              Text(
                                'by $uploadedBy',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _inkTertiary,
                                ),
                              ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: _inkTertiary,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: _surfaceSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isPaid ? _success : _primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
        ),
        SizedBox(height: 14),
        Text(
          'Loading billing records…',
          style: TextStyle(fontSize: 13, color: _inkSecondary),
        ),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _danger.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _danger,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: _inkSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _loadBilling,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _surfaceSubtle,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: _inkTertiary,
            size: 26,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No billing records found',
          style: TextStyle(fontSize: 14, color: _inkSecondary),
        ),
      ],
    ),
  );
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _HeroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HeroChip({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color.withOpacity(0.8),
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6F6F6F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusTag extends StatelessWidget {
  final bool isPaid;
  const _StatusTag({required this.isPaid});
  @override
  Widget build(BuildContext context) {
    final color = isPaid ? const Color(0xFF24A148) : const Color(0xFFFF832B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPaid ? 'PAID' : 'OPEN',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
