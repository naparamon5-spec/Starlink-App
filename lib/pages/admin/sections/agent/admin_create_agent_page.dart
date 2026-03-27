import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../../services/api_service.dart';

// ── Design tokens (identical to create-ticket page) ──────────────────────────
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

class _AdminCreateAgentPageState extends State<AdminCreateAgentPage>
    with TickerProviderStateMixin {
  // ── Pagination state ───────────────────────────────────────────────────────
  static const int _pageSize = 20;

  final List<Map<String, dynamic>> _items = [];
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  int _currentPage = 1;
  int _totalPages = 1;
  bool _loadingFirst = true;
  bool _loadingMore = false;
  bool _submitting = false;
  String? _loadError;
  String _lastQuery = '';

  // Multi-select
  final Map<String, Map<String, dynamic>> _selected = {};

  // Debounce
  Timer? _debounce;

  // Search focus
  final FocusNode _searchFocus = FocusNode();
  bool _searchFocused = false;

  // Animation
  late AnimationController _animController;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchPage(page: 1, query: '', reset: true);
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animController.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
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
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final q = _searchCtrl.text.trim();
      if (q != _lastQuery) {
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

        if (reset) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _animController.forward(from: 0),
          );
        }
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

  // ── UI helpers ─────────────────────────────────────────────────────────────
  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _inkTertiary,
        letterSpacing: 1.1,
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        body: Column(
          children: [
            // ── Gradient AppBar ────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Agent',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Select companies to assign',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_loadingFirst &&
                          _loadError == null &&
                          _selected.isNotEmpty)
                        GestureDetector(
                          onTap: _submitting ? null : _save,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                _submitting ? 0.08 : 0.18,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:
                                _submitting
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Text(
                                      'Create (${_selected.length})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child:
                  _loadingFirst
                      ? _buildLoading()
                      : _loadError != null && _items.isEmpty
                      ? _buildErrorState()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading state ──────────────────────────────────────────────────────────
  Widget _buildLoading() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Loading companies...',
          style: TextStyle(
            color: _inkSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fetching available companies',
          style: TextStyle(color: _inkTertiary, fontSize: 12),
        ),
      ],
    ),
  );

  // ── Error state ────────────────────────────────────────────────────────────
  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              color: _primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Could not load companies',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _loadError ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _inkSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed:
                () => _fetchPage(page: 1, query: _lastQuery, reset: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  // ── Main content ───────────────────────────────────────────────────────────
  Widget _buildContent() {
    return AnimatedBuilder(
      animation: _animController,
      builder:
          (_, child) => Opacity(
            opacity: _animController.value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - _animController.value)),
              child: child,
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar + selected chips ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('SELECT COMPANIES'),

                // ── Search bar ─────────────────────────────────────────────
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: _inkTertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(fontSize: 14, color: _ink),
                          decoration: InputDecoration(
                            hintText: 'Search companies…',
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: _inkTertiary,
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            suffixIcon:
                                _searchCtrl.text.isNotEmpty
                                    ? GestureDetector(
                                      onTap: () {
                                        _searchCtrl.clear();
                                        _fetchPage(
                                          page: 1,
                                          query: '',
                                          reset: true,
                                        );
                                      },
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: _inkTertiary,
                                      ),
                                    )
                                    : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Selected chips — single horizontal scrollable row ───────
                if (_selected.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 26,
                    child: Row(
                      children: [
                        // "N selected" badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selected.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Scrollable chips
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children:
                                _selected.values.map((c) {
                                  final lbl =
                                      (c['label'] as String? ?? '').trim();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 5),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
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
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: _primary,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () => _toggle(c),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 11,
                                              color: _primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),

                        // Clear all
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _selected.clear()),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _inkTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Section label for results ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _sectionLabel('COMPANIES'),
                const SizedBox(width: 8),
                if (!_loadingFirst && _loadError == null)
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
                      '${_items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Company list ─────────────────────────────────────────────────
          Expanded(
            child: Padding(
              // FIX: bottom padding creates visual gap between list card
              // and the Cancel / Create button bar
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildList(),
            ),
          ),

          // ── Pinned action buttons ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: _surface,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _inkSecondary,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _primary.withOpacity(0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon:
                        _submitting
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(
                              Icons.support_agent_outlined,
                              size: 15,
                            ),
                    label: Text(
                      _submitting
                          ? 'Creating...'
                          : _selected.isEmpty
                          ? 'Create Agent'
                          : 'Create ${_selected.length} Agent${_selected.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Company list ───────────────────────────────────────────────────────────
  Widget _buildList() {
    if (_items.isEmpty && !_loadingMore) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_outlined,
                color: _primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No companies found',
              style: TextStyle(
                color: _inkSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try a different search term',
              style: TextStyle(color: _inkTertiary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return _card(
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: EdgeInsets.zero,
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder:
            (_, __) => const Divider(height: 1, color: _border, indent: 36),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
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
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? _primary.withOpacity(0.04)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Checkbox
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: selected ? _primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
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
                                size: 12,
                              )
                              : null,
                    ),
                    const SizedBox(width: 8),

                    // Avatar
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color:
                            selected
                                ? _primary.withOpacity(0.12)
                                : _surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          ini,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: selected ? _primary : _inkSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Label + code
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lbl,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? _primary : _ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (val.isNotEmpty)
                            Text(
                              val,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _inkTertiary,
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
        },
      ),
    );
  }
}
