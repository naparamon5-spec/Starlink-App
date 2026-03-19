import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _activeGreen = Color(0xFF24A148);
const _inactiveRed = Color(0xFFFF4757);
const _ink = Color(0xFF1B1B1B);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);
const _danger = Color(0xFFE57373);

const _kPageSize = 10;

bool _isActiveSub(Map<String, dynamic> sub) {
  for (final field in [
    'is_active',
    'isActive',
    'active',
    'status',
    'enabled',
  ]) {
    final v = sub[field];
    if (v == true ||
        v == 1 ||
        v == '1' ||
        v == 'true' ||
        v == 'active' ||
        v == 'enabled') {
      return true;
    }
  }
  return false;
}

class EndUserSubscriptionPage extends StatefulWidget {
  const EndUserSubscriptionPage({super.key});

  @override
  State<EndUserSubscriptionPage> createState() =>
      _EndUserSubscriptionPageState();
}

class _EndUserSubscriptionPageState extends State<EndUserSubscriptionPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _subscriptions = [];
  bool _loading = false;
  String? _error;

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchQuery = '';
  DateTime? _lastSearch;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSubscriptions(page: 1);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;
    final now = DateTime.now();
    _lastSearch = now;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_lastSearch != now || !mounted) return;
      setState(() {
        _searchQuery = query;
        _currentPage = 1;
      });
      _loadSubscriptions(page: 1);
    });
  }

  Future<void> _loadSubscriptions({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getSubscriptionsPaginated(
        page: page,
        limit: _kPageSize,
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
            int.tryParse(
              (pagination['currentPage'] ?? pagination['current_page'] ?? page)
                  .toString(),
            ) ??
            page;
        totalPages =
            int.tryParse(
              (pagination['totalPages'] ?? pagination['total_pages'] ?? 1)
                  .toString(),
            ) ??
            1;
        totalItems =
            int.tryParse(
              (pagination['totalItems'] ?? pagination['total_items'] ?? 0)
                  .toString(),
            ) ??
            0;
      }

      setState(() {
        _subscriptions =
            items
                .whereType<Map>()
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
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
        _error = e.toString().replaceAll('Exception: ', '');
        _subscriptions = [];
      });
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    _loadSubscriptions(page: page);
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold — this widget is embedded inside a parent that owns the Scaffold.
    // Using a plain Container fills the tab body correctly.
    return Container(
      color: _surfaceSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Search bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, color: _primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13, color: _ink),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        hintText: 'Search subscriptions...',
                        hintStyle: TextStyle(
                          color: _inkSecondary,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (_, value, __) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: _searchController.clear,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(
                            Icons.close_rounded,
                            color: _inkTertiary,
                            size: 16,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Section header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'All subscriptions ($_totalItems)'
                        : 'Results for "$_searchQuery" ($_totalItems)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  ),
              ],
            ),
          ),

          // ── List / states ────────────────────────────────────────────────
          Expanded(
            child:
                _error != null
                    ? _buildError()
                    : _loading && _subscriptions.isEmpty
                    ? _buildSkeletons()
                    : _subscriptions.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                      onRefresh: () => _loadSubscriptions(page: _currentPage),
                      color: _primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _subscriptions.length,
                        itemBuilder: (_, i) => _buildCard(_subscriptions[i]),
                      ),
                    ),
          ),

          // ── Pagination ───────────────────────────────────────────────────
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> sub) {
    final nickname = _str(sub['nickname'] ?? sub['name'] ?? sub['site_name']);
    final sln = _str(sub['serviceLineNumber'] ?? sub['service_line_number']);
    final isActive = _isActiveSub(sub);
    final statusColor = isActive ? _activeGreen : _inactiveRed;
    final startDate = _str(
      sub['start_date'] ?? sub['start_at'] ?? sub['startDate'],
    );
    final endDate = _str(
      sub['end_date'] ??
          sub['expires_at'] ??
          sub['expiry_date'] ??
          sub['endDate'],
    );
    final speed = _str(sub['speed'] ?? sub['bandwidth'] ?? sub['data_limit']);
    final ipAddress = _str(sub['ip_address'] ?? sub['ipAddress']);
    final hasDetails =
        speed.isNotEmpty ||
        startDate.isNotEmpty ||
        endDate.isNotEmpty ||
        ipAddress.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname.isNotEmpty ? nickname : 'Unnamed',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sln.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'SLN: $sln',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _inkTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasDetails) ...[
            Container(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  if (speed.isNotEmpty) _buildMeta('Speed', speed),
                  if (startDate.isNotEmpty) _buildMeta('Start', startDate),
                  if (endDate.isNotEmpty) _buildMeta('Expires', endDate),
                  if (ipAddress.isNotEmpty) _buildMeta('IP', ipAddress),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _inkTertiary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PagBtn(
            icon: Icons.chevron_left,
            enabled: _currentPage > 1,
            onTap: () => _goToPage(_currentPage - 1),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Text(
              '$_currentPage / $_totalPages',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _PagBtn(
            icon: Icons.chevron_right,
            enabled: _currentPage < _totalPages,
            onTap: () => _goToPage(_currentPage + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: _surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off_outlined
                    : Icons.wifi_off_rounded,
                color: _inkTertiary,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No subscriptions match "$_searchQuery".'
                  : 'No subscriptions found.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _inkSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: _danger),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _inkSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _loadSubscriptions(page: _currentPage),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletons() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: 5,
      itemBuilder:
          (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: _surfaceSubtle,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 13,
                        width: 140,
                        decoration: BoxDecoration(
                          color: _surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 90,
                        decoration: BoxDecoration(
                          color: _surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 26,
                  width: 64,
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  String _str(dynamic v) =>
      (v == null || v == 'null' || v.toString().trim().isEmpty)
          ? ''
          : v.toString().trim();
}

class _PagBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PagBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Icon(icon, size: 20, color: enabled ? _ink : _inkTertiary),
      ),
    );
  }
}
