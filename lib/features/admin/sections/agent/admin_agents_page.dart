import 'dart:async';

import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/admin/sections/agent/admin_agent_details_page.dart';
import 'package:starlink_app/features/admin/sections/agent/admin_create_agent_page.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// Customers, shown the mobile way: search and cards that load more as you
/// scroll. Searching and paging are done by the server
/// (GET /customers/paginated).
class AdminAgentsPage extends StatefulWidget {
  const AdminAgentsPage({super.key});

  @override
  State<AdminAgentsPage> createState() => _AdminAgentsPageState();
}

class _AdminAgentsPageState extends State<AdminAgentsPage> {
  static const _pageSize = 10;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  /// Only the latest request may update the list.
  int _requestSeq = 0;

  List<Map<String, dynamic>> _customers = const [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    setState(() {}); // Shows or hides the clear button.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load());
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 200 && !_loadingMore && !_loading) {
      if (_page < _totalPages) _load(page: _page + 1);
    }
  }

  Future<void> _load({int page = 1}) async {
    final seq = ++_requestSeq;
    final more = page > 1;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loadingMore = false;
        _loading = _customers.isEmpty;
        _error = null;
      }
    });
    Map<String, dynamic>? res;
    try {
      res = await ApiService.getCustomersPaginated(
        page: page,
        limit: _pageSize,
        search: _search.text.trim(),
      );
    } catch (_) {
      res = null;
    }
    if (!mounted || seq != _requestSeq) return;

    if (res == null || res['status'] != 'success') {
      setState(() {
        _loading = false;
        _loadingMore = false;
        // A failed "load more" keeps the list; scrolling again retries.
        if (!more) {
          _customers = const [];
          _error = res?['message']?.toString() ?? "Couldn't load customers.";
        }
      });
      return;
    }
    final data = res['data'];
    final list =
        data is Map && data['data'] is List
            ? data['data'] as List
            : (data is List ? data : const []);
    final pagination =
        data is Map && data['pagination'] is Map
            ? data['pagination'] as Map
            : (res['pagination'] is Map ? res['pagination'] as Map : const {});
    final rows =
        list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    setState(() {
      _loading = false;
      _loadingMore = false;
      _customers = more ? [..._customers, ...rows] : rows;
      _page = page;
      _totalPages = int.tryParse('${pagination['totalPages']}') ?? 1;
      _totalItems =
          int.tryParse('${pagination['totalItems']}') ?? _customers.length;
    });
    if (!more && _scroll.hasClients) _scroll.jumpTo(0);
  }

  void _openDetails(Map<String, dynamic> c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminAgentDetailsPage(
              agentId: '${c['id'] ?? c['customer_id'] ?? ''}',
              agentCode: '${c['code'] ?? ''}',
              agentName: '${c['name'] ?? ''}',
            ),
      ),
    );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreateAgentPage()),
    );
    if (created == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperSubtle,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('New Customer'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search code or company…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon:
                    _search.text.isEmpty
                        ? null
                        : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _search.clear();
                            _onSearchChanged('');
                          },
                        ),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _load(),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (_customers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No customers found.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '$_totalItems customer${_totalItems == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              for (final c in _customers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CustomerCard(
                    customer: c,
                    onTap: () => _openDetails(c),
                  ),
                ),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onTap});
  final Map<String, dynamic> customer;
  final VoidCallback onTap;

  String _text(String key) {
    final t = customer[key]?.toString().trim() ?? '';
    return t == 'null' ? '' : t;
  }

  @override
  Widget build(BuildContext context) {
    final active = _text('inactive') == 'N';
    final code = _text('code');
    final name = _text('name');
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code.isEmpty ? '—' : code,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      name.isEmpty ? '—' : name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              DotBadge(
                active ? 'ACTIVE' : 'INACTIVE',
                color: active ? AppColors.successInk : AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
