import 'dart:async';

import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/admin/sections/enduser/admin_create_end_user_page.dart';
import 'package:starlink_app/features/admin/sections/enduser/admin_end_user_details_page.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

String _text(dynamic v) {
  final t = v?.toString().trim() ?? '';
  return t == 'null' ? '' : t;
}

/// End users, shown the mobile way: search and cards that load more as you
/// scroll. Searching and paging are done by the server
/// (GET /end-user/paginated).
class AdminEndUsersPage extends StatefulWidget {
  const AdminEndUsersPage({super.key});

  @override
  State<AdminEndUsersPage> createState() => _AdminEndUsersPageState();
}

class _AdminEndUsersPageState extends State<AdminEndUsersPage> {
  static const _pageSize = 10;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  /// Only the latest request may update the list.
  int _requestSeq = 0;

  List<Map<String, dynamic>> _users = const [];
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

  void _onScroll() {
    if (_scroll.position.extentAfter < 200 &&
        !_loadingMore &&
        !_loading &&
        _page < _totalPages) {
      _load(page: _page + 1);
    }
  }

  void _onSearchChanged(String _) {
    setState(() {}); // Shows or hides the clear button.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load());
  }

  Future<void> _load({int page = 1}) async {
    final seq = ++_requestSeq;
    final more = page > 1;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loadingMore = false;
        _loading = _users.isEmpty;
        _error = null;
      }
    });
    Map<String, dynamic>? res;
    try {
      res = await ApiService.getEndUsersPaginated(
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
          _users = const [];
          _error = res?['message']?.toString() ?? "Couldn't load end users.";
        }
      });
      return;
    }
    final data = res['data'];
    final rows =
        data is List
            ? data
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList()
            : <Map<String, dynamic>>[];
    final pagination = res['pagination'] is Map ? res['pagination'] as Map : {};
    setState(() {
      _loading = false;
      _loadingMore = false;
      _users = more ? [..._users, ...rows] : rows;
      _page = page;
      _totalPages = int.tryParse('${pagination['totalPages']}') ?? 1;
      _totalItems =
          int.tryParse('${pagination['totalItems']}') ?? _users.length;
    });
    if (!more && _scroll.hasClients) _scroll.jumpTo(0);
  }

  void _openDetails(Map<String, dynamic> user) {
    final code = _text(user['eu_code'] ?? user['code']);
    if (code.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminEndUserDetailsPage(
              endUserId: code,
              endUserCode: code,
              endUserName: _text(user['eu_name'] ?? user['name']),
            ),
      ),
    );
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreateEndUserPage()),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperSubtle,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('New End User'),
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
                hintText: 'Search name, code, customer…',
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
            else if (_users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No end users found.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '$_totalItems end user${_totalItems == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              for (final u in _users)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EndUserCard(user: u, onTap: () => _openDetails(u)),
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

class _EndUserCard extends StatelessWidget {
  const _EndUserCard({required this.user, required this.onTap});
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final code = _text(user['eu_code'] ?? user['code']);
    final name = _text(user['eu_name'] ?? user['name']);
    final company = _text(user['company_name']);
    final customer =
        company.isNotEmpty ? company : _text(user['customer_code']);
    final active = _text(user['inactive']) == 'N';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      code.isEmpty ? '—' : code,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DotBadge(
                    active ? 'ACTIVE' : 'INACTIVE',
                    color: active ? AppColors.successInk : AppColors.inkMuted,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                name.isEmpty ? '—' : name,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.business_outlined,
                    size: 15,
                    color: AppColors.inkFaint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customer.isEmpty ? '—' : customer,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
