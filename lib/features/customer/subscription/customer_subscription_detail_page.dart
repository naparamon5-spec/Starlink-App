import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:starlink_app/services/api_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFFF6F7F9);
const _surface = Color(0xFFFFFFFF);
const _heroTop = Color(0xFF0A1628);
const _heroBot = Color(0xFF0D2444);
const _accent = Color(0xFFEB1E23);
const _accentBlue = Color(0xFF1A6FE8);
const _activeGreen = Color(0xFF00C48C);
const _inactiveRed = Color(0xFFFF4757);
const _inkDark = Color(0xFF0D1B2A);
const _inkMid = Color(0xFF4A5568);
const _inkLight = Color(0xFF9AA5B4);
const _border = Color(0xFFEBEEF2);
const _divider = Color(0xFFF0F4F8);
const _amber = Color(0xFFF59E0B);
const _emerald = Color(0xFF10B981);

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

class CustomerSubscriptionDetailsPage extends StatefulWidget {
  final String serviceLineNumber;
  final String title;

  const CustomerSubscriptionDetailsPage({
    super.key,
    required this.serviceLineNumber,
    required this.title,
  });

  @override
  State<CustomerSubscriptionDetailsPage> createState() =>
      _CustomerSubscriptionDetailsPageState();
}

class _CustomerSubscriptionDetailsPageState
    extends State<CustomerSubscriptionDetailsPage>
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
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
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
    try {
      final s = DateTime.parse(
        p.startDate.contains('T') ? p.startDate : '${p.startDate}T00:00:00',
      );
      final e = DateTime.parse(
        p.endDate.contains('T') ? p.endDate : '${p.endDate}T00:00:00',
      );
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
      return '${months[s.month - 1]} ${s.year} – ${months[e.month - 1]} ${e.year}';
    } catch (_) {
      return '${p.startDate} – ${p.endDate}';
    }
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
    ApiService.refreshStarlinkServiceLine(sln).catchError((_) => <String, dynamic>{});

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
      _cycleStart = useStart;
      _cycleEnd = useEnd;
      _billingPeriods = periods;
      _selectedPeriod = periods.isNotEmpty ? periods.first : null;
      _loading = false;
      if (subResult == null && billingResult == null) {
        _error = 'Failed to load subscription data.';
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
              res['message']?.toString() ?? 'Failed to load billing cycle';
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

  Widget _buildLoading() {
    return Container(
      color: _bg,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 200,
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
          ),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
                  SizedBox(height: 16),
                  Text(
                    'Loading subscription…',
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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: _accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _inkDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildBody() {
    final sub = _subscriptionData;
    final isActive = sub != null ? _isActiveSub(sub) : false;
    final nickname = _str(sub?['nickname']);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Hero AppBar ──────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 240,
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
            background: _HeroHeader(
              nickname: nickname,
              serviceLineNumber: widget.serviceLineNumber,
              isActive: isActive,
            ),
          ),
        ),

        // ── Content ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status banner
                    _StatusBanner(isActive: isActive),
                    const SizedBox(height: 28),

                    // ── Subscription section ───────────────────────────────
                    const _SectionLabel(label: 'SUBSCRIPTION'),
                    const SizedBox(height: 12),

                    if (_subscriptionError != null)
                      _InlineError(message: _subscriptionError!)
                    else ...[
                      _DetailCard(
                        items: [
                          _DetailItem(
                            icon: Icons.person_outline_rounded,
                            label: 'Nickname',
                            value: _str(sub?['nickname']),
                            accent: _accentBlue,
                          ),
                          _DetailItem(
                            icon: Icons.event_busy_rounded,
                            label: 'End Date',
                            value: _fmtDate(sub?['endDate']?.toString()),
                            accent: const Color(0xFFEA7C00),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AddressCard(address: _str(sub?['address'])),
                      const SizedBox(height: 12),
                      _HardwareCard(data: sub),
                      const SizedBox(height: 12),
                      _UsageCard(
                        subscriptionData: sub,
                        billingData: _billingData,
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Billing section ────────────────────────────────────
                    const _SectionLabel(label: 'BILLING CYCLE'),
                    const SizedBox(height: 12),

                    _BillingCard(
                      billingData: _billingData,
                      billingError: _billingError,
                      periods: _billingPeriods,
                      selectedPeriod: _selectedPeriod,
                      onPeriodChanged: (p) {
                        setState(() => _selectedPeriod = p);
                        _loadBillingForPeriod(p);
                      },
                      periodLabel: _periodLabel,
                      gbStr: _gbStr,
                      parseGb: _parseGb,
                    ),
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
// Hero Header
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String nickname;
  final String serviceLineNumber;
  final bool isActive;

  const _HeroHeader({
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
            top: -40,
            right: -40,
            child: _DecorCircle(
              size: 200,
              color: Colors.white.withOpacity(0.03),
            ),
          ),
          Positioned(
            bottom: 30,
            left: -30,
            child: _DecorCircle(
              size: 140,
              color: Colors.white.withOpacity(0.025),
            ),
          ),
          Positioned(
            top: 80,
            right: 60,
            child: _DecorCircle(
              size: 60,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 56,
              24,
              28,
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
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.satellite_alt_rounded,
                        color: Colors.white54,
                        size: 13,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'STARLINK',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.tag_rounded,
                      color: Colors.white.withOpacity(0.5),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      serviceLineNumber,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        'Refreshes 30–45 min',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
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
// Status Banner
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final bool isActive;
  const _StatusBanner({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _activeGreen : _inactiveRed;
    final message =
        isActive
            ? 'This subscription is currently active and running.'
            : 'This subscription is currently inactive.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive
                  ? Icons.check_circle_outline_rounded
                  : Icons.cancel_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _inkMid,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          _PulseDot(color: color, active: isActive),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hardware Card
// ─────────────────────────────────────────────────────────────────────────────

class _HardwareCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _HardwareCard({required this.data});

  String _str(dynamic v) =>
      (v == null || v.toString() == 'null' || v.toString().isEmpty)
          ? '—'
          : v.toString();

  @override
  Widget build(BuildContext context) {
    final rtm = data?['routerTerminalMap'];
    final hardware =
        (rtm is List && rtm.isNotEmpty)
            ? Map<String, dynamic>.from(rtm.first)
            : (rtm is Map ? Map<String, dynamic>.from(rtm) : null);

    final starlinkId = _str(
      hardware?['starlink_id'] ??
          hardware?['starlinkId'] ??
          data?['starlink_id'] ??
          data?['starlinkId'],
    );
    final serialNumber = _str(
      hardware?['serial_number'] ??
          hardware?['serialNumber'] ??
          data?['serial_number'] ??
          data?['serialNumber'],
    );
    final kitNumber = _str(
      hardware?['kit_number'] ??
          hardware?['kitNumber'] ??
          data?['kit_number'] ??
          data?['kitNumber'],
    );

    if (starlinkId == '—' && serialNumber == '—' && kitNumber == '—') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.router_rounded,
                  color: Color(0xFF7C3AED),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Hardware',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _inkDark,
                ),
              ),
            ],
          ),
          if (starlinkId != '—') ...[
            const SizedBox(height: 14),
            const _HDivider(),
            const SizedBox(height: 14),
            _InfoRow(label: 'Starlink ID', value: starlinkId),
          ],
          if (serialNumber != '—') ...[
            const SizedBox(height: 10),
            _InfoRow(label: 'Serial Number', value: serialNumber),
          ],
          if (kitNumber != '—') ...[
            const SizedBox(height: 10),
            _InfoRow(label: 'Kit Number', value: kitNumber),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Usage Card
// ─────────────────────────────────────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  final Map<String, dynamic>? subscriptionData;
  final Map<String, dynamic>? billingData;
  const _UsageCard({required this.subscriptionData, required this.billingData});

  double _pg(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  String _gb(dynamic v) {
    final d = _pg(v);
    return d == 0 ? '0 GB' : '${d.toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final bc = subscriptionData?['billingCycle'];
    final Map<String, dynamic>? billing =
        bc is Map ? Map<String, dynamic>.from(bc) : null;

    final totalPriorityGB = _pg(
      billing?['totalPriorityGB'] ?? billing?['total_priority_gb'],
    );
    final dataplanGb = _pg(subscriptionData?['dataplan']);

    final serviceTopUps = subscriptionData?['serviceTopUp'] as List?;
    double topup = 0;
    if (serviceTopUps != null) {
      for (final item in serviceTopUps) {
        if (item is Map) {
          topup += _pg(item['amountGB'] ?? item['amount_gb']);
        }
      }
    }

    final usageLimitGb = _pg(
      billing?['usageLimitGB'] ??
          billing?['usage_limit_gb'] ??
          subscriptionData?['usageLimitGB'] ??
          subscriptionData?['usage_limit_gb'],
    );
    final effectiveLimit = usageLimitGb > 0 ? usageLimitGb : dataplanGb;
    final totalUsed = totalPriorityGB + topup;
    final progress =
        effectiveLimit > 0 ? (totalUsed / effectiveLimit).clamp(0.0, 1.0) : 0.0;
    final isOverLimit = effectiveLimit > 0 && totalUsed > effectiveLimit;

    final barColor =
        isOverLimit
            ? const Color(0xFFEF4444)
            : progress > 0.7
            ? const Color(0xFFF59E0B)
            : _accentBlue;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _accentBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.data_usage_rounded,
                    color: _accentBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Plan Usage',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _inkDark,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_gb(totalUsed)} / ${_gb(effectiveLimit)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOverLimit ? const Color(0xFFEF4444) : _inkLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (isOverLimit) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Data limit exceeded',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE8ECF0),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}% used',
                  style: const TextStyle(fontSize: 10, color: _inkLight),
                ),
                if (effectiveLimit > 0 && !isOverLimit)
                  Text(
                    '${_gb(effectiveLimit - totalUsed)} remaining',
                    style: const TextStyle(fontSize: 10, color: _inkLight),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const _HDivider(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Monthly Data',
                    value: _gb(dataplanGb),
                    color: _accentBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStat(
                    label: 'Top-Up Data',
                    value: _gb(topup),
                    color: const Color(0xFF7C3AED),
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

// ─────────────────────────────────────────────────────────────────────────────
// Billing Section
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Billing Card (Aligned with End User UI)
// ─────────────────────────────────────────────────────────────────────────────

class _BillingCard extends StatelessWidget {
  final Map<String, dynamic>? billingData;
  final String? billingError;
  final List<_BillingPeriod> periods;
  final _BillingPeriod? selectedPeriod;
  final ValueChanged<_BillingPeriod> onPeriodChanged;
  final String Function(_BillingPeriod) periodLabel;
  final String Function(dynamic) gbStr;
  final double Function(dynamic) parseGb;

  const _BillingCard({
    required this.billingData,
    required this.billingError,
    required this.periods,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.periodLabel,
    required this.gbStr,
    required this.parseGb,
  });

  @override
  Widget build(BuildContext context) {
    final priority = parseGb(
      billingData?['totalPriorityGB'] ?? billingData?['total_priority_gb'],
    );
    final standard = parseGb(
      billingData?['totalStandardGB'] ?? billingData?['total_standard_gb'],
    );
    final optin = parseGb(
      billingData?['totalOptInPriorityGB'] ??
          billingData?['total_opt_in_priority_gb'],
    );
    final nonBillable = parseGb(
      billingData?['totalNonBillableGB'] ??
          billingData?['total_non_billable_gb'],
    );

    final dailyUsage = billingData?['dailyUsage'];
    final List<dynamic> graphs =
        (dailyUsage is Map) ? (dailyUsage['graphs'] as List? ?? []) : [];

    double datasetsPriorityTotal = 0;
    if (graphs.isNotEmpty) {
      final g = graphs.first;
      final dataMap = g['data'] as Map? ?? {};
      final datasets = dataMap['datasets'] as List? ?? [];
      for (final ds in datasets) {
        if (ds is Map) {
          final dList = ds['data'] as List? ?? [];
          if (dList.isNotEmpty) {
            datasetsPriorityTotal += parseGb(dList[0]);
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
                    if (periods.isEmpty) return;
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
                                        periodLabel(p),
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
                                ? periodLabel(selectedPeriod!)
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
                if (billingData != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Updated Data Usage',
                        style: TextStyle(
                          fontSize: 12,
                          color: _inkMid,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        gbStr(datasetsPriorityTotal),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _accent,
                        ),
                      ),
                    ],
                  ),
                ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared detail widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<_DetailItem> items;
  const _DetailCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(child: _DetailItemWidget(item: items[i])),
            if (i < items.length - 1)
              Container(width: 1, height: 52, color: _border),
          ],
        ],
      ),
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
}

class _DetailItemWidget extends StatelessWidget {
  final _DetailItem item;
  const _DetailItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _inkLight,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _inkDark,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final String address;
  const _AddressCard({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF0891B2),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Address',
                  style: TextStyle(
                    fontSize: 10,
                    color: _inkLight,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inkDark,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _inkDark,
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: _inkLight,
      letterSpacing: 1.4,
    ),
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
        color: _accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _accent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) => Container(height: 1, color: _divider);
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

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool active;
  const _PulseDot({required this.color, required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    if (widget.active) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _ctrl,
              builder:
                  (_, __) => Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withOpacity(_opacity.value),
                      ),
                    ),
                  ),
            ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
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
