import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../services/api_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFFF4F6FA);
const _surface = Color(0xFFFFFFFF);
const _heroTop = Color(0xFF0A2540);
const _heroBot = Color(0xFF1A4080);
const _accent = Color(0xFF2563EB);
const _accentSoft = Color(0xFFEFF6FF);
const _activeGreen = Color(0xFF16A34A);
const _inactiveRed = Color(0xFFDC2626);
const _inkDark = Color(0xFF0F172A);
const _inkMid = Color(0xFF475569);
const _inkLight = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _divider = Color(0xFFF1F5F9);
const _purple = Color(0xFF7C3AED);
const _orange = Color(0xFFEA580C);
const _teal = Color(0xFF0891B2);
const _amber = Color(0xFFF59E0B);
const _emerald = Color(0xFF10B981);
const _indigo = Color(0xFF6366F1);

/// Shared robust active-status resolver.
bool _isActiveSub(Map<String, dynamic> sub) {
  for (final key in ['active', 'is_active', 'isActive', 'status', 'state']) {
    final raw = sub[key];
    if (raw == null) continue;
    if (raw is bool) return raw;
    if (raw is int) return raw == 1;
    final s = raw.toString().toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'active' || s == 'enabled') return true;
    if (s == 'false' || s == '0' || s == 'inactive' || s == 'disabled') {
      return false;
    }
  }
  return false;
}

class UserSubscriptionDetailsPage extends StatefulWidget {
  final String serviceLineNumber;
  final String title;

  const UserSubscriptionDetailsPage({
    super.key,
    required this.serviceLineNumber,
    required this.title,
  });

  @override
  State<UserSubscriptionDetailsPage> createState() =>
      _UserSubscriptionDetailsPageState();
}

class _UserSubscriptionDetailsPageState
    extends State<UserSubscriptionDetailsPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _subscriptionData;
  Map<String, dynamic>? _billingData;
  String? _subscriptionError;
  String? _billingError;
  String? _cycleStart;
  String? _cycleEnd;
  List<_BillingPeriod> _billingPeriods = [];
  _BillingPeriod? _selectedPeriod;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _str(dynamic v) =>
      (v == null || v.toString() == 'null' || v.toString().isEmpty)
          ? '—'
          : v.toString();

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

  String _gbStr(dynamic v) {
    final d = _parseGb(v);
    return d == 0 ? '0 GB' : '${d.toStringAsFixed(2)} GB';
  }

  String _toMonthYear(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    try {
      final clean =
          raw.contains('T') ? raw.split('T').first : raw.split(' ').first;
      final dt = DateTime.parse('${clean}T00:00:00');
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw ?? '—';
    }
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null' || raw == '0000-00-00') {
      return '—';
    }
    try {
      final clean =
          raw.contains('T') ? raw.split('T').first : raw.split(' ').first;
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
      return raw;
    }
  }

  String _periodLabel(_BillingPeriod p) {
    final s = _toMonthYear(p.startDate);
    final e = _toMonthYear(p.endDate);
    return s == e ? s : '$s - $e';
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _subscriptionError = null;
      _billingError = null;
      _subscriptionData = null;
      _billingData = null;
      _cycleStart = null;
      _cycleEnd = null;
      _billingPeriods = [];
      _selectedPeriod = null;
    });
    _animController.reset();

    final sln = widget.serviceLineNumber.trim();
    ApiService.refreshStarlinkServiceLine(sln).catchError((_) {});

    Map<String, dynamic>? subResult;
    String? subErr;
    try {
      final res = await ApiService.getSubscriptionByServiceLineNumber(sln);
      if (res['status'] == 'success') {
        final d = res['data'];
        subResult =
            d is Map
                ? Map<String, dynamic>.from(d)
                : <String, dynamic>{'raw': d};
      } else {
        subErr =
            res['message']?.toString() ?? 'Could not load your subscription.';
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
              res['message']?.toString() ?? 'Could not load billing data.';
        }
      } catch (e) {
        billingErr = e.toString().replaceAll('Exception: ', '');
      }
    } else {
      billingErr = 'No billing dates available.';
    }

    if (!mounted) return;
    setState(() {
      _subscriptionData = subResult;
      _subscriptionError = subErr;
      _billingData = billingResult;
      _billingError = billingErr;
      _cycleStart = useStart;
      _cycleEnd = useEnd;
      _billingPeriods = periods;
      _selectedPeriod = periods.isNotEmpty ? periods.first : null;
      _loading = false;
      if (subResult == null && billingResult == null) {
        _error = 'Unable to load your subscription details.';
      }
    });
    if (_error == null) _animController.forward();
  }

  Future<void> _loadBillingForPeriod(_BillingPeriod period) async {
    setState(() {
      _billingData = null;
      _billingError = null;
      _cycleStart = period.startDate;
      _cycleEnd = period.endDate;
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
              res['message']?.toString() ?? 'Could not load billing data.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _billingError = e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body:
            _loading
                ? _buildLoading()
                : _error != null
                ? _buildErrorState()
                : _buildBody(),
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Container(
      color: _bg,
      child: Column(
        children: [
          _buildHeroShell(showBack: true),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
                  SizedBox(height: 16),
                  Text(
                    'Loading your subscription…',
                    style: TextStyle(
                      color: _inkLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroShell({required bool showBack}) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_heroTop, _heroBot],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (showBack)
                _CircleButton(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_heroTop, _heroBot],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  _CircleButton(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _inactiveRed.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      color: _inactiveRed,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(
                      color: _inkDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _inkMid,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 15,
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Main Body ──────────────────────────────────────────────────────────────

  Widget _buildBody() {
    final sub = _subscriptionData;
    final isActive = sub != null ? _isActiveSub(sub) : false;
    final nickname = _str(sub?['nickname']);

    // Parse hardware info
    final rtm = sub?['routerTerminalMap'];
    final hardware =
        (rtm is List && rtm.isNotEmpty)
            ? Map<String, dynamic>.from(rtm.first)
            : (rtm is Map ? Map<String, dynamic>.from(rtm) : null);

    // Parse usage
    final bc = sub?['billingCycle'];
    final Map<String, dynamic>? billing =
        bc is Map ? Map<String, dynamic>.from(bc) : null;
    final totalPriorityGB = _parseGb(
      billing?['totalPriorityGB'] ?? billing?['total_priority_gb'],
    );
    final dataplanGb = _parseGb(sub?['dataplan']);
    final serviceTopUps = sub?['serviceTopUp'] as List?;
    double topup = 0;
    if (serviceTopUps != null) {
      for (final item in serviceTopUps) {
        if (item is Map) {
          topup += _parseGb(item['amountGB'] ?? item['amount_gb']);
        }
      }
    }
    final usageLimitGb = _parseGb(
      billing?['usageLimitGB'] ??
          billing?['usage_limit_gb'] ??
          sub?['usageLimitGB'] ??
          sub?['usage_limit_gb'],
    );
    final effectiveLimit = usageLimitGb > 0 ? usageLimitGb : dataplanGb;
    final totalUsed = totalPriorityGB + topup;
    final progress =
        effectiveLimit > 0 ? (totalUsed / effectiveLimit).clamp(0.0, 1.0) : 0.0;
    final isOverLimit = effectiveLimit > 0 && totalUsed > effectiveLimit;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Hero AppBar ──────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: _heroTop,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: _CircleButton(
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: _UserHeroHeader(
              nickname: nickname,
              serviceLineNumber: widget.serviceLineNumber,
              isActive: isActive,
            ),
          ),
        ),

        // ── Content ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Service Line Chip ────────────────────────────
                    _ServiceLineChip(
                      serviceLineNumber: widget.serviceLineNumber,
                    ),
                    const SizedBox(height: 14),

                    // ── Subscription Card ────────────────────────────
                    if (_subscriptionError != null)
                      _InlineError(message: _subscriptionError!)
                    else
                      _SubscriptionCard(
                        data: sub,
                        hardware: hardware,
                        totalUsed: totalUsed,
                        effectiveLimit: effectiveLimit,
                        dataplanGb: dataplanGb,
                        topup: topup,
                        progress: progress,
                        isOverLimit: isOverLimit,
                        isActive: isActive,
                        gbStr: _gbStr,
                        fmtDate: _fmtDate,
                        strVal: _str,
                      ),

                    const SizedBox(height: 14),

                    // ── Billing Card ─────────────────────────────────
                    _BillingCard(
                      billingData: _billingData,
                      billingError: _billingError,
                      periods: _billingPeriods,
                      selectedPeriod: _selectedPeriod,
                      toMonthYear: _toMonthYear,
                      onPeriodChanged: (p) {
                        setState(() => _selectedPeriod = p);
                        _loadBillingForPeriod(p);
                      },
                      gbStr: _gbStr,
                      parseGb: _parseGb,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Hero Header
// ─────────────────────────────────────────────────────────────────────────────

class _UserHeroHeader extends StatelessWidget {
  final String nickname;
  final String serviceLineNumber;
  final bool isActive;

  const _UserHeroHeader({
    required this.nickname,
    required this.serviceLineNumber,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_heroTop, _heroBot],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -50,
            child: _DecorCircle(
              size: 180,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -20,
            child: _DecorCircle(
              size: 110,
              color: Colors.white.withOpacity(0.03),
            ),
          ),
          Positioned(
            top: 70,
            right: 80,
            child: _DecorCircle(
              size: 50,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 52,
              24,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.satellite_alt_rounded,
                        color: Colors.white60,
                        size: 12,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'MY SUBSCRIPTION',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white60,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.numbers_rounded,
                      color: Colors.white.withOpacity(0.5),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      serviceLineNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service Line Chip
// ─────────────────────────────────────────────────────────────────────────────

class _ServiceLineChip extends StatelessWidget {
  final String serviceLineNumber;
  const _ServiceLineChip({required this.serviceLineNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.satellite_alt_rounded,
              color: _accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Line',
                  style: TextStyle(
                    fontSize: 11,
                    color: _inkLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  serviceLineNumber,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _inkDark,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _accent.withOpacity(0.2)),
            ),
            child: const Text(
              'Refreshes every 30–45 min',
              style: TextStyle(
                fontSize: 9,
                color: _accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subscription Card
// ─────────────────────────────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? hardware;
  final double totalUsed;
  final double effectiveLimit;
  final double dataplanGb;
  final double topup;
  final double progress;
  final bool isOverLimit;
  final bool isActive;
  final String Function(dynamic) gbStr;
  final String Function(String?) fmtDate;
  final String Function(dynamic) strVal;

  const _SubscriptionCard({
    required this.data,
    required this.hardware,
    required this.totalUsed,
    required this.effectiveLimit,
    required this.dataplanGb,
    required this.topup,
    required this.progress,
    required this.isOverLimit,
    required this.isActive,
    required this.gbStr,
    required this.fmtDate,
    required this.strVal,
  });

  String _hw(String? a, String? b) {
    if (a != null && a != 'null' && a.isNotEmpty) return a;
    if (b != null && b != 'null' && b.isNotEmpty) return b;
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final starlinkId = _hw(
      hardware?['starlink_id']?.toString() ??
          hardware?['starlinkId']?.toString(),
      data?['starlink_id']?.toString() ?? data?['starlinkId']?.toString(),
    );
    final serialNumber = _hw(
      hardware?['serial_number']?.toString() ??
          hardware?['serialNumber']?.toString(),
      data?['serial_number']?.toString() ?? data?['serialNumber']?.toString(),
    );
    final kitNumber = _hw(
      hardware?['kit_number']?.toString() ?? hardware?['kitNumber']?.toString(),
      data?['kit_number']?.toString() ?? data?['kitNumber']?.toString(),
    );

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nickname',
                        style: TextStyle(
                          fontSize: 11,
                          color: _inkLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        strVal(data?['nickname']),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _inkDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(fontSize: 12, color: _inkLight),
                    ),
                    _StatusBadge(active: isActive),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const _HDivider(),

          // ── Hardware ───────────────────────────────────────────────
          if (starlinkId != '—' || serialNumber != '—' || kitNumber != '—')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  if (starlinkId != '—') ...[
                    _InfoRow(label: 'Starlink ID', value: starlinkId),
                    const SizedBox(height: 10),
                  ],
                  if (serialNumber != '—') ...[
                    _InfoRow(label: 'Serial Number', value: serialNumber),
                    const SizedBox(height: 10),
                  ],
                  if (kitNumber != '—')
                    _InfoRow(label: 'Kit Number', value: kitNumber),
                ],
              ),
            ),

          if (starlinkId != '—' || serialNumber != '—' || kitNumber != '—') ...[
            const SizedBox(height: 14),
            const _HDivider(),
          ],

          // ── End Date ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Valid Until',
                  style: TextStyle(
                    fontSize: 11,
                    color: _inkLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: _inkLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fmtDate(data?['endDate']?.toString()),
                        style: const TextStyle(
                          fontSize: 13,
                          color: _inkDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _HDivider(),

          // ── Current Plan Usage ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Plan Usage',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _inkDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${gbStr(totalUsed)} / ${gbStr(effectiveLimit)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isOverLimit ? _inactiveRed : _inkDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (isOverLimit) ...[
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: _inactiveRed,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Data limit exceeded',
                        style: TextStyle(
                          fontSize: 11,
                          color: _inactiveRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: _border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOverLimit
                          ? _inactiveRed
                          : progress > 0.7
                          ? _amber
                          : _accent,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 14),
                _UsageRow(
                  label: 'Current monthly data',
                  value: gbStr(dataplanGb),
                ),
                const SizedBox(height: 8),
                _UsageRow(label: 'Top-Up data', value: gbStr(topup)),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _HDivider(),

          // ── Address ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Address',
                  style: TextStyle(
                    fontSize: 11,
                    color: _inkLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: _inkLight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        strVal(data?['address']),
                        style: const TextStyle(
                          fontSize: 13,
                          color: _inkDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Billing Card
// ─────────────────────────────────────────────────────────────────────────────

class _BillingCard extends StatelessWidget {
  final Map<String, dynamic>? billingData;
  final String? billingError;
  final List<_BillingPeriod> periods;
  final _BillingPeriod? selectedPeriod;
  final String Function(String?) toMonthYear;
  final ValueChanged<_BillingPeriod> onPeriodChanged;
  final String Function(dynamic) gbStr;
  final double Function(dynamic) parseGb;

  const _BillingCard({
    required this.billingData,
    required this.billingError,
    required this.periods,
    required this.selectedPeriod,
    required this.toMonthYear,
    required this.onPeriodChanged,
    required this.gbStr,
    required this.parseGb,
  });

  String _periodLabel(_BillingPeriod p) {
    final s = toMonthYear(p.startDate);
    final e = toMonthYear(p.endDate);
    return s == e ? s : '$s - $e';
  }

  @override
  Widget build(BuildContext context) {
    double totalPriorityFromDatasets = 0;
    final dailyUsage = billingData?['dailyUsage'];
    final List<dynamic> graphs =
        (dailyUsage is Map) ? (dailyUsage['graphs'] as List? ?? []) : [];

    if (graphs.isNotEmpty) {
      final g = graphs.first;
      final dataMap = g['data'] as Map? ?? {};
      final datasets = dataMap['datasets'] as List? ?? [];
      for (var d in datasets) {
        if (d is Map) {
          final dataList = d['data'] as List? ?? [];
          if (dataList.isNotEmpty) {
            totalPriorityFromDatasets += parseGb(dataList[0]);
          }
        }
      }
    }

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Period Dropdown ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select billing period:',
                  style: TextStyle(
                    fontSize: 11,
                    color: _inkLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: _surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (ctx) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: _border,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Select Billing Period',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _inkDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.4,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: periods.length,
                                  itemBuilder: (context, index) {
                                    final p = periods[index];
                                    final isSelected = p == selectedPeriod;
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 24,
                                          ),
                                      title: Text(
                                        _periodLabel(p),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                          color:
                                              isSelected ? _accent : _inkDark,
                                        ),
                                      ),
                                      trailing:
                                          isSelected
                                              ? const Icon(
                                                Icons.check_circle_rounded,
                                                color: _accent,
                                                size: 20,
                                              )
                                              : null,
                                      onTap: () {
                                        onPeriodChanged(p);
                                        Navigator.pop(ctx);
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedPeriod != null
                                ? _periodLabel(selectedPeriod!)
                                : 'Select period',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _inkDark,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _inkLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _HDivider(),

          if (billingError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _InlineError(message: billingError!),
            )
          else if (billingData == null)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(
                child: CircularProgressIndicator(
                  color: _accent,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Updated Data Usage ─────────────────────────────
                  const Text(
                    'Updated Data Usage',
                    style: TextStyle(
                      fontSize: 11,
                      color: _inkLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accent.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // const Text(
                        //   'Total Priority Data',
                        //   style: TextStyle(
                        //     fontSize: 12,
                        //     color: _inkMid,
                        //     fontWeight: FontWeight.w500,
                        //   ),
                        // ),
                        // const SizedBox(height: 4),
                        Text(
                          gbStr(totalPriorityFromDatasets),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _HDivider(),
                  const SizedBox(height: 16),

                  // ── Daily Usage Graph ──────────────────────────────
                  const Text(
                    'Daily Usage Trends',
                    style: TextStyle(
                      fontSize: 11,
                      color: _inkLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (_) {
                      if (graphs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: const Center(
                            child: Text(
                              'No daily usage data available',
                              style: TextStyle(fontSize: 13, color: _inkLight),
                            ),
                          ),
                        );
                      }
                      final g = graphs.first;
                      final dataMap = g['data'] as Map? ?? {};
                      final labels =
                          (dataMap['labels'] as List? ?? [])
                              .map((e) => e.toString())
                              .toList();
                      final datasets = dataMap['datasets'] as List? ?? [];

                      return _UsageUnifiedGraph(
                        labels: labels,
                        datasets: datasets,
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

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
    final s = _parse(dataList.length > 1 ? dataList[1] : 0);
    final o = _parse(dataList.length > 2 ? dataList[2] : 0);
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
                _dialogMetric('Standard', s, _indigo, effectiveMax),
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
      final s = _parse(dataList.length > 1 ? dataList[1] : 0);
      final o = _parse(dataList.length > 2 ? dataList[2] : 0);
      final n = _parse(dataList.length > 3 ? dataList[3] : 0);

      pSpots.add(FlSpot(i.toDouble(), p));
      sSpots.add(FlSpot(i.toDouble(), s));
      oSpots.add(FlSpot(i.toDouble(), o));
      nSpots.add(FlSpot(i.toDouble(), n));

      final dayMax = [p, s, o, n].reduce((a, b) => a > b ? a : b);
      if (dayMax > maxY) maxY = dayMax;
    }
    maxY = (maxY * 1.2).ceilToDouble();

    // Only show a line series if it has at least one non-zero value
    final bool showS = sSpots.any((s) => s.y > 0);
    final bool showO = oSpots.any((s) => s.y > 0);
    final bool showN = nSpots.any((s) => s.y > 0);

    // 48px per point + 60 left margin + 40 right padding so last dot is never clipped
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
              if (showS) _legendItem('Standard', _indigo),
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // extra right padding so the last label + dot is fully visible
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
                        if (showS) _lineData(sSpots, _indigo),
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
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _HDivider extends StatelessWidget {
  const _HDivider();

  @override
  Widget build(BuildContext context) => Container(height: 1, color: _divider);
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? _activeGreen : _inactiveRed;
    final bg = active ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'ACTIVE' : 'INACTIVE',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: _inkLight)),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _inkDark,
        ),
      ),
    ],
  );
}

class _UsageRow extends StatelessWidget {
  final String label;
  final String value;
  const _UsageRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 12.5, color: _inkMid)),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12.5,
          color: _inkDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _inactiveRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _inactiveRed.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _inactiveRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _inactiveRed,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _CircleButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _DecorCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1.5),
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
