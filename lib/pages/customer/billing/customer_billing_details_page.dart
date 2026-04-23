import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/api_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFFF6F7F9);
const _surface = Color(0xFFFFFFFF);
const _heroTop = Color(0xFF0A1628);
const _heroBot = Color(0xFF0D2444);
const _accent = Color(0xFFEB1E23);
const _accentBlue = Color(0xFF1A6FE8);
const _paidGreen = Color(0xFF00C48C);
const _warningAmber = Color(0xFFF59E0B);
const _inkDark = Color(0xFF0D1B2A);
const _inkMid = Color(0xFF4A5568);
const _inkLight = Color(0xFF9AA5B4);
const _border = Color(0xFFEBEEF2);
const _divider = Color(0xFFF0F4F8);

class CustomerBillingDetailsPage extends StatefulWidget {
  final String customerCode;
  final String cpoNumber;
  final String sidrNumber;
  final String? customerName;
  final Map<String, dynamic>? prefetchedData;

  const CustomerBillingDetailsPage({
    super.key,
    required this.customerCode,
    required this.cpoNumber,
    required this.sidrNumber,
    this.customerName,
    this.prefetchedData,
  });

  @override
  State<CustomerBillingDetailsPage> createState() =>
      _CustomerBillingDetailsPageState();
}

class _CustomerBillingDetailsPageState extends State<CustomerBillingDetailsPage>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  Map<String, dynamic>? _billing;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    if (widget.prefetchedData != null) {
      _billing = Map<String, dynamic>.from(widget.prefetchedData!);
    }
    _tryFetchFromApi();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _tryFetchFromApi() async {
    final code = widget.customerCode.trim();
    final cpo = widget.cpoNumber.trim();
    final sidr = widget.sidrNumber.trim();
    if (code.isEmpty || cpo.isEmpty || sidr.isEmpty) {
      if (_billing != null) _animController.forward();
      return;
    }

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
        if (data is Map && (data).isNotEmpty) {
          setState(() {
            _billing = {
              ...?_billing,
              ...Map<String, dynamic>.from(data as Map),
            };
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _animController.forward();
      }
    }
  }

  Future<void> _reload() async {
    _animController.reset();
    if (widget.prefetchedData != null) {
      setState(
        () => _billing = Map<String, dynamic>.from(widget.prefetchedData!),
      );
    }
    await _tryFetchFromApi();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _str(dynamic v) =>
      (v == null || v.toString() == 'null' || v.toString().trim().isEmpty)
          ? '—'
          : v.toString().trim();

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null' || raw == '0000-00-00') {
      return '—';
    }
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

  String _fmtAmt(dynamic raw) {
    if (raw == null) return '0.00';
    final d = double.tryParse(raw.toString());
    return d != null ? d.toStringAsFixed(2) : raw.toString();
  }

  double _parseAmt(dynamic raw) =>
      double.tryParse(raw?.toString() ?? '0') ?? 0.0;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final b = _billing ?? {};
    final amount = _parseAmt(b['amount']);
    final paid = _parseAmt(b['paid_amount'] ?? b['paidAmount']);
    final balance = amount - paid;
    final isPaid = balance <= 0;
    final progress = amount > 0 ? (paid / amount).clamp(0.0, 1.0) : 0.0;

    final displayName =
        (widget.customerName?.isNotEmpty == true)
            ? widget.customerName!
            : widget.customerCode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body:
            _billing == null && _loading
                ? _buildLoading()
                : _buildBody(
                  b,
                  amount,
                  paid,
                  balance,
                  isPaid,
                  progress,
                  displayName,
                ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_heroTop, _heroBot],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _CircleButton(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
                SizedBox(height: 16),
                Text(
                  'Loading billing details…',
                  style: TextStyle(
                    color: _inkLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    Map<String, dynamic> b,
    double amount,
    double paid,
    double balance,
    bool isPaid,
    double progress,
    String displayName,
  ) {
    return Stack(
      children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Hero AppBar ──────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: _heroTop,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: _CircleButton(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              // actions: [
              //   Padding(
              //     padding: const EdgeInsets.only(right: 12),
              //     child: _CircleButton(
              //       onTap: _loading ? () {} : _reload,
              //       child: const Icon(
              //         Icons.refresh_rounded,
              //         color: Colors.white,
              //         size: 18,
              //       ),
              //     ),
              //   ),
              // ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _HeroHeader(
                  displayName: displayName,
                  sidrNumber: widget.sidrNumber,
                  cpoNumber: widget.cpoNumber,
                  isPaid: isPaid,
                  progress: progress,
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Payment status banner ────────────────────
                        _PaymentBanner(
                          isPaid: isPaid,
                          amount: amount,
                          paid: paid,
                          balance: balance,
                          progress: progress,
                          fmtAmt: _fmtAmt,
                        ),
                        const SizedBox(height: 24),

                        // ── Summary stat row ─────────────────────────
                        const _SectionLabel(label: 'PAYMENT OVERVIEW'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Total Billed',
                                value: '₱${_fmtAmt(amount)}',
                                icon: Icons.receipt_long_rounded,
                                color: _accentBlue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                label: 'Amount Paid',
                                value: '₱${_fmtAmt(paid)}',
                                icon: Icons.check_circle_outline_rounded,
                                color: _paidGreen,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                label: isPaid ? 'Overpayment' : 'Balance Due',
                                value: '₱${_fmtAmt(balance.abs())}',
                                icon:
                                    isPaid
                                        ? Icons.verified_rounded
                                        : Icons.pending_outlined,
                                color: isPaid ? _paidGreen : _accent,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Billing info ─────────────────────────────
                        const _SectionLabel(label: 'BILLING INFORMATION'),
                        const SizedBox(height: 12),
                        _InfoCard(
                          billing: b,
                          str: _str,
                          formatDate: _formatDate,
                        ),

                        const SizedBox(height: 24),

                        // ── Payment detail ───────────────────────────
                        const _SectionLabel(label: 'PAYMENT DETAIL'),
                        const SizedBox(height: 12),
                        _PaymentDetailCard(
                          amount: amount,
                          paid: paid,
                          balance: balance,
                          isPaid: isPaid,
                          progress: progress,
                          fmtAmt: _fmtAmt,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // ── Loading indicator strip ──────────────────────────────────
        if (_loading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: _accent,
              backgroundColor: _accent.withOpacity(0.15),
              minHeight: 3,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Header
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String displayName;
  final String sidrNumber;
  final String cpoNumber;
  final bool isPaid;
  final double progress;

  const _HeroHeader({
    required this.displayName,
    required this.sidrNumber,
    required this.cpoNumber,
    required this.isPaid,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_heroTop, _heroBot],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: _DecorCircle(
              size: 200,
              color: Colors.white.withOpacity(0.03),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -30,
            child: _DecorCircle(
              size: 140,
              color: Colors.white.withOpacity(0.025),
            ),
          ),
          Positioned(
            top: 80,
            right: 60,
            child: _DecorCircle(
              size: 60,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 56,
              24,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white54,
                        size: 13,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'BILLING',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.tag_rounded,
                      color: Colors.white.withOpacity(0.5),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'SIDR $sidrNumber',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'CPO $cpoNumber',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
// Payment Banner
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentBanner extends StatelessWidget {
  final bool isPaid;
  final double amount;
  final double paid;
  final double balance;
  final double progress;
  final String Function(dynamic) fmtAmt;

  const _PaymentBanner({
    required this.isPaid,
    required this.amount,
    required this.paid,
    required this.balance,
    required this.progress,
    required this.fmtAmt,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPaid ? _paidGreen : _accent;
    final progressColor =
        progress >= 1.0
            ? _paidGreen
            : progress >= 0.5
            ? _warningAmber
            : _accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaid
                      ? Icons.verified_rounded
                      : Icons.account_balance_wallet_outlined,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaid ? 'Fully Paid' : 'Payment Outstanding',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isPaid
                          ? 'This billing record has been settled.'
                          : 'Balance of ₱${fmtAmt(balance.abs())} remaining.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _inkMid,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              _PulseDot(color: color, active: !isPaid),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(1)}% paid',
                style: TextStyle(
                  fontSize: 10,
                  color: progressColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₱${fmtAmt(paid)} of ₱${fmtAmt(amount)}',
                style: const TextStyle(fontSize: 10, color: _inkLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
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
              fontSize: 12,
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
            style: const TextStyle(fontSize: 9, color: _inkLight, height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Card
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> billing;
  final String Function(dynamic) str;
  final String Function(String?) formatDate;

  const _InfoCard({
    required this.billing,
    required this.str,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final b = billing;
    final rows = [
      if (str(b['customer_name'] ?? b['customerName']) != '—')
        _KVPair('Customer Name', str(b['customer_name'] ?? b['customerName'])),
      // _KVPair('Customer Code', str(b['customer_code'] ?? b['customerCode'])),
      _KVPair('CPO Number', str(b['cpo_number'] ?? b['cpoNumber'])),
      _KVPair(
        'CPO Date',
        formatDate((b['cpo_date'] ?? b['cpoDate'])?.toString()),
      ),
      _KVPair('SIDR Number', str(b['sidr_number'] ?? b['sidrNumber'])),
      _KVPair(
        'SIDR Date',
        formatDate((b['sidr_date'] ?? b['sidrDate'])?.toString()),
      ),
      // _KVPair(
      //   'Date Uploaded',
      //   formatDate((b['date_uploaded'] ?? b['dateUploaded'])?.toString()),
      // ),
      // _KVPair('Uploaded By', str(b['uploaded_by'] ?? b['uploadedBy'])),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _CardHeader(
            icon: Icons.info_outline_rounded,
            iconColor: _accentBlue,
            label: 'Billing Information',
          ),
          const _HDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  _KVRow(label: rows[i].label, value: rows[i].value),
                  if (i < rows.length - 1) ...[
                    const SizedBox(height: 4),
                    const _HDivider(),
                    const SizedBox(height: 4),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KVPair {
  final String label;
  final String value;
  const _KVPair(this.label, this.value);
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Detail Card
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentDetailCard extends StatelessWidget {
  final double amount;
  final double paid;
  final double balance;
  final bool isPaid;
  final double progress;
  final String Function(dynamic) fmtAmt;

  const _PaymentDetailCard({
    required this.amount,
    required this.paid,
    required this.balance,
    required this.isPaid,
    required this.progress,
    required this.fmtAmt,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor =
        progress >= 1.0
            ? _paidGreen
            : progress >= 0.5
            ? _warningAmber
            : _accent;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _CardHeader(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: _paidGreen,
            label: 'Payment Summary',
            trailing: _StatusBadge(
              label: isPaid ? 'PAID' : 'OUTSTANDING',
              color: isPaid ? _paidGreen : _accent,
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
                          ? 'Fully settled'
                          : 'Balance: ₱${fmtAmt(balance.abs())}',
                      style: const TextStyle(fontSize: 11, color: _inkLight),
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
                const SizedBox(height: 14),
                _AmountRow(
                  label: 'Total Amount',
                  value: '₱${fmtAmt(amount)}',
                  bold: true,
                  color: _inkDark,
                ),
                const SizedBox(height: 10),
                _AmountRow(
                  label: 'Amount Paid',
                  value: '₱${fmtAmt(paid)}',
                  color: _paidGreen,
                ),
                const SizedBox(height: 10),
                _AmountRow(
                  label: isPaid ? 'Overpayment' : 'Outstanding Balance',
                  value: '₱${fmtAmt(balance.abs())}',
                  color: isPaid ? _paidGreen : _accent,
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
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _inkDark,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _KVRow extends StatelessWidget {
  final String label;
  final String value;
  const _KVRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _inkLight,
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
              color: _inkDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
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
          color: bold ? _inkDark : _inkLight,
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3), width: 1.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: _inkLight,
      letterSpacing: 1.4,
    ),
  );
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) => Container(height: 1, color: _divider);
}

class _CircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _CircleButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Center(child: child),
    ),
  );
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _DecorCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1.5),
    ),
  );
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool active;
  const _PulseDot({required this.color, required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    if (widget.active) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _ctrl,
              builder:
                  (_, __) => Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withOpacity(_opacity.value),
                      ),
                    ),
                  ),
            ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}
