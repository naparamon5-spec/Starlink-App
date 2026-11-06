import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/billing_export.dart';
import 'package:starlink_app/features/billing/billing_actions_button.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// The web portal's Billing page for a phone: search, totals of what matches,
/// then one card per record. `GET /billing/` returns every visible record, so
/// search, totals and paging all happen here.
class BillingListView extends StatefulWidget {
  const BillingListView({
    super.key,
    required this.onOpen,
    this.showAppBar = false,
    this.actionsController,
  });

  final ValueChanged<Map<String, dynamic>> onOpen;
  final bool showAppBar;

  /// For a parent's app bar to show [BillingActionsButton]. With [showAppBar],
  /// this page's own app bar has one.
  final BillingListController? actionsController;

  @override
  State<BillingListView> createState() => _BillingListViewState();
}

class _BillingListViewState extends State<BillingListView> {
  static const _pageSize = 20;

  final _search = TextEditingController();
  late final _actions = widget.actionsController ?? BillingListController();
  List<Map<String, dynamic>> _all = const [];
  int _shown = _pageSize;
  bool _loading = true;
  String? _error;

  String _text(Map<String, dynamic> r, String key) {
    final t = r[key]?.toString().trim() ?? '';
    return t == 'null' ? '' : t;
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((r) {
      return [
        'customer_name',
        'customer_code',
        'cpo_number',
        'sidr_number',
      ].any((k) => _text(r, k).toLowerCase().contains(q));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _shown = _pageSize));
    _actions.loader = () async => _filtered;
    _actions.reload = _load;
    _load();
  }

  @override
  void dispose() {
    _actions.loader = null;
    _actions.reload = null;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    final res = await ApiService.getBillingList();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['status'] == 'success' && res['data'] is List) {
        _all =
            (res['data'] as List)
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
      } else {
        _error = res['message']?.toString() ?? "Couldn't load billing.";
      }
    });
  }

  bool _onScroll(ScrollNotification n, int total) {
    if (n.metrics.extentAfter < 300 && _shown < total) {
      setState(() => _shown += _pageSize);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final billed = rows.fold<num>(0, (s, r) => s + billingNumber(r['amount']));
    final paid = rows.fold<num>(
      0,
      (s, r) => s + billingNumber(r['paid_amount']),
    );
    final visible = rows.take(_shown).toList();
    return Scaffold(
      backgroundColor: AppColors.paperSubtle,
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Billing'),
                actions: [BillingActionsButton(controller: _actions)],
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _onScroll(n, rows.length),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search customer, CPO or SI/DR number…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _TotalCard(
                        'Total billed',
                        billingMoney(billed, decimals: false),
                        AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TotalCard(
                        'Total paid',
                        billingMoney(paid, decimals: false),
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _Message(_error!, onRetry: _load)
              else if (rows.isEmpty)
                _Message(
                  _search.text.trim().isEmpty
                      ? 'No billing records found.'
                      : 'No billing records match your search.',
                )
              else
                for (final r in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BillingCard(
                      record: r,
                      query: _search.text.trim(),
                      onTap: () => widget.onOpen(r),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard(this.label, this.value, this.accent);
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.line),
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BillingCard extends StatelessWidget {
  const _BillingCard({
    required this.record,
    required this.query,
    required this.onTap,
  });
  final Map<String, dynamic> record;
  final String query;
  final VoidCallback onTap;

  String _text(String key) {
    final t = record[key]?.toString().trim() ?? '';
    return t == 'null' ? '' : t;
  }

  @override
  Widget build(BuildContext context) {
    final name = _text('customer_name');
    final code = _text('customer_code');
    final balance = billingBalance(record);
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
              HighlightedText(
                name.isNotEmpty ? name : (code.isNotEmpty ? code : '—'),
                query: query,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppColors.ink,
                ),
              ),
              if (name.isNotEmpty && code.isNotEmpty) ...[
                const SizedBox(height: 2),
                HighlightedText(
                  code,
                  query: query,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Reference(
                      'CPO #',
                      _text('cpo_number'),
                      record['cpo_date'],
                      query,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Reference(
                      'SI/DR #',
                      _text('sidr_number'),
                      record['sidr_date'],
                      query,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Figure(
                      'Amount',
                      billingNumber(record['amount']),
                      AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Figure(
                      'Paid',
                      billingNumber(record['paid_amount']),
                      AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Figure(
                      'Balance',
                      balance,
                      balance > 0 ? AppColors.dangerInk : AppColors.successInk,
                      bold: balance > 0,
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

class _Reference extends StatelessWidget {
  const _Reference(this.label, this.value, this.date, this.query);
  final String label;
  final String value;
  final dynamic date;
  final String query;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: AppColors.inkMuted,
        ),
      ),
      const SizedBox(height: 2),
      HighlightedText(
        value.isEmpty ? '—' : value,
        query: query,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
      const SizedBox(height: 1),
      Text(
        billingDate(date),
        style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
      ),
    ],
  );
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.color, {this.bold = false});
  final String label;
  final num value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
      ),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          billingMoney(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ),
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(30),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ],
    ),
  );
}
