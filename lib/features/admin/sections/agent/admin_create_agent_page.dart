import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';

/// Onboard customers: pick companies from the directory, then create them
/// (POST /customers/).
class AdminCreateAgentPage extends StatefulWidget {
  const AdminCreateAgentPage({super.key});

  @override
  State<AdminCreateAgentPage> createState() => _AdminCreateAgentPageState();
}

class _AdminCreateAgentPageState extends State<AdminCreateAgentPage> {
  /// Picked companies: code -> company name.
  final Map<String, String> _rows = {};
  bool _saving = false;

  Future<void> _openDirectory() async {
    final picked = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _DirectorySheet(alreadyPicked: _rows.keys.toSet()),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      _rows.addAll(picked);
    });
  }

  Future<void> _submit() async {
    if (_rows.isEmpty || _saving) return;
    setState(() {
      _saving = true;
    });
    final res = await ApiService.createAgent({
      'formData': [
        for (final e in _rows.entries)
          {'customer_code': e.key, 'customer_name': e.value},
      ],
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['status'] != 'success') {
      AppToast.error(
        context,
        res['message']?.toString() ?? "Couldn't create the customers.",
      );
      return;
    }
    final toast = AppToast.of(context);
    final count = _rows.length;
    Navigator.pop(context, true);
    toast.showSuccess('Created $count customer${count == 1 ? '' : 's'}');
  }

  String get _createLabel {
    final n = _rows.length;
    return n == 0
        ? 'Create customers'
        : 'Create $n customer${n == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: () => _rows.isNotEmpty,
      child: Scaffold(
        backgroundColor: AppColors.paperSubtle,
        appBar: AppBar(title: const Text('New Customers')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'Pick companies from the directory to onboard.',
              style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _openDirectory,
                style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Add from directory'),
              ),
            ),
            const SizedBox(height: 14),
            if (_rows.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.paperMuted,
                        child: Icon(
                          Icons.inbox_outlined,
                          size: 22,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No customers added yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Use “Add from directory” to search and select companies.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final e in _rows.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
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
                                e.key,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                e.value,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.3,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove ${e.value}',
                          onPressed:
                              _saving
                                  ? null
                                  : () => setState(() => _rows.remove(e.key)),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.maybePop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: _rows.isEmpty || _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_createLabel),
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The company directory: search, tick several, and load more while scrolling.
/// Companies that are already customers aren't offered.
class _DirectorySheet extends StatefulWidget {
  const _DirectorySheet({required this.alreadyPicked});
  final Set<String> alreadyPicked;

  @override
  State<_DirectorySheet> createState() => _DirectorySheetState();
}

class _DirectorySheetState extends State<_DirectorySheet> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<Map<String, String>> _items = [];
  final Map<String, String> _selected = {};
  Set<String>? _existing;
  int _requestSeq = 0;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 200 &&
          !_loadingMore &&
          !_loading &&
          _page < _totalPages) {
        _fetch(page: _page + 1);
      }
    });
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetch({int page = 1}) async {
    final seq = ++_requestSeq;
    final more = page > 1;
    setState(() {
      _error = null;
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
      }
    });
    if (_existing == null) {
      final existing = await ApiService.getCustomersListAll();
      if (!mounted || seq != _requestSeq) return;
      final raw = existing['data'];
      _existing = {
        for (final e in (raw is List ? raw : const []).whereType<Map>())
          '${e['value'] ?? ''}'.trim(),
      };
    }
    final res = await ApiService.getExternalCustomers(
      page: page,
      limit: 30,
      search: _search.text.trim(),
    );
    if (!mounted || seq != _requestSeq) return;
    if (res['status'] != 'success') {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = res['message']?.toString() ?? "Couldn't load the directory.";
      });
      return;
    }
    final raw = res['data'];
    final rows = [
      for (final e in (raw is List ? raw : const []).whereType<Map>())
        {
          'label': '${e['label'] ?? ''}'.trim(),
          'value': '${e['value'] ?? ''}'.trim(),
        },
    ].where((e) {
      final code = e['value']!;
      return e['label']!.isNotEmpty &&
          code.isNotEmpty &&
          !_existing!.contains(code) &&
          !widget.alreadyPicked.contains(code);
    });
    final pagination =
        res['pagination'] ??
        (res['raw'] is Map ? (res['raw'] as Map)['pagination'] : null);
    final total =
        pagination is Map
            ? int.tryParse('${pagination['totalPages']}') ?? page
            : page;
    setState(() {
      if (!more) _items.clear();
      _items.addAll(rows);
      _page = page;
      _totalPages = total;
      _loading = false;
      _loadingMore = false;
    });
    // A page may be all existing customers; keep the list long enough to scroll.
    if (_items.length < 15 && page < total) _fetch(page: page + 1);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search customer directory',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => _fetch(),
                );
              },
              decoration: const InputDecoration(
                hintText: 'Search…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList()),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              '${_selected.length} selected',
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed:
                        _selected.isEmpty
                            ? null
                            : () => Navigator.pop(context, _selected),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Add selected'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _fetch(),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No companies found.',
          style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final item = _items[i];
        final code = item['value']!;
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.brand,
          value: _selected.containsKey(code),
          title: Text(
            item['label']!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          subtitle: Text(
            code,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
          onChanged:
              (v) => setState(() {
                if (v == true) {
                  _selected[code] = item['label']!;
                } else {
                  _selected.remove(code);
                }
              }),
        );
      },
    );
  }
}
