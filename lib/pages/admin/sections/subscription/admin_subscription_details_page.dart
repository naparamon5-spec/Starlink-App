import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';

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

  String? _subscriptionError;
  String? _billingError;

  String? _cycleStart;
  String? _cycleEnd;

  List<_BillingPeriod> _billingPeriods = [];
  _BillingPeriod? _selectedPeriod;

  // ── Brand colors ───────────────────────────────────────────────────────────
  static const _brandRed = Color(0xFFEB1E23);
  static const _brandDark = Color(0xFF760F12);

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

  String _dateOnly(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    if (raw == '0000-00-00') return '—';
    try {
      if (raw.contains('T')) return raw.split('T').first;
      if (raw.contains(' ')) return raw.split(' ').first;
    } catch (_) {}
    return raw;
  }

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
        subErr = res['message']?.toString() ?? 'Subscription fetch failed';
      }
    } catch (e) {
      subErr = e.toString().replaceAll('Exception: ', '');
    }

    String? startDate;
    String? endDate;
    final List<_BillingPeriod> periods = [];

    if (subResult != null) {
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
      if (periods.isEmpty && startDate != null && endDate != null) {
        periods.add(_BillingPeriod(startDate: startDate, endDate: endDate));
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF000000),
              ),
            ),
          ],
        ),
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.refresh_rounded, color: _brandRed),
        //     onPressed: _loading ? null : _load,
        //   ),
        // ],
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
            _SubscriptionCard(data: _subscriptionData),

          const SizedBox(height: 14),

          _BillingCard(
            billingData: _billingData,
            billingError: _billingError,
            cycleStart: _cycleStart,
            cycleEnd: _cycleEnd,
            periods: _billingPeriods,
            selectedPeriod: _selectedPeriod,
            onPeriodChanged: (p) {
              setState(() => _selectedPeriod = p);
              _loadBillingForPeriod(p);
            },
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
  const _SubscriptionCard({required this.data});

  String _str(dynamic v) =>
      (v == null || v.toString() == 'null' || v.toString().isEmpty)
          ? '—'
          : v.toString();

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null' || raw == '0000-00-00') {
      return 'Invalid date';
    }
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
    final consumed = _parseGb(
      data?['consumedAmountGB'] ?? data?['consumed_amount_gb'],
    );
    final usageLimit = _parseGb(
      data?['usageLimitGB'] ?? data?['usage_limit_gb'],
    );
    final monthly = _parseGb(
      data?['totalPriorityGB'] ??
          data?['total_priority_gb'] ??
          data?['currentMonthlyData'],
    );
    final topup = _parseGb(
      data?['totalStandardGB'] ??
          data?['total_standard_gb'] ??
          data?['topUpData'],
    );
    final progress =
        usageLimit > 0 ? (consumed / usageLimit).clamp(0.0, 1.0) : 0.0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      ),
                    ],
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
                Container(
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
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _HDivider(),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
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
                      '${_gbStr(consumed)} / ${_gbStr(usageLimit)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF000000),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFE8ECF0),
                    // Data-viz: red when >90%, amber >70%, blue otherwise (keep as-is)
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress > 0.9
                          ? const Color(0xFFEF4444)
                          : progress > 0.7
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF0F62FE),
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 14),
                _UsageRow(
                  label: 'Current monthly data',
                  value: _gbStr(monthly),
                ),
                const SizedBox(height: 8),
                _UsageRow(label: 'Top-Up data', value: _gbStr(topup)),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _HDivider(),

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
// Billing Card
// ─────────────────────────────────────────────────────────────────────────────

class _BillingCard extends StatelessWidget {
  final Map<String, dynamic>? billingData;
  final String? billingError;
  final String? cycleStart;
  final String? cycleEnd;
  final List<_BillingPeriod> periods;
  final _BillingPeriod? selectedPeriod;
  final ValueChanged<_BillingPeriod> onPeriodChanged;

  const _BillingCard({
    required this.billingData,
    required this.billingError,
    required this.cycleStart,
    required this.cycleEnd,
    required this.periods,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  double _parseGb(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  String _gbStr(dynamic v) {
    final d = _parseGb(v);
    return d == 0 ? '0 GB' : '${d.toStringAsFixed(2)} GB';
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
      return '${months[s.month - 1]} ${s.year} – ${months[e.month - 1]} ${e.year}';
    } catch (_) {
      return '${p.startDate} – ${p.endDate}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final consumed = _parseGb(billingData?['consumedAmountGB']);
    final limit = _parseGb(billingData?['usageLimitGB']);
    final priority = _parseGb(billingData?['totalPriorityGB']);
    final standard = _parseGb(billingData?['totalStandardGB']);
    final overage = _parseGb(billingData?['overageGB']);
    final progress =
        limit > 0
            ? (consumed / limit).clamp(0.0, 1.0)
            : (consumed > 0 ? 1.0 : 0.0);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select billing period:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A96A3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (periods.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'No billing periods available',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8A96A3)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_BillingPeriod>(
                        value: selectedPeriod,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF8A96A3),
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF000000),
                          fontWeight: FontWeight.w500,
                        ),
                        items:
                            periods
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(_periodLabel(p)),
                                  ),
                                )
                                .toList(),
                        onChanged: (p) {
                          if (p != null) onPeriodChanged(p);
                        },
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
            Padding(
              padding: const EdgeInsets.all(36),
              child: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFFEB1E23),
                  strokeWidth: 2.5,
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Updated Data Usage',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A96A3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _gbStr(consumed),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF000000),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFFE8ECF0),
                      // Data-viz: keep color gradient for usage level
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.9
                            ? const Color(0xFFEF4444)
                            : progress > 0.7
                            ? const Color(0xFFF59E0B)
                            : const Color(
                              0xFFFC9FA5,
                            ), // light brand red for healthy usage
                      ),
                      minHeight: 48,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}% used',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A96A3),
                        ),
                      ),
                      if (limit > 0)
                        Text(
                          '${_gbStr(limit - consumed)} remaining',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A96A3),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const _HDivider(),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'Priority Data',
                          value: _gbStr(priority),
                          color: const Color(
                            0xFF0F62FE,
                          ), // blue = data category
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          label: 'Standard Data',
                          value: _gbStr(standard),
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'Usage Limit',
                          value: _gbStr(limit),
                          color: const Color(0xFF8A96A3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          label: 'Overage',
                          value: _gbStr(overage),
                          color:
                              overage > 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
  Widget build(BuildContext context) {
    return Row(
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
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF000000),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
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
