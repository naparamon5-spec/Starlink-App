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
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allCompanies = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = false;
  String? _loadError;

  // Multi-select keyed by company value
  final Map<String, Map<String, dynamic>> _selected = {};

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered =
          q.isEmpty
              ? _allCompanies
              : _allCompanies.where((c) {
                return (c['label'] as String? ?? '').toLowerCase().contains(
                      q,
                    ) ||
                    (c['value']?.toString() ?? '').toLowerCase().contains(q);
              }).toList();
    });
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _allCompanies = [];
      _filtered = [];
    });
    try {
      final token = await ApiService.getValidAccessToken();
      const int pageSize = 100;
      int currentPage = 1;
      int totalPages = 1;
      final List<Map<String, dynamic>> allItems = [];

      do {
        final uri = Uri(
          scheme: 'https',
          host: 'starlink-api.ardentnetworks.com.ph',
          path: '/api/external/list/customer',
          queryParameters: {
            'limit': '$pageSize',
            'page': '$currentPage',
            'search': '',
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
          final items =
              (body['data'] as List? ?? [])
                  .whereType<Map>()
                  .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e),
                  )
                  .where(
                    (e) =>
                        (e['label'] as String? ?? '').trim().isNotEmpty &&
                        e['value'] != null,
                  )
                  .toList();

          allItems.addAll(items);

          final pag = body['pagination'] as Map<String, dynamic>? ?? {};
          totalPages = (pag['totalPages'] as num?)?.toInt() ?? 1;

          // Show first batch immediately so the user sees results fast
          if (currentPage == 1 && mounted) {
            setState(() {
              _allCompanies = List.from(allItems);
              _filtered = List.from(allItems);
            });
          }

          currentPage++;
        } else {
          setState(() {
            _loadError = 'Server error: ${res.statusCode}';
            _isLoading = false;
          });
          return;
        }
      } while (currentPage <= totalPages);

      if (!mounted) return;
      setState(() {
        _allCompanies = allItems;
        _filtered = allItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _toggle(Map<String, dynamic> c) {
    final key = c['value']?.toString() ?? '';
    if (key.isEmpty) return;
    setState(() {
      if (_selected.containsKey(key)) {
        _selected.remove(key);
      } else {
        _selected[key] = c;
      }
    });
  }

  bool _isSelected(Map<String, dynamic> c) =>
      _selected.containsKey(c['value']?.toString() ?? '');

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
          // ── Header: section title + selected chips + search ──────────────
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
                // Selected chips — single horizontal scrollable row
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
                    controller: _searchController,
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
                          _searchController.text.isNotEmpty
                              ? GestureDetector(
                                onTap: _searchController.clear,
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

                const SizedBox(height: 10),

                // Count row
                if (!_isLoading && _loadError == null)
                  Row(
                    children: [
                      Text(
                        '${_filtered.length} compan${_filtered.length == 1 ? 'y' : 'ies'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _inkTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_selected.isNotEmpty) ...[
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
                            '${_selected.length} selected',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                const SizedBox(height: 10),
              ],
            ),
          ),

          Container(height: 1, color: _border),

          // ── Company list ────────────────────────────────────────────────
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: _primary,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Loading companies…',
                            style: TextStyle(
                              fontSize: 13,
                              color: _inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _loadError != null
                    ? Center(
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
                              style: const TextStyle(
                                fontSize: 13,
                                color: _inkSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: _loadCompanies,
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
                    : _filtered.isEmpty
                    ? const Center(
                      child: Text(
                        'No companies found.',
                        style: TextStyle(fontSize: 13, color: _inkSecondary),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _filtered.length,
                      separatorBuilder:
                          (_, __) => const Divider(height: 1, color: _border),
                      itemBuilder: (context, i) {
                        final c = _filtered[i];
                        final lbl = (c['label'] as String? ?? '').trim();
                        final val = c['value']?.toString().trim() ?? '';
                        final selected = _isSelected(c);

                        final parts =
                            lbl
                                .split(RegExp(r'\s+'))
                                .where((p) => p.isNotEmpty)
                                .toList();
                        final ini =
                            parts.length >= 2
                                ? '${parts.first[0]}${parts.last[0]}'
                                    .toUpperCase()
                                : lbl.isNotEmpty
                                ? lbl[0].toUpperCase()
                                : '?';

                        return RepaintBoundary(
                          child: InkWell(
                            onTap: () => _toggle(c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              color:
                                  selected
                                      ? _primary.withOpacity(0.04)
                                      : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  // Checkbox
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color:
                                          selected
                                              ? _primary
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color:
                                            selected ? _primary : _inkTertiary,
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
                                          color:
                                              selected
                                                  ? _primary
                                                  : _inkSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Label + code
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lbl,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                                selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
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
                    ),
          ),

          // ── Pinned save button ───────────────────────────────────────────
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
