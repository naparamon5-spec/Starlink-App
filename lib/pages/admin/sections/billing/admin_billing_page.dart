import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import 'admin_billing_details_page.dart';
// import 'package:starlink_app/components/UploadBillingDialog.dart';

class AdminBillingPage extends StatefulWidget {
  const AdminBillingPage({super.key});

  @override
  State<AdminBillingPage> createState() => _AdminBillingPageState();
}

class _AdminBillingPageState extends State<AdminBillingPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 278.0;

  void _measureHeader() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _headerKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final h = box.size.height;
      if (h > 0 && (h - _headerHeight).abs() > 1) {
        setState(() => _headerHeight = h);
      }
    });
  }

  List<Map<String, dynamic>> _allBilling = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = false;
  String? _error;

  static const _primary = Color(0xFFEB1E23);
  static const _primaryDark = Color(0xFF760F12);
  static const _success = Color(0xFF24A148);
  static const _danger = Color(0xFFEB1E23);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
    _loadBilling();
    _measureHeader();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered =
          q.isEmpty
              ? _allBilling
              : _allBilling.where((b) {
                final name =
                    (b['customer_name'] ?? b['customerName'] ?? '')
                        .toString()
                        .toLowerCase();
                final code =
                    (b['customer_code'] ?? b['customerCode'] ?? '')
                        .toString()
                        .toLowerCase();
                final cpo =
                    (b['cpo_number'] ?? b['cpoNumber'] ?? '')
                        .toString()
                        .toLowerCase();
                final sidr =
                    (b['sidr_number'] ?? b['sidrNumber'] ?? '')
                        .toString()
                        .toLowerCase();
                final sln =
                    (b['service_line_number'] ?? b['serviceLineNumber'] ?? '')
                        .toString()
                        .toLowerCase();
                return name.contains(q) ||
                    code.contains(q) ||
                    cpo.contains(q) ||
                    sidr.contains(q) ||
                    sln.contains(q);
              }).toList();
    });
  }

  Future<void> _loadBilling() async {
    setState(() {
      _loading = true;
      _error = null;
      _allBilling = [];
      _filtered = [];
    });
    try {
      final response = await ApiService.getBillingList();
      if (!mounted) return;
      if (response['status'] != 'success') {
        setState(() {
          _loading = false;
          _error = response['message']?.toString() ?? 'Failed to load billing';
        });
        return;
      }
      final data = response['data'];
      final List<dynamic> items = data is List ? data : [];
      final list =
          items
              .whereType<Map>()
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
      setState(() {
        _allBilling = list;
        _filtered = list;
        _loading = false;
      });
      // Re-apply search if user typed while loading
      if (_searchController.text.isNotEmpty) _onSearch();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ── Export CSV ─────────────────────────────────────────────────────────────

  Future<void> _exportBilling() async {
    if (_allBilling.isEmpty) {
      _showSnack('No billing records to export.', isError: true);
      return;
    }
    try {
      final headers = [
        'customer_code',
        'customer_name',
        'cpo_number',
        'sidr_number',
        'service_line_number',
        'nickname',
        'service_plan',
        'service_plan_fee',
        'billing_period_from',
        'billing_period_to',
        'total_amount',
        'paid_amount',
      ];

      String toCamel(String s) {
        final p = s.split('_');
        return p[0] +
            p.skip(1).map((x) => x[0].toUpperCase() + x.substring(1)).join();
      }

      String csvVal(String v) =>
          (v.contains(',') || v.contains('\n') || v.contains('"'))
              ? '"${v.replaceAll('"', '""')}"'
              : v;

      final rows = [
        headers.join(','),
        ..._allBilling.map(
          (b) => headers
              .map((h) => csvVal((b[h] ?? b[toCamel(h)] ?? '').toString()))
              .join(','),
        ),
      ];
      final csv = rows.join('\n');

      try {
        final dir = await FilePicker.platform.getDirectoryPath();
        if (dir != null) {
          final ts =
              DateTime.now()
                  .toIso8601String()
                  .replaceAll(':', '-')
                  .split('.')[0];
          await File('$dir/billing_export_$ts.csv').writeAsString(csv);
          _showSnack('Exported successfully.');
        } else {
          _showSnack('Export cancelled.');
        }
      } catch (_) {
        _showExportPreview(csv);
      }
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    }
  }

  void _showExportPreview(String csv) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Export Preview',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: SingleChildScrollView(
                child: Text(
                  csv,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _danger : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openDetails(Map<String, dynamic> b) {
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

  // ── Formatters ─────────────────────────────────────────────────────────────

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '0000-00-00') return '—';
    try {
      final dt = DateTime.parse(raw);
      if (dt.year < 1900) return '—';
      const m = [
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
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw.contains('T') ? raw.split('T').first : raw;
    }
  }

  String _formatAmount(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return '0.00';
    final d = double.tryParse(raw.toString());
    return d != null ? d.toStringAsFixed(2) : raw.toString();
  }

  String _formatAmountShort(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  double _parseAmount(Map<String, dynamic> b) =>
      double.tryParse((b['total_amount'] ?? b['amount'] ?? '0').toString()) ??
      0;

  double _parsePaid(Map<String, dynamic> b) =>
      double.tryParse(
        (b['paid_amount'] ?? b['paidAmount'] ?? '0').toString(),
      ) ??
      0;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalAmount = _allBilling.fold<double>(
      0,
      (s, b) => s + _parseAmount(b),
    );
    final totalPaid = _allBilling.fold<double>(0, (s, b) => s + _parsePaid(b));
    final outstanding = totalAmount - totalPaid;

    return ColoredBox(
      color: _surface,
      child:
          _loading
              ? _buildLoader()
              : _error != null && _allBilling.isEmpty
              ? _buildError()
              : RefreshIndicator(
                onRefresh: _loadBilling,
                color: _primary,
                strokeWidth: 2,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Pinned header ──────────────────────────────────
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyHeaderDelegate(
                        height: _headerHeight,
                        child: _buildStickyHeader(
                          totalAmount,
                          totalPaid,
                          outstanding,
                        ),
                      ),
                    ),

                    // ── Body ──────────────────────────────────────────
                    if (_filtered.isEmpty)
                      SliverFillRemaining(child: _buildEmpty())
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: RepaintBoundary(
                                child: _BillingCard(
                                  billing: _filtered[index],
                                  onTap: () => _openDetails(_filtered[index]),
                                  formatDate: _formatDate,
                                  formatAmount: _formatAmount,
                                  parseAmount: _parseAmount,
                                  parsePaid: _parsePaid,
                                ),
                              ),
                            ),
                            childCount: _filtered.length,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'All ${_filtered.length} record${_filtered.length == 1 ? '' : 's'} loaded',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _inkTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }

  // ── Sticky header ──────────────────────────────────────────────────────────

  Widget _buildStickyHeader(
    double totalAmount,
    double totalPaid,
    double outstanding,
  ) {
    final progress =
        totalAmount > 0 ? (totalPaid / totalAmount).clamp(0.0, 1.0) : 0.0;

    return ColoredBox(
      key: _headerKey,
      color: _surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Billing overview banner ──────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Billed',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '₱${_formatAmountShort(totalAmount)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _HeroChip(
                          label: 'Collected',
                          value: '₱${_formatAmountShort(totalPaid)}',
                          color: const Color(0xFF42BE65),
                        ),
                        const SizedBox(height: 4),
                        _HeroChip(
                          label: 'Outstanding',
                          value: '₱${_formatAmountShort(outstanding)}',
                          color: const Color(0xFFFFB3B8),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF42BE65),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}% collected',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search bar ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: InputDecoration(
                  hintText: 'Search by customer, CPO, SIDR…',
                  hintStyle: const TextStyle(fontSize: 13, color: _inkTertiary),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: _inkTertiary,
                  ),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: _inkTertiary,
                            ),
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
          ),

          // ── List title row ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Billing',
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
                    '${_filtered.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
                const Spacer(),
                // GestureDetector(
                //   onTap: _loadBilling,
                //   child: const Padding(
                //     padding: EdgeInsets.symmetric(horizontal: 8),
                //     child: Icon(
                //       Icons.refresh_rounded,
                //       size: 18,
                //       color: _inkTertiary,
                //     ),
                //   ),
                // ),
                // GestureDetector(
                //   onTap: _exportBilling,
                //   child: Container(
                //     padding: const EdgeInsets.symmetric(
                //       horizontal: 12,
                //       vertical: 7,
                //     ),
                //     decoration: BoxDecoration(
                //       color: const Color(0xFF0F62FE).withOpacity(0.08),
                //       borderRadius: BorderRadius.circular(10),
                //       border: Border.all(
                //         color: const Color(0xFF0F62FE).withOpacity(0.2),
                //       ),
                //     ),
                //     child: const Row(
                //       mainAxisSize: MainAxisSize.min,
                //       children: [
                //         Icon(
                //           Icons.file_download_outlined,
                //           size: 14,
                //           color: Color(0xFF0F62FE),
                //         ),
                //         SizedBox(width: 4),
                //         Text(
                //           'Export',
                //           style: TextStyle(
                //             fontSize: 12,
                //             fontWeight: FontWeight.w700,
                //             color: Color(0xFF0F62FE),
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
              ],
            ),
          ),

          Container(height: 1, color: _border),
        ],
      ),
    );
  }

  // ── State widgets ──────────────────────────────────────────────────────────

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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: _inkSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
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
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: _surfaceSubtle,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: _inkTertiary,
            size: 24,
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

// ── Sticky header delegate ─────────────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _StickyHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(height: height, child: child);

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) => old.height != height;
}

// ── Billing card ───────────────────────────────────────────────────────────────

class _BillingCard extends StatelessWidget {
  final Map<String, dynamic> billing;
  final VoidCallback onTap;
  final String Function(String?) formatDate;
  final String Function(dynamic) formatAmount;
  final double Function(Map<String, dynamic>) parseAmount;
  final double Function(Map<String, dynamic>) parsePaid;

  static const _primary = Color(0xFFEB1E23);
  static const _success = Color(0xFF24A148);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  const _BillingCard({
    required this.billing,
    required this.onTap,
    required this.formatDate,
    required this.formatAmount,
    required this.parseAmount,
    required this.parsePaid,
  });

  @override
  Widget build(BuildContext context) {
    final b = billing;
    final customerName =
        (b['customer_name'] ?? b['customerName'] ?? '—').toString();
    final customerCode =
        (b['customer_code'] ?? b['customerCode'] ?? '—').toString();
    final cpoNumber = (b['cpo_number'] ?? b['cpoNumber'] ?? '—').toString();
    final sidrNumber = (b['sidr_number'] ?? b['sidrNumber'] ?? '—').toString();
    final cpoDate = formatDate((b['cpo_date'] ?? b['cpoDate'])?.toString());
    final uploadedBy = (b['uploaded_by'] ?? b['uploadedBy'] ?? '').toString();

    final amountD = parseAmount(b);
    final paidD = parsePaid(b);
    final progress = amountD > 0 ? (paidD / amountD).clamp(0.0, 1.0) : 0.0;
    final isPaid = paidD >= amountD && amountD > 0;
    final statusColor = isPaid ? _success : const Color(0xFFFF832B);

    final initial =
        customerName.isNotEmpty ? customerName[0].toUpperCase() : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _ink,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPaid ? 'PAID' : 'OPEN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Code + CPO
                      Text(
                        '$customerCode · CPO: $cpoNumber',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _inkSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // SIDR + date meta tags
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _MetaTag(label: 'SIDR', value: sidrNumber),
                          if (cpoDate != '—') ...[
                            const SizedBox(width: 6),
                            _MetaTag(label: 'Date', value: cpoDate),
                          ],
                        ],
                      ),

                      const SizedBox(height: 8),
                      Container(height: 1, color: _border),
                      const SizedBox(height: 8),

                      // Footer: amounts + progress + chevron
                      Row(
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
                                '₱${formatAmount(b['total_amount'] ?? b['amount'])}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                '₱${formatAmount(b['paid_amount'] ?? b['paidAmount'])}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isPaid ? _success : _primary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
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
                            size: 18,
                            color: _inkTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Progress bar
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
      ),
    );
  }
}

// ── Meta tag ───────────────────────────────────────────────────────────────────

class _MetaTag extends StatelessWidget {
  final String label, value;
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  const _MetaTag({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: _surfaceSubtle,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: _border),
    ),
    child: Text(
      '$label: $value',
      style: const TextStyle(
        fontSize: 9,
        color: _inkTertiary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ── Hero chip ──────────────────────────────────────────────────────────────────

class _HeroChip extends StatelessWidget {
  final String label, value;
  final Color color;

  const _HeroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color.withOpacity(0.8),
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}
