import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/status_labels.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/core/utils/usage_export.dart';
import 'package:starlink_app/features/admin/sections/subscription/subscription_kits_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:starlink_app/services/api_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _surface = Color(0xFFFFFFFF);
const _accent = Color(0xFF133341);
const _accentBlue = Color(0xFF3B82F6);
const _inkDark = Color(0xFF0D1B2A);
const _inkMid = Color(0xFF4A5568);
const _inkLight = Color(0xFF9AA5B4);
const _border = Color(0xFFD7D7D7);
const _amber = Color(0xFFF59E0B);
const _emerald = Color(0xFF10B981);

/// Subscription details for every role: a navy summary, then Usage, Service
/// plans, Top-ups and Terminal (the web portal's four tabs, as sections).
class SubscriptionDetailsView extends StatefulWidget {
  final String serviceLineNumber;
  final String title;

  /// Staff only, as on the web portal.
  final bool canEditEndDate;
  final bool canManageKits;
  final bool canViewRouter;

  const SubscriptionDetailsView({
    super.key,
    required this.serviceLineNumber,
    required this.title,
    this.canEditEndDate = false,
    this.canManageKits = false,
    this.canViewRouter = false,
  });

  @override
  State<SubscriptionDetailsView> createState() =>
      _SubscriptionDetailsViewState();
}

class _SubscriptionDetailsViewState extends State<SubscriptionDetailsView> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _subscriptionData;
  Map<String, dynamic>? _billingData;

  String? _subscriptionError;
  String? _billingError;

  // GET /subscriptions/:id has no company or end user; the list does.
  String? _accountName;

  List<_BillingPeriod> _billingPeriods = [];
  _BillingPeriod? _selectedPeriod;

  static const _brandRed = Color(0xFF133341);

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String? _pickDate(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k]?.toString();
      if (v != null && v.isNotEmpty && v != 'null' && v != '0000-00-00') {
        return v;
      }
    }
    return null;
  }

  double _parseGb(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  String? _text(dynamic v) {
    final t = v?.toString().trim() ?? '';
    return t.isEmpty || t == 'null' ? null : t;
  }

  String _date(dynamic raw) {
    final t = _text(raw);
    if (t == null || t.startsWith('0000')) return '—';
    final d = DateTime.tryParse(t.split(RegExp('[T ]')).first);
    return d == null ? t : DateFormat('MMM d, y').format(d);
  }

  String _gb(dynamic v) => '${NumberFormat('#,##0.00').format(_parseGb(v))} GB';

  String _gbShort(num v) => '${NumberFormat('#,##0.##').format(v)} GB';

  String _periodLabel(_BillingPeriod p) =>
      '${_date(p.startDate)} – ${_date(p.endDate)}';

  Future<void> _loadAccountName(String sln) async {
    final res = await ApiService.getSubscriptionsPaginated(
      limit: 5,
      search: sln,
    );
    if (!mounted || res['status'] != 'success' || res['data'] is! List) return;
    for (final row in (res['data'] as List).whereType<Map>()) {
      if (row['serviceLineNumber']?.toString() != sln) continue;
      final name = _text(row['company_name']) ?? _text(row['end_user_name']);
      if (name != null) setState(() => _accountName = name);
      return;
    }
  }

  // ── load ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _subscriptionError = null;
      _billingError = null;
      _subscriptionData = null;
      _billingData = null;
      _billingPeriods = [];
      _selectedPeriod = null;
    });

    final sln = widget.serviceLineNumber.trim();
    _loadAccountName(sln);
    ApiService.refreshStarlinkServiceLine(
      sln,
    ).catchError((_) => <String, dynamic>{});

    Map<String, dynamic>? subResult;
    String? subErr;
    try {
      final res = await ApiService.getSubscriptionByServiceLineNumber(sln);
      if (res['status'] == 'success') {
        final d = res['data'];
        if (d is Map) {
          subResult = Map<String, dynamic>.from(d);
        } else if (d is List && d.isNotEmpty) {
          subResult = Map<String, dynamic>.from(d.first);
        } else {
          subResult = <String, dynamic>{'raw': d};
        }
      } else {
        subErr = res['message']?.toString() ?? 'Subscription fetch failed';
      }
    } catch (e) {
      subErr = e.toString().replaceAll('Exception: ', '');
    }

    String? startDate;
    String? endDate;
    final List<_BillingPeriod> periods = [];

    if (subResult != null) {
      final dd = subResult['dd'];
      if (dd is List) {
        for (final item in dd) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final s = _pickDate(m, ['startDate', 'start_date', 'start']);
            final e = _pickDate(m, ['endDate', 'end_date', 'end']);
            if (s != null && e != null) {
              periods.add(_BillingPeriod(startDate: s, endDate: e));
            }
          }
        }
      }

      if (periods.isEmpty) {
        final bc = subResult['billingCycle'];
        if (bc is Map) {
          final bcm = Map<String, dynamic>.from(bc);
          startDate = _pickDate(bcm, ['startDate', 'start_date', 'start']);
          endDate = _pickDate(bcm, ['endDate', 'end_date', 'end']);
        }
        startDate ??= _pickDate(subResult, [
          'startDate',
          'start_date',
          'cycleStart',
          'billingStart',
        ]);
        endDate ??= _pickDate(subResult, [
          'endDate',
          'end_date',
          'cycleEnd',
          'billingEnd',
        ]);
        if (startDate != null && endDate != null) {
          periods.add(_BillingPeriod(startDate: startDate, endDate: endDate));
        }
      }
    }

    final useStart = periods.isNotEmpty ? periods.first.startDate : startDate;
    final useEnd = periods.isNotEmpty ? periods.first.endDate : endDate;

    Map<String, dynamic>? billingResult;
    String? billingErr;

    if (useStart != null && useEnd != null) {
      try {
        final res = await ApiService.getSubscriptionBillingCycleByDates(
          sln,
          startDate: useStart,
          endDate: useEnd,
        );
        if (res['status'] == 'success') {
          final d = res['data'];
          billingResult =
              d is Map
                  ? Map<String, dynamic>.from(d)
                  : <String, dynamic>{'raw': d};
        } else {
          billingErr =
              res['message']?.toString() ?? 'Billing cycle fetch failed';
        }
      } catch (e) {
        billingErr = e.toString().replaceAll('Exception: ', '');
      }
    } else {
      billingErr = 'No billing dates available';
    }

    if (!mounted) return;
    setState(() {
      _subscriptionData = subResult;
      _subscriptionError = subErr;
      _billingData = billingResult;
      _billingError = billingErr;
      _billingPeriods = periods;
      _selectedPeriod = periods.isNotEmpty ? periods.first : null;
      _loading = false;

      if (subResult == null && billingResult == null) {
        _error = 'Failed to load subscription data.';
      }
    });
  }

  void _changeEndDate() async {
    final current = _subscriptionData?['endDate']?.toString();
    DateTime initial = DateTime.now();
    if (current != null && current != 'null' && current.isNotEmpty) {
      try {
        final clean =
            current.contains('T')
                ? current.split('T').first
                : current.split(' ').first;
        initial = DateTime.parse('${clean}T00:00:00');
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _brandRed,
              onPrimary: Colors.white,
              onSurface: Color(0xFF000000),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    // PUT /subscriptions/end-date/:sln { endDate: YYYY-MM-DD }
    final endDate =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    final res = await ApiService.updateSubscriptionEndDate(
      widget.serviceLineNumber,
      endDate,
    );
    if (!mounted) return;
    final ok = res['status'] == 'success';
    if (ok) {
      setState(
        () => _subscriptionData = {...?_subscriptionData, 'endDate': endDate},
      );
    }
    AppToast.result(context, ok
              ? 'End date updated'
              : res['message']?.toString() ?? 'Could not update the end date', ok: ok);
  }

  Future<void> _loadBillingForPeriod(_BillingPeriod period) async {
    setState(() {
      _billingData = null;
      _billingError = null;
    });
    try {
      final res = await ApiService.getSubscriptionBillingCycleByDates(
        widget.serviceLineNumber.trim(),
        startDate: period.startDate,
        endDate: period.endDate,
      );
      if (!mounted) return;
      if (res['status'] == 'success') {
        final d = res['data'];
        setState(() {
          _billingData =
              d is Map
                  ? Map<String, dynamic>.from(d)
                  : <String, dynamic>{'raw': d};
        });
      } else {
        setState(() {
          _billingError =
              res['message']?.toString() ?? 'Failed to load billing cycle';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _billingError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  /// Excel export of the billing cycle on screen (same workbook as the web).
  void _exportUsage() {
    final sub = _subscriptionData ?? const <String, dynamic>{};
    String? s(dynamic v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty || t == 'null' ? null : t;
    }

    exportUsage(
      context,
      serviceLineNumber: widget.serviceLineNumber,
      cycle: _billingData,
      limitGb: _limitGb,
      nickname: s(sub['nickname']),
      account: s(sub['company_name']) ?? s(sub['end_user_name']),
      plan: s(sub['subscriptionPlan']),
      start: _selectedPeriod?.startDate,
      end: _selectedPeriod?.endDate,
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperSubtle,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_loading && _billingData != null)
            IconButton(
              tooltip: 'Export usage to Excel',
              icon: const Icon(Icons.download_rounded),
              onPressed: _exportUsage,
            ),
        ],
      ),
      body:
          _loading
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: _brandRed,
                      strokeWidth: 2.5,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Loading subscription…',
                      style: TextStyle(color: Color(0xFF8A96A3), fontSize: 13),
                    ),
                  ],
                ),
              )
              : _error != null
              ? _buildErrorState()
              : _buildBody(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _brandRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: _brandRed,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE90408),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandRed,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _listOf(String key) {
    final v = _subscriptionData?[key];
    return v is List
        ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : const [];
  }

  Widget _buildBody() {
    final terminals = _listOf('routerTerminalMap');
    final plans = _listOf('servicePlan');
    final topUps = _listOf('serviceTopUp');
    return RefreshIndicator(
      onRefresh: _load,
      color: _brandRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_subscriptionError != null)
            _ErrorCard(message: 'Subscription: $_subscriptionError')
          else
            _buildHero(),
          const SizedBox(height: 22),
          const SectionHeading('Usage'),
          _buildUsage(),
          const SizedBox(height: 22),
          SectionHeading('Service plans', trailing: _CountPill(plans.length)),
          _buildPlans(plans),
          const SizedBox(height: 22),
          SectionHeading('Top-ups', trailing: _CountPill(topUps.length)),
          _buildTopUps(topUps),
          const SizedBox(height: 22),
          SectionHeading('Terminal', trailing: _CountPill(terminals.length)),
          SubscriptionKitsCard(
            serviceLineNumber: widget.serviceLineNumber,
            terminals: terminals,
            onChanged: _load,
            canManage: widget.canManageKits,
            canViewRouter: widget.canViewRouter,
          ),
        ],
      ),
    );
  }

  // ── Summary (navy, like the web portal's header) ─────────────────────────

  Widget _buildHero() {
    final d = _subscriptionData ?? const <String, dynamic>{};
    final status = subscriptionStatusLabel(d['active']);
    final active = status == 'ACTIVE';
    final planCode = _text(d['subscriptionPlan']) ?? '';
    final plan =
        const {'NOR': 'Normal', 'IMP': 'IMPACT'}[planCode.toUpperCase()] ??
        (planCode.isEmpty ? '—' : planCode);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.lg + 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.satellite_alt_rounded,
                size: 15,
                color: AppColors.salmon,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.serviceLineNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color:
                            active ? AppColors.success : AppColors.lineStrong,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _text(d['nickname']) ?? 'Service line',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _text(d['address']) ?? '—',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _HeroField('Account', _accountName ?? '—')),
              const SizedBox(width: 14),
              Expanded(child: _HeroField('Plan', plan)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _HeroField('Start', _date(d['startDate']))),
              const SizedBox(width: 14),
              Expanded(
                child:
                    widget.canEditEndDate
                        ? InkWell(
                          onTap: _changeEndDate,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: _HeroField(
                            'End',
                            _date(d['endDate']),
                            trailing: Icons.edit_calendar_outlined,
                          ),
                        )
                        : _HeroField('End', _date(d['endDate'])),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Usage ────────────────────────────────────────────────────────────────

  /// Plan data plus top-ups. Usage is priority data against this, the same
  /// as the backend's usage report and alerts; the cycle's own
  /// usageLimitGB/consumedAmountGB are Starlink overage fields, usually 0.
  double get _limitGb => _listOf('serviceTopUp').fold<double>(
    _parseGb(_subscriptionData?['dataplan']),
    (sum, t) => sum + _parseGb(t['TotalDataAmount'] ?? t['dataAmount']),
  );

  Widget _buildUsage() {
    final bc = _subscriptionData?['billingCycle'];
    final used = _parseGb(bc is Map ? bc['totalPriorityGB'] : null);
    final limit = _limitGb;
    final pct = limit > 0 ? (used / limit * 100) : 0.0;
    final barColor =
        pct >= 90
            ? AppColors.brand
            : pct >= 75
            ? AppColors.warning
            : AppColors.success;
    final cycle = _billingData;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_billingPeriods.isNotEmpty) ...[
            AppSelect<_BillingPeriod>(
              label: 'Billing period',
              sheetTitle: 'Billing period',
              value: _selectedPeriod,
              options: [
                for (final p in _billingPeriods)
                  SelectOption(p, _periodLabel(p)),
              ],
              onChanged: (p) {
                setState(() => _selectedPeriod = p);
                _loadBillingForPeriod(p);
              },
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Current plan usage',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '${_gbShort(used)} / ${_gbShort(limit)} (${pct.round()}%)',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0, 1).toDouble(),
              minHeight: 9,
              backgroundColor: AppColors.paperMuted,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Refreshes every 30–45 minutes',
            style: TextStyle(fontSize: 11, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 16),
          if (_billingError != null)
            _ErrorCard(message: _billingError!)
          else if (cycle == null)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else ...[
            _statRow(
              _StatTile(
                'Consumed',
                _gb(cycle['totalPriorityGB']),
                AppColors.brand,
              ),
              _StatTile('Limit', _gb(limit), AppColors.navy),
            ),
            const SizedBox(height: 8),
            _statRow(
              _StatTile(
                'Priority',
                _gb(cycle['totalPriorityGB']),
                AppColors.info,
              ),
              _StatTile(
                'Standard',
                _gb(cycle['totalStandardGB']),
                AppColors.success,
              ),
            ),
            const SizedBox(height: 8),
            _statRow(
              _StatTile(
                'Opt-in priority',
                _gb(cycle['totalOptInPriorityGB']),
                AppColors.warning,
              ),
              _StatTile(
                'Non-billable',
                _gb(cycle['totalNonBillableGB']),
                AppColors.navy,
              ),
            ),
            const SizedBox(height: 18),
            _buildChart(cycle),
          ],
        ],
      ),
    );
  }

  Widget _statRow(Widget a, Widget b) => Row(
    children: [
      Expanded(child: a),
      const SizedBox(width: 8),
      Expanded(child: b),
    ],
  );

  Widget _buildChart(Map<String, dynamic> cycle) {
    final daily = cycle['dailyUsage'];
    final graphs =
        daily is Map && daily['graphs'] is List
            ? daily['graphs'] as List
            : const [];
    // A graph with no labels is the API's empty placeholder.
    final graph = graphs.whereType<Map>().cast<Map?>().firstWhere((g) {
      final data = g!['data'];
      return data is Map &&
          data['labels'] is List &&
          (data['labels'] as List).isNotEmpty;
    }, orElse: () => null);
    if (graph == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            'No daily usage recorded for this billing cycle yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
          ),
        ),
      );
    }
    final data = graph['data'] as Map;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily usage',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        _UsageUnifiedGraph(
          labels: [for (final l in data['labels'] as List) l.toString()],
          datasets:
              data['datasets'] is List ? data['datasets'] as List : const [],
        ),
      ],
    );
  }

  // ── Service plans ────────────────────────────────────────────────────────

  Widget _buildPlans(List<Map<String, dynamic>> plans) {
    if (plans.isEmpty) return const _EmptySection('No service plans.');
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < plans.length; i++) ...[
            if (i > 0) const Divider(height: 24),
            _planRow(plans[i]),
          ],
        ],
      ),
    );
  }

  Widget _planRow(Map<String, dynamic> p) {
    final price = num.tryParse('${p['pricePerGB']}');
    return Column(
      children: [
        _statRow(
          _Field('Overage limit', _gb(p['usageLimitGB'])),
          _Field('Overage used', _gb(p['consumedAmountGB'])),
        ),
        const SizedBox(height: 12),
        _statRow(
          _Field(
            'Overage price / GB',
            price == null ? '—' : '₱${NumberFormat('#,##0.00').format(price)}',
          ),
          _Field('Active from', _date(p['subscriptionActiveFrom'])),
        ),
      ],
    );
  }

  // ── Top-ups ──────────────────────────────────────────────────────────────

  Widget _buildTopUps(List<Map<String, dynamic>> topUps) {
    if (topUps.isEmpty) return const _EmptySection('No active top-ups.');
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < topUps.length; i++) ...[
            if (i > 0) const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${NumberFormat('#,##0.##').format(_parseGb(topUps[i]['TotalDataAmount'] ?? topUps[i]['dataAmount']))} '
                        '${_text(topUps[i]['dataUnitType']) ?? 'GB'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Expires ${_date(topUps[i]['expirationDate'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _CountPill(
                  int.tryParse('${topUps[i]['count']}') ?? 1,
                  prefix: '×',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Grid
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Unified Usage Graph — Scrollable fl_chart implementation
// ─────────────────────────────────────────────────────────────────────────────

class _UsageUnifiedGraph extends StatelessWidget {
  final List<String> labels;
  final List<dynamic> datasets;

  const _UsageUnifiedGraph({required this.labels, required this.datasets});

  double _parse(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  String _formatDate(String date) {
    try {
      final clean =
          date.contains('T') ? date.split('T').first : date.split(' ').first;
      final dt = DateTime.parse('${clean}T00:00:00');
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
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return date;
    }
  }

  void _showDetailDialog(BuildContext context, int index) {
    if (index < 0 || index >= labels.length) return;

    final date = labels[index];
    final dataList = index < datasets.length ? datasets[index]['data'] : [];

    final p = _parse(dataList.length > 0 ? dataList[0] : 0);
    // API order: [priority, optInPriority, standard, nonBillable].
    final o = _parse(dataList.length > 1 ? dataList[1] : 0);
    final s = _parse(dataList.length > 2 ? dataList[2] : 0);
    final n = _parse(dataList.length > 3 ? dataList[3] : 0);

    final maxVal = [p, s, o, n].reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: _surface,
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Usage Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _inkDark,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(
                    Icons.close_rounded,
                    color: _inkLight,
                    size: 20,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inkLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                _dialogMetric('Priority', p, _accent, effectiveMax),
                const SizedBox(height: 14),
                _dialogMetric('Standard', s, _accentBlue, effectiveMax),
                const SizedBox(height: 14),
                _dialogMetric('Opt-in Priority', o, _amber, effectiveMax),
                const SizedBox(height: 14),
                _dialogMetric('Non-Billable', n, _emerald, effectiveMax),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: _HDivider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Daily Usage',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _inkDark,
                      ),
                    ),
                    Text(
                      '${(p + s + o + n).toStringAsFixed(2)} GB',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _dialogMetric(String label, double value, Color color, double max) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _inkMid,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.toStringAsFixed(2)} GB',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (value / max).clamp(0.0, 1.0),
            backgroundColor: _border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();

    double maxY = 1.0;
    final List<FlSpot> pSpots = [];
    final List<FlSpot> sSpots = [];
    final List<FlSpot> oSpots = [];
    final List<FlSpot> nSpots = [];

    for (int i = 0; i < labels.length; i++) {
      final dataList = i < datasets.length ? datasets[i]['data'] : [];
      final p = _parse(dataList.length > 0 ? dataList[0] : 0);
      // API order: [priority, optInPriority, standard, nonBillable].
      final o = _parse(dataList.length > 1 ? dataList[1] : 0);
      final s = _parse(dataList.length > 2 ? dataList[2] : 0);
      final n = _parse(dataList.length > 3 ? dataList[3] : 0);

      pSpots.add(FlSpot(i.toDouble(), p));
      sSpots.add(FlSpot(i.toDouble(), s));
      oSpots.add(FlSpot(i.toDouble(), o));
      nSpots.add(FlSpot(i.toDouble(), n));

      final dayMax = [p, s, o, n].reduce((a, b) => a > b ? a : b);
      if (dayMax > maxY) maxY = dayMax;
    }
    maxY = (maxY * 1.2).ceilToDouble();

    final bool showS = sSpots.any((s) => s.y > 0);
    final bool showO = oSpots.any((s) => s.y > 0);
    final bool showN = nSpots.any((s) => s.y > 0);

    final double chartWidth = labels.length * 48.0 + 100.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _legendItem('Priority', _accent),
              if (showS) _legendItem('Standard', _accentBlue),
              if (showO) _legendItem('Opt-in', _amber),
              if (showN) _legendItem('Non-Billable', _emerald),
            ],
          ),
        ),
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: EdgeFade(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                  child: SizedBox(
                    width: chartWidth < 300 ? 300 : chartWidth,
                    child: LineChart(
                      LineChartData(
                        maxY: maxY,
                        minX: 0,
                        maxX: (labels.length - 1).toDouble(),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          handleBuiltInTouches: true,
                          touchCallback: (FlTouchEvent event, touchResponse) {
                            if (event is FlTapDownEvent &&
                                touchResponse != null &&
                                touchResponse.lineBarSpots != null &&
                                touchResponse.lineBarSpots!.isNotEmpty) {
                              final index =
                                  touchResponse.lineBarSpots!.first.x.toInt();
                              _showDetailDialog(context, index);
                            }
                          },
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: _inkDark.withOpacity(0.9),
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((s) {
                                return LineTooltipItem(
                                  '${s.y.toStringAsFixed(2)} GB',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine:
                              (v) => FlLine(
                                color: _border.withOpacity(0.5),
                                strokeWidth: 1,
                              ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= labels.length) {
                                  return const SizedBox.shrink();
                                }
                                String label = labels[i];
                                try {
                                  final dt = DateTime.parse(
                                    label.contains('T')
                                        ? label.split('T').first
                                        : label.split(' ').first,
                                  );
                                  label = '${dt.month}/${dt.day}';
                                } catch (_) {}
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      color: _inkLight,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget:
                                  (v, m) => Text(
                                    '${v.toInt()}',
                                    style: const TextStyle(
                                      color: _inkLight,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          _lineData(pSpots, _accent),
                          if (showS) _lineData(sSpots, _accentBlue),
                          if (showO) _lineData(oSpots, _amber),
                          if (showN) _lineData(nSpots, _emerald),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, size: 12, color: _inkLight),
            SizedBox(width: 4),
            Text(
              'Tap points for details',
              style: TextStyle(
                fontSize: 10,
                color: _inkLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  LineChartBarData _lineData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.05)),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _inkMid,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared detail widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: const Color(0xFFF0F4F8));
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F0F3),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF133341).withOpacity(0.35)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFF133341),
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF133341), fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _BillingPeriod {
  final String startDate;
  final String endDate;
  const _BillingPeriod({required this.startDate, required this.endDate});

  @override
  bool operator ==(Object other) =>
      other is _BillingPeriod &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(startDate, endDate);
}

class _HeroField extends StatelessWidget {
  const _HeroField(this.label, this.value, {this.trailing});
  final String label;
  final String value;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.6,
          color: Colors.white60,
        ),
      ),
      const SizedBox(height: 2),
      Row(
        children: [
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Icon(trailing, size: 15, color: Colors.white70),
          ],
        ],
      ),
    ],
  );
}

/// Figure with a colored edge, like the web portal's stat cards.
class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.accent);
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.paperSubtle,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    ],
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.count, {this.prefix = ''});
  final int count;
  final String prefix;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.navy.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$prefix$count',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
    ),
  );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Center(
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
      ),
    ),
  );
}
