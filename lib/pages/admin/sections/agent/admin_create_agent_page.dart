import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../services/api_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _success = Color(0xFF24A148);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class AdminCreateAgentPage extends StatefulWidget {
  const AdminCreateAgentPage({super.key});

  @override
  State<AdminCreateAgentPage> createState() => _AdminCreateAgentPageState();
}

class _AdminCreateAgentPageState extends State<AdminCreateAgentPage> {
  // ── Pagination state ───────────────────────────────────────────────────────
  static const int _pageSize = 20;

  final List<Map<String, dynamic>> _items = [];
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  int _currentPage = 1;
  int _totalPages = 1;
  bool _loadingFirst = true; // skeleton on initial load
  bool _loadingMore = false; // spinner at bottom when paginating
  bool _submitting = false;
  String? _loadError;
  String _lastQuery = '';

  // Debounce timer for search
  Future<void>? _searchDebounce;

  // Multi-select
  final Map<String, Map<String, dynamic>> _selected = {};

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchPage(page: 1, query: '', reset: true);
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Infinite scroll trigger ────────────────────────────────────────────────
  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _currentPage < _totalPages) {
      _fetchPage(page: _currentPage + 1, query: _lastQuery);
    }
  }

  // ── Debounced search ───────────────────────────────────────────────────────
  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    // Simple debounce: wait 350ms after last keystroke
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_searchCtrl.text.trim() == q && q != _lastQuery) {
        _fetchPage(page: 1, query: q, reset: true);
      }
    });
  }

  // ── Core fetch ─────────────────────────────────────────────────────────────
  Future<void> _fetchPage({
    required int page,
    required String query,
    bool reset = false,
  }) async {
    if (reset) {
      setState(() {
        _loadingFirst = true;
        _loadError = null;
        _lastQuery = query;
        _currentPage = 1;
        _totalPages = 1;
        _items.clear();
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final token = await ApiService.getValidAccessToken();
      final uri = Uri(
        scheme: 'https',
        host: 'starlink-api.ardentnetworks.com.ph',
        path: '/api/external/list/customer',
        queryParameters: {
          'limit': '$_pageSize',
          'page': '$page',
          'search': query,
        },
      );

      final res = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final pag = body['pagination'] as Map<String, dynamic>? ?? {};
        final total = (pag['totalPages'] as num?)?.toInt() ?? 1;

        final newItems =
            (body['data'] as List? ?? [])
                .whereType<Map>()
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .where(
                  (e) =>
                      (e['label'] as String? ?? '').trim().isNotEmpty &&
                      e['value'] != null,
                )
                .toList();

        setState(() {
          if (reset) _items.clear();
          _items.addAll(newItems);
          _currentPage = page;
          _totalPages = total;
          _loadingFirst = false;
          _loadingMore = false;
          _loadError = null;
        });
      } else {
        setState(() {
          _loadError = 'Server error: ${res.statusCode}';
          _loadingFirst = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceAll('Exception: ', '');
        _loadingFirst = false;
        _loadingMore = false;
      });
    }
  }

  // ── Selection helpers ──────────────────────────────────────────────────────
  void _toggle(Map<String, dynamic> c) {
    final key = c['value']?.toString() ?? '';
    if (key.isEmpty) return;
    setState(() {
      _selected.containsKey(key) ? _selected.remove(key) : _selected[key] = c;
    });
  }

  bool _isSelected(Map<String, dynamic> c) =>
      _selected.containsKey(c['value']?.toString() ?? '');

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_selected.isEmpty) {
      _showSnack('Please select at least one company.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    // TODO: replace with real create-agent API call
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _submitting = false);
    _showSnack(
      '${_selected.length} agent${_selected.length > 1 ? 's' : ''} created successfully!',
      isError: false,
    );
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.of(context).pop(true);
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? _primaryDark : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Create Agent',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top controls ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                const _SectionHeader(
                  icon: Icons.support_agent_outlined,
                  title: 'Select Companies',
                ),
                const SizedBox(height: 14),

                // Selected chips
                if (_selected.isNotEmpty) ...[
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selected.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final c = _selected.values.elementAt(i);
                        final lbl = (c['label'] as String? ?? '').trim();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _primary.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                lbl,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _primary,
                                ),
                              ),
                              const SizedBox(width: 5),
                              GestureDetector(
                                onTap: () => _toggle(c),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: _primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13, color: _ink),
                    decoration: InputDecoration(
                      hintText: 'Search by company name or code…',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: _inkTertiary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: _inkTertiary,
                      ),
                      suffixIcon:
                          _searchCtrl.text.isNotEmpty
                              ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  _fetchPage(page: 1, query: '', reset: true);
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
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Count row
                // if (!_loadingFirst && _loadError == null)
                //   Row(
                //     children: [
                //       Text(
                //         '${_items.length} compan${_items.length == 1 ? 'y' : 'ies'}',
                //         style: const TextStyle(
                //           fontSize: 11,
                //           color: _inkTertiary,
                //           fontWeight: FontWeight.w500,
                //         ),
                //       ),
                //       if (_selected.isNotEmpty) ...[
                //         const SizedBox(width: 8),
                //         Container(
                //           padding: const EdgeInsets.symmetric(
                //             horizontal: 8,
                //             vertical: 2,
                //           ),
                //           decoration: BoxDecoration(
                //             color: _primary.withOpacity(0.08),
                //             borderRadius: BorderRadius.circular(20),
                //           ),
                //           child: Text(
                //             '${_selected.length} selected',
                //             style: const TextStyle(
                //               fontSize: 11,
                //               fontWeight: FontWeight.w700,
                //               color: _primary,
                //             ),
                //           ),
                //         ),
                //       ],
                //     ],
                //   ),

                // const SizedBox(height: 10),
              ],
            ),
          ),

          Container(height: 1, color: _border),

          // ── List body ────────────────────────────────────────────────────
          Expanded(child: _buildBody()),

          // ── Pinned save button ────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: _surface,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: GestureDetector(
              onTap: _submitting ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: _submitting ? _primary.withOpacity(0.6) : _primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child:
                      _submitting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                          : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.support_agent_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selected.isEmpty
                                    ? 'Create Agent'
                                    : 'Create ${_selected.length} Agent${_selected.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── List body switch ───────────────────────────────────────────────────────
  Widget _buildBody() {
    // First load — show skeletons immediately
    if (_loadingFirst) return _SkeletonList();

    // Error on first load
    if (_loadError != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _inkSecondary),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed:
                    () => _fetchPage(page: 1, query: _lastQuery, reset: true),
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
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No companies found.',
          style: TextStyle(fontSize: 13, color: _inkSecondary),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollCtrl,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
      itemBuilder: (context, i) {
        // Load-more spinner at the very bottom
        if (i == _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: _primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final c = _items[i];
        final lbl = (c['label'] as String? ?? '').trim();
        final val = c['value']?.toString().trim() ?? '';
        final selected = _isSelected(c);

        final parts =
            lbl.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
        final ini =
            parts.length >= 2
                ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
                : lbl.isNotEmpty
                ? lbl[0].toUpperCase()
                : '?';

        return RepaintBoundary(
          child: InkWell(
            onTap: () => _toggle(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              color: selected ? _primary.withOpacity(0.04) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? _primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? _primary : _inkTertiary,
                        width: 1.5,
                      ),
                    ),
                    child:
                        selected
                            ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            )
                            : null,
                  ),
                  const SizedBox(width: 14),

                  // Avatar
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? _primary.withOpacity(0.1)
                              : _primary.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        ini,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: selected ? _primary : _inkSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Label + code
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lbl,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: _ink,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          val,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _inkTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: _primary,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Skeleton shimmer list ─────────────────────────────────────────────────────

class _SkeletonList extends StatefulWidget {
  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.4 + (_anim.value * 0.4);
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 4),
          itemCount: 10,
          separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
          itemBuilder:
              (_, __) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Checkbox placeholder
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _border.withOpacity(opacity),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Avatar placeholder
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _border.withOpacity(opacity),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text placeholders
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _border.withOpacity(opacity),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 10,
                            width: 80,
                            decoration: BoxDecoration(
                              color: _border.withOpacity(opacity),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        );
      },
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: _primary),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _ink,
          letterSpacing: -0.2,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: _border, height: 1)),
    ],
  );
}
