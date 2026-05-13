import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../services/api_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFFF6F7F9);
const _surface = Color(0xFFFFFFFF);
const _accent = Color(0xFFEB1E23);
const _accentBlue = Color(0xFF1A6FE8);
const _inkDark = Color(0xFF0D1B2A);
const _inkMid = Color(0xFF4A5568);
const _inkLight = Color(0xFF9AA5B4);
const _border = Color(0xFFEBEEF2);
const _divider = Color(0xFFF0F4F8);
const _amber = Color(0xFFF59E0B);
const _emerald = Color(0xFF10B981);
const _indigo = Color(0xFF6366F1);

class AdminSubscriptionDetailsPage extends StatefulWidget {
  final String serviceLineNumber;
  final String title;

  const AdminSubscriptionDetailsPage({
    super.key,
    required this.serviceLineNumber,
    required this.title,
  });

  @override
  State<AdminSubscriptionDetailsPage> createState() =>
      _AdminSubscriptionDetailsPageState();
}

class _AdminSubscriptionDetailsPageState
    extends State<AdminSubscriptionDetailsPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _subscriptionData;
  Map<String, dynamic>? _billingData;
  Map<String, dynamic>? _billingStatus;

  String? _subscriptionError;
  String? _billingError;
  String? _billingStatusError;

  String? _cycleStart;
  String? _cycleEnd;

  List<_BillingPeriod> _billingPeriods = [];
  _BillingPeriod? _selectedPeriod;

  static const _brandRed = Color(0xFFEB1E23);

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

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

  /// FIX 1 — Convert "2026-04-20" → "April 2026"
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
      return raw;
    }
  }

  String _periodLabel(_BillingPeriod p) {
    final s = _toMonthYear(p.startDate);
    final e = _toMonthYear(p.endDate);
    return s == e ? s : '$s - $e';
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
      _cycleStart = null;
      _cycleEnd = null;
      _billingPeriods = [];
      _selectedPeriod = null;
    });

    final sln = widget.serviceLineNumber.trim();
    ApiService.refreshStarlinkServiceLine(sln).catchError((_) => {});

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

    Map<String, dynamic>? statusResult;
    String? statusErr;
    try {
      // Assuming a GET request to the endpoint that returns the requested JSON
      final res = await ApiService.getSubscriptionByServiceLineNumber(sln);
      if (res['status'] == 'success') {
        final d = res['data'];
        statusResult =
            d is Map
                ? Map<String, dynamic>.from(d)
                : <String, dynamic>{'raw': d};
      } else {
        statusErr = res['message']?.toString() ?? 'Status fetch failed';
      }
    } catch (e) {
      statusErr = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _subscriptionData = subResult;
      _subscriptionError = subErr;
      _billingData = billingResult;
      _billingError = billingErr;
      _billingStatus = statusResult;
      _billingStatusError = statusErr;
      _cycleStart = useStart;
      _cycleEnd = useEnd;
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

    if (picked != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected new end date: ${picked.toString().split(' ').first}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: _brandRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
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
      setState(() {
        _billingError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF000000),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8ECF0)),
        ),
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
                color: Color(0xFF000000),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _load,
      color: _brandRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _ServiceLineChip(
            serviceLineNumber: widget.serviceLineNumber,
            brandRed: _brandRed,
          ),
          const SizedBox(height: 14),
          if (_subscriptionError != null)
            _ErrorCard(message: 'Subscription: $_subscriptionError')
          else
            _SubscriptionCard(
              data: _subscriptionData,
              onDateTap: _changeEndDate,
            ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 24),
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
  final Color brandRed;
  const _ServiceLineChip({
    required this.serviceLineNumber,
    required this.brandRed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: brandRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.satellite_alt_rounded, color: brandRed, size: 20),
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
                    color: Color(0xFF8A96A3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  serviceLineNumber,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF000000),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: brandRed.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: brandRed.withOpacity(0.2)),
            ),
            child: Text(
              'Refreshes every 30–45 min',
              style: TextStyle(
                fontSize: 9,
                color: brandRed,
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
  final VoidCallback? onDateTap;
  const _SubscriptionCard({required this.data, this.onDateTap});

  String _str(dynamic v) =>
      (v == null || v.toString() == 'null' || v.toString().isEmpty)
          ? '—'
          : v.toString();

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null' || raw == '0000-00-00')
      return 'No end date';
    try {
      final clean =
          raw.contains('T') ? raw.split('T').first : raw.split(' ').first;
      final dt = DateTime.parse('${clean}T00:00:00');
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
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  bool get _isActive {
    if (data == null) return false;
    final v = data!['active']?.toString().toLowerCase() ?? '';
    return v == 'true' || v == '1' || v == 'active';
  }

  double _parseGb(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  String _gbStr(dynamic v) {
    final d = _parseGb(v);
    return d == 0 ? '0 GB' : '${d.toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final active = _isActive;
    final bc = data?['billingCycle'];
    final Map<String, dynamic>? billing =
        bc is Map ? Map<String, dynamic>.from(bc) : null;

    // FIX: Current Plan Usage = totalPriorityGB from billing cycle
    final totalPriorityGB = _parseGb(
      billing?['totalPriorityGB'] ?? billing?['total_priority_gb'],
    );
    final dataplanGb = _parseGb(data?['dataplan']);

    // FIX: Current Monthly Data = dataplan, TopUp = sum of serviceTopUp
    final serviceTopUps = data?['serviceTopUp'] as List?;
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
          data?['usageLimitGB'] ??
          data?['usage_limit_gb'],
    );
    final effectiveLimit = usageLimitGb > 0 ? usageLimitGb : dataplanGb;

    // total = priority + topup (based on user request)
    final totalUsed = totalPriorityGB + topup;

    // FIX 2 — cap bar at 1.0; show red + warning label when over limit
    final progress =
        effectiveLimit > 0 ? (totalUsed / effectiveLimit).clamp(0.0, 1.0) : 0.0;
    final isOverLimit = effectiveLimit > 0 && totalUsed > effectiveLimit;

    final rtm = data?['routerTerminalMap'];
    final hardware =
        (rtm is List && rtm.isNotEmpty)
            ? Map<String, dynamic>.from(rtm.first)
            : (rtm is Map ? Map<String, dynamic>.from(rtm) : null);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
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
                          color: Color(0xFF8A96A3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                       _str(data?['nickname']),
                       style: const TextStyle(
                         fontSize: 15,
                         fontWeight: FontWeight.w700,
                         color: Color(0xFF000000),
                       ),
                      ),                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8A96A3)),
                    ),
                    _StatusBadge(active: active),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const _HDivider(),

          // ── Hardware ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                if (_str(
                      hardware?['starlink_id'] ??
                          hardware?['starlinkId'] ??
                          data?['starlink_id'] ??
                          data?['starlinkId'],
                    ) !=
                    '—') ...[
                  _InfoRow(
                    label: 'Starlink ID',
                    value: _str(
                      hardware?['starlink_id'] ??
                          hardware?['starlinkId'] ??
                          data?['starlink_id'] ??
                          data?['starlinkId'],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_str(
                      hardware?['serial_number'] ??
                          hardware?['serialNumber'] ??
                          data?['serial_number'] ??
                          data?['serialNumber'],
                    ) !=
                    '—') ...[
                  _InfoRow(
                    label: 'Serial Number',
                    value: _str(
                      hardware?['serial_number'] ??
                          hardware?['serialNumber'] ??
                          data?['serial_number'] ??
                          data?['serialNumber'],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_str(
                      hardware?['kit_number'] ??
                          hardware?['kitNumber'] ??
                          data?['kit_number'] ??
                          data?['kitNumber'],
                    ) !=
                    '—')
                  _InfoRow(
                    label: 'Kit Number',
                    value: _str(
                      hardware?['kit_number'] ??
                          hardware?['kitNumber'] ??
                          data?['kit_number'] ??
                          data?['kitNumber'],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const _HDivider(),

          // ── End date ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'End Date',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A96A3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                InkWell(
                  onTap: onDateTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: Color(0xFF8A96A3),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDate(data?['endDate']?.toString()),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF000000),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (onDateTap != null)
                          const Icon(
                            Icons.edit_calendar_outlined,
                            size: 16,
                            color: Color(0xFFEB1E23),
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

          // ── FIX 2: Usage section ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current plan Usage',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF000000),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_gbStr(totalUsed)} / ${_gbStr(effectiveLimit)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        // Red when over the plan limit
                        color:
                            isOverLimit
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF000000),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // Over-limit warning badge
                if (isOverLimit) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: const [
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
                const SizedBox(height: 8),
                // Bar never overflows — clamped to 1.0
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFE8ECF0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOverLimit
                          ? const Color(0xFFEF4444) // red  when exceeded
                          : progress > 0.7
                          ? const Color(0xFFF59E0B) // amber when >70%
                          : const Color(0xFF0F62FE), // blue otherwise
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 14),
                _UsageRow(
                  label: 'Current monthly data',
                  value: _gbStr(dataplanGb),
                ),
                const SizedBox(height: 8),
                _UsageRow(label: 'Top-Up data', value: _gbStr(topup)),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _HDivider(),

          // ── Address ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Address',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A96A3),
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
                        color: Color(0xFF8A96A3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _str(data?['address']),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF000000),
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
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _HDivider(),

          if (billingError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _ErrorCard(message: billingError!),
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
                  // ── Updated Data Usage ──────────────────────────────
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
// Summary Grid
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final double priority;
  final double standard;
  final double optin;
  final double nonBillable;
  final String Function(dynamic) gbStr;

  const _SummaryGrid({
    required this.priority,
    required this.standard,
    required this.optin,
    required this.nonBillable,
    required this.gbStr,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _SummaryItem(
              label: 'Priority',
              value: gbStr(priority),
              color: _accent,
            ),
            const SizedBox(width: 12),
            _SummaryItem(
              label: 'Standard',
              value: gbStr(standard),
              color: _indigo,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _SummaryItem(label: 'Opt-in', value: gbStr(optin), color: _amber),
            const SizedBox(width: 12),
            _SummaryItem(
              label: 'Non-Billable',
              value: gbStr(nonBillable),
              color: _emerald,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
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
                _dialogMetric('Standard', s, _accentBlue, effectiveMax),
                const SizedBox(height: 14),
                _dialogMetric(
                  'Opt-in Priority',
                  o,
                  _amber,
                  effectiveMax,
                ),
                const SizedBox(height: 14),
                _dialogMetric(
                  'Non-Billable',
                  n,
                  _emerald,
                  effectiveMax,
                ),
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8ECF0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: const Color(0xFFF0F4F8));
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF10B981) : const Color(0xFF760F12);
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

class _UsageRow extends StatelessWidget {
  final String label;
  final String value;
  const _UsageRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A5568)),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF000000),
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF8A96A3)),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF000000),
        ),
      ),
    ],
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F0),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEB1E23).withOpacity(0.35)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFEB1E23),
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFEB1E23), fontSize: 12),
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

