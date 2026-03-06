import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import 'admin_subscription_details_page.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23); // Brand red
const _primaryDark = Color(0xFF760F12); // Dark red
const _success = Color(0xFF24A148);
const _danger = Color(0xFFEB1E23);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  State<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _subscriptions = [];
  bool _loading = false;
  String? _error;

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptions({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getSubscriptionsPaginated(
        page: page,
        limit: 10,
        search: _searchQuery,
      );

      if (!mounted) return;

      if (response['status'] != 'success') {
        setState(() {
          _loading = false;
          _error =
              response['message']?.toString() ?? 'Failed to load subscriptions';
          _subscriptions = [];
        });
        return;
      }

      final data = response['data'];
      final List<dynamic> items = data is List ? data : [];
      final pagination = response['pagination'];
      int currentPage = page;
      int totalPages = 1;
      int totalItems = 0;
      if (pagination is Map<String, dynamic>) {
        currentPage =
            (pagination['currentPage'] ?? pagination['current_page'] ?? page)
                as int;
        totalPages =
            (pagination['totalPages'] ?? pagination['total_pages'] ?? 1) as int;
        totalItems =
            (pagination['totalItems'] ?? pagination['total_items'] ?? 0) as int;
      }

      setState(() {
        _subscriptions =
            items
                .whereType<Map>()
                .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e as Map),
                )
                .toList();
        _currentPage = currentPage;
        _totalPages = totalPages;
        _totalItems = totalItems;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _subscriptions = [];
      });
    }
  }

  void _openDetails(Map<String, dynamic> sub) {
    final serviceLineNumber = sub['serviceLineNumber']?.toString() ?? '';
    final nickname = sub['nickname']?.toString() ?? '';
    if (serviceLineNumber.trim().isEmpty || serviceLineNumber == '—') return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AdminSubscriptionDetailsPage(
              serviceLineNumber: serviceLineNumber.trim(),
              title:
                  nickname.trim().isNotEmpty
                      ? nickname.trim()
                      : serviceLineNumber.trim(),
            ),
      ),
    );
  }

  Color _activeColor(String? active) {
    final a = (active ?? '').toString().toUpperCase();
    if (a == 'ACTIVE') return _success;
    if (a == 'EXPIRED' || a == 'CANCELLED') return _primaryDark;
    return _inkTertiary;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '0000-00-00') return '—';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surfaceSubtle,
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            color: _surface,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Subscriptions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      _searchQuery = val;
                      _loadSubscriptions(page: 1);
                    },
                    style: const TextStyle(fontSize: 13, color: _ink),
                    decoration: const InputDecoration(
                      hintText: 'Search subscriptions...',
                      hintStyle: TextStyle(color: _inkTertiary, fontSize: 13),
                      prefixIcon: Icon(
                        Icons.search,
                        color: _inkTertiary,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (!_loading && _error == null)
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_subscriptions.length} of $_totalItems subscriptions',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Container(height: 1, color: _border),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child:
                _loading
                    ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              color: _primary,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Loading subscriptions…',
                            style: TextStyle(
                              fontSize: 13,
                              color: _inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _error != null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _danger.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.error_outline_rounded,
                                color: _danger,
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
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed:
                                  () => _loadSubscriptions(page: _currentPage),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Try again'),
                              style: TextButton.styleFrom(
                                foregroundColor: _primary,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : _subscriptions.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _surfaceSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.subscriptions_outlined,
                              color: _inkTertiary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No subscriptions found.',
                            style: TextStyle(
                              fontSize: 14,
                              color: _inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _subscriptions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final sub = _subscriptions[index];
                        final id = sub['id']?.toString() ?? '—';
                        final serviceLineNumber =
                            sub['serviceLineNumber']?.toString() ?? '—';
                        final nickname = sub['nickname']?.toString() ?? '—';
                        final active = sub['active']?.toString() ?? '—';
                        final startDate = _formatDate(
                          sub['startDate']?.toString(),
                        );
                        final endDate = _formatDate(sub['endDate']?.toString());
                        final subscriptionPlan =
                            sub['subscriptionPlan']?.toString() ?? '—';
                        final address = sub['address']?.toString() ?? '';
                        final dataplan = sub['dataplan']?.toString() ?? '—';
                        final endUserName =
                            sub['end_user_name']?.toString() ??
                            sub['company_name']?.toString() ??
                            '';
                        final canNavigate =
                            serviceLineNumber.trim().isNotEmpty &&
                            serviceLineNumber != '—';
                        final color = _activeColor(active);

                        final initial =
                            nickname.isNotEmpty
                                ? nickname[0].toUpperCase()
                                : '?';

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canNavigate ? () => _openDetails(sub) : null,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
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
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      14,
                                      14,
                                      10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Avatar
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: _primary.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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

                                        // Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      nickname,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        color: _ink,
                                                        letterSpacing: -0.2,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: color.withOpacity(
                                                        0.08,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      active,
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: color,
                                                        letterSpacing: 0.4,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'ID: $id · $serviceLineNumber',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: _inkSecondary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (subscriptionPlan != '—')
                                                Text(
                                                  'Plan: $subscriptionPlan',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: _inkTertiary,
                                                  ),
                                                ),
                                              if (address.isNotEmpty)
                                                Text(
                                                  address,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: _inkTertiary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              if (endUserName.isNotEmpty)
                                                Text(
                                                  'End user: $endUserName',
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
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      10,
                                      14,
                                      12,
                                    ),
                                    child: Row(
                                      children: [
                                        _DateChip(
                                          label: 'Start',
                                          value: startDate,
                                        ),
                                        const SizedBox(width: 8),
                                        _DateChip(label: 'End', value: endDate),
                                        if (dataplan != '—') ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _primary.withOpacity(0.06),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '$dataplan GB',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: _primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        if (canNavigate)
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: _inkTertiary,
                                            size: 16,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),

          // ── Pagination ────────────────────────────────────────────────────
          if (_totalPages > 1)
            Container(
              color: _surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PaginationButton(
                    label: 'Previous',
                    enabled: _currentPage > 1,
                    onTap: () => _loadSubscriptions(page: _currentPage - 1),
                  ),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _inkSecondary,
                    ),
                  ),
                  _PaginationButton(
                    label: 'Next',
                    enabled: _currentPage < _totalPages,
                    onTap: () => _loadSubscriptions(page: _currentPage + 1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String value;
  const _DateChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: _inkTertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            color: _inkSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? _primary.withOpacity(0.08) : _surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? _primary.withOpacity(0.25) : _border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: enabled ? _primary : _inkTertiary,
          ),
        ),
      ),
    );
  }
}
