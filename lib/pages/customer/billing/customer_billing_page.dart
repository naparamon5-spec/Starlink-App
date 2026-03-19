import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import 'customer_billing_details_page.dart';

const _primary = Color(0xFFEB1E23);
const _inProgress = Color(0xFF0F62FE);
const _success = Color(0xFF24A148);
const _warning = Color(0xFFFF832B);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

const _kPageSize = 15;

class CustomerBillingPage extends StatefulWidget {
  final bool showAppBar;

  const CustomerBillingPage({super.key, this.showAppBar = true});

  @override
  State<CustomerBillingPage> createState() => _CustomerBillingPageState();
}

class _CustomerBillingPageState extends State<CustomerBillingPage> {
  bool _loading = true;

  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _displayedRecords = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  int _currentPage = 0;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_loading &&
        _searchQuery.isEmpty) {
      _loadMoreRecords();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query == _searchQuery) return;
    setState(() => _searchQuery = query);
  }

  List<Map<String, dynamic>> get _filteredRecords {
    if (_searchQuery.isEmpty) return _displayedRecords;
    return _allRecords.where((r) {
      return [
        r['sidr_number'],
        r['cpo_number'],
        r['customer_name'],
        r['amount'],
        r['paid_amount'],
        r['customer_code'],
      ].any((v) => v?.toString().toLowerCase().contains(_searchQuery) == true);
    }).toList();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _allRecords = [];
      _displayedRecords = [];
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final response = await ApiService.getBillingList();

      if (response['status'] == 'success' && response['data'] is List) {
        _allRecords = List<Map<String, dynamic>>.from(
          (response['data'] as List).whereType<Map>().map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );
      }

      final end = _kPageSize.clamp(0, _allRecords.length);
      _displayedRecords = _allRecords.sublist(0, end);
      _hasMore = _allRecords.length > _kPageSize;
    } catch (e) {
      debugPrint('[CustomerBillingPage] _loadAll error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading billing: $e'),
            backgroundColor: _primary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadMoreRecords() {
    if (!_hasMore) return;
    final nextPage = _currentPage + 1;
    final start = nextPage * _kPageSize;
    final end = (start + _kPageSize).clamp(0, _allRecords.length);
    if (start >= _allRecords.length) {
      setState(() => _hasMore = false);
      return;
    }
    setState(() {
      _displayedRecords.addAll(_allRecords.sublist(start, end));
      _currentPage = nextPage;
      if (end >= _allRecords.length) _hasMore = false;
    });
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    final year = int.tryParse(raw.substring(0, raw.length >= 4 ? 4 : 0));
    if (year == null || year < 2000) return '—';
    try {
      final dt = DateTime.parse(raw);
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
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Scaffold(
      backgroundColor: _surfaceSubtle,
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text(
                  'Billing',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                centerTitle: true,
                backgroundColor: _surface,
                elevation: 0,
                iconTheme: const IconThemeData(color: _ink),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: _border),
                ),
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: _primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _SearchBar(controller: _searchController),
              ),
            ),
            // ── Section header — count removed ─────────────────────────
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(title: 'BILLING RECORDS'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver:
                  _loading
                      ? SliverList(
                        delegate: SliverChildListDelegate([
                          const _SkeletonTile(),
                          const SizedBox(height: 10),
                          const _SkeletonTile(),
                          const SizedBox(height: 10),
                          const _SkeletonTile(),
                        ]),
                      )
                      : filtered.isEmpty
                      ? SliverToBoxAdapter(
                        child: _EmptyState(
                          icon: Icons.receipt_long_outlined,
                          message:
                              _searchQuery.isNotEmpty
                                  ? 'No results for "$_searchQuery".'
                                  : 'No billing records found.',
                        ),
                      )
                      : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index == filtered.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child:
                                  _hasMore && _searchQuery.isEmpty
                                      ? const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _primary,
                                          ),
                                        ),
                                      )
                                      : Center(
                                        child: Text(
                                          _searchQuery.isNotEmpty
                                              ? ''
                                              : 'All records loaded',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _inkTertiary,
                                          ),
                                        ),
                                      ),
                            );
                          }

                          final r = filtered[index];
                          final sidrNumber = r['sidr_number']?.toString() ?? '';
                          final cpoNumber = r['cpo_number']?.toString() ?? '';
                          final customerName =
                              r['customer_name']?.toString() ?? '';
                          final amount = r['amount']?.toString() ?? '0.00';
                          final paidAmount =
                              r['paid_amount']?.toString() ?? '0.00';
                          final sidrDate = _formatDate(
                            r['sidr_date']?.toString() ?? '',
                          );
                          final dateUploaded = _formatDate(
                            r['date_uploaded']?.toString() ?? '',
                          );

                          final amountVal = double.tryParse(amount) ?? 0.0;
                          final paidVal = double.tryParse(paidAmount) ?? 0.0;

                          String status;
                          Color statusColor;
                          if (amountVal == 0.0) {
                            status = 'PENDING';
                            statusColor = _warning;
                          } else if (paidVal >= amountVal) {
                            status = 'PAID';
                            statusColor = _success;
                          } else if (paidVal > 0) {
                            status = 'PARTIAL';
                            statusColor = _inProgress;
                          } else {
                            status = 'UNPAID';
                            statusColor = _primary;
                          }

                          final subtitleParts = <String>[];
                          if (cpoNumber.isNotEmpty && cpoNumber != 'n/a') {
                            subtitleParts.add('CPO: $cpoNumber');
                          }
                          if (sidrDate.isNotEmpty && sidrDate != '—') {
                            subtitleParts.add(sidrDate);
                          } else if (dateUploaded.isNotEmpty &&
                              dateUploaded != '—') {
                            subtitleParts.add('Uploaded: $dateUploaded');
                          }
                          if (customerName.isNotEmpty) {
                            subtitleParts.add(customerName);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BillingTile(
                              title:
                                  sidrNumber.isNotEmpty
                                      ? 'SIDR #$sidrNumber'
                                      : 'Billing Record',
                              subtitle: subtitleParts.join(' · '),
                              amount: amount,
                              paidAmount: paidAmount,
                              status: status,
                              statusColor: statusColor,
                              searchQuery: _searchQuery,
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => CustomerBillingDetailsPage(
                                            customerCode:
                                                r['customer_code']
                                                    ?.toString() ??
                                                '',
                                            cpoNumber:
                                                r['cpo_number']?.toString() ??
                                                '',
                                            sidrNumber:
                                                r['sidr_number']?.toString() ??
                                                '',
                                            customerName:
                                                r['customer_name']?.toString(),
                                            prefetchedData: r,
                                          ),
                                    ),
                                  ),
                            ),
                          );
                        }, childCount: filtered.length + 1),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Billing Tile ───────────────────────────────────────────────────────────────

class _BillingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final String paidAmount;
  final String status;
  final Color statusColor;
  final String searchQuery;
  final VoidCallback? onTap;

  const _BillingTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.paidAmount,
    required this.status,
    required this.statusColor,
    this.searchQuery = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightText(
                      text: title,
                      query: searchQuery,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _HighlightText(
                        text: subtitle,
                        query: searchQuery,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _inkTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _AmountChip(
                          label: 'Billed',
                          value: '₱${_fmt(amount)}',
                          color: _inkSecondary,
                        ),
                        const SizedBox(width: 6),
                        _AmountChip(
                          label: 'Paid',
                          value: '₱${_fmt(paidAmount)}',
                          color: _success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _inkTertiary,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(String v) => (double.tryParse(v) ?? 0.0).toStringAsFixed(2);
}

// ── Amount Chip ────────────────────────────────────────────────────────────────

class _AmountChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AmountChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _surfaceSubtle,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _border),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 9,
                color: _inkTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search Bar ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 13,
          color: _ink,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search by SIDR, CPO, customer…',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: _inkTertiary,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _inkTertiary,
            size: 18,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder:
                (_, value, __) =>
                    value.text.isNotEmpty
                        ? GestureDetector(
                          onTap: controller.clear,
                          child: const Icon(
                            Icons.close_rounded,
                            color: _inkTertiary,
                            size: 16,
                          ),
                        )
                        : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

// ── Supporting Widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _inkTertiary,
      letterSpacing: 1.1,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _inkTertiary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _inkSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(query, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: style.copyWith(
            color: _primary,
            backgroundColor: _primary.withOpacity(0.08),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      start = idx + query.length;
    }
    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 11,
                  width: 150,
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 9,
                  width: 220,
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 9,
                  width: 120,
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
