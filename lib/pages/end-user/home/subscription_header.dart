import 'package:flutter/material.dart';

class SubscriptionHeader extends StatelessWidget {
  /// The raw subscription object from the API (first item of the list).
  final Map<String, dynamic> subscriptionData;

  /// The first billing cycle object (may be null if none loaded yet).
  final Map<String, dynamic>? billingCycle;

  const SubscriptionHeader({
    super.key,
    required this.subscriptionData,
    this.billingCycle,
  });

  // ── Safe parsers ──────────────────────────────────────────────────────────

  /// Handles "2024-01-15 00:00:00", "2024-01-15T00:00:00Z", "2024-01-15", etc.
  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    try {
      return DateTime.parse(s.contains('T') ? s : s.replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _str(dynamic v, [String fallback = '']) =>
      (v == null || v.toString() == 'null') ? fallback : v.toString().trim();

  // ── Field readers that check multiple key variants ────────────────────────

  String get _serviceLineNumber => _str(
    subscriptionData['serviceLineNumber'] ??
        subscriptionData['service_line_number'] ??
        subscriptionData['sln'],
  );

  String get _nickname => _str(
    subscriptionData['nickname'] ??
        subscriptionData['name'] ??
        subscriptionData['label'],
  );

  String get _address => _str(
    subscriptionData['address'] ??
        subscriptionData['location'] ??
        subscriptionData['site_address'],
  );

  bool get _active {
    final v =
        subscriptionData['active'] ??
        subscriptionData['is_active'] ??
        subscriptionData['status'];
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'active';
  }

  // Billing cycle field readers
  double get _consumed => _parseDouble(
    billingCycle?['consumedAmountGB'] ??
        billingCycle?['consumed_amount_gb'] ??
        billingCycle?['consumed'] ??
        billingCycle?['usage_gb'],
  );

  double get _limit => _parseDouble(
    billingCycle?['usageLimitGB'] ??
        billingCycle?['usage_limit_gb'] ??
        billingCycle?['limit'] ??
        billingCycle?['data_limit_gb'] ??
        100,
  );

  DateTime? get _startDate =>
      _parseDate(billingCycle?['startDate'] ?? billingCycle?['start_date']);

  DateTime? get _endDate =>
      _parseDate(billingCycle?['endDate'] ?? billingCycle?['end_date']);

  // ── Derived values ────────────────────────────────────────────────────────

  double get _usagePercent =>
      _limit > 0 ? (_consumed / _limit).clamp(0.0, 1.0) : 0.0;

  Color _statusColor(bool isActive) =>
      isActive ? const Color(0xFF4CAF50) : const Color(0xFFF44336);

  Color get _usageColor {
    if (_limit <= 0) return const Color(0xFF4CAF50);
    final pct = _consumed / _limit;
    if (pct >= 0.9) return const Color(0xFFF44336);
    if (pct >= 0.7) return const Color(0xFFFFC107);
    return const Color(0xFF4CAF50);
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String get _periodText {
    if (billingCycle == null) return 'No billing data';
    final s = _startDate;
    final e = _endDate;
    if (s == null || e == null) return 'Invalid date range';
    return '${_fmtDate(s)} – ${_fmtDate(e)}';
  }

  @override
  Widget build(BuildContext context) {
    final usageCol = _usageColor;
    final statusCol = _statusColor(_active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Service line + status badge ──────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                _serviceLineNumber.isNotEmpty
                    ? 'SLN: $_serviceLineNumber'
                    : 'No Service Line',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF133343),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusCol.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _active ? 'ACTIVE' : 'INACTIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusCol,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Nickname / name ──────────────────────────────────────────────
        Text(
          _nickname.isNotEmpty
              ? _nickname
              : (_serviceLineNumber.isNotEmpty
                  ? _serviceLineNumber
                  : 'Subscription'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF133343),
          ),
        ),

        // ── Address ──────────────────────────────────────────────────────
        if (_address.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: Color(0xFF666666),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _address,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),

        // ── Billing period title ─────────────────────────────────────────
        const Text(
          'Current Billing Period',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF133343),
          ),
        ),
        const SizedBox(height: 8),

        if (billingCycle == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF133343).withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF666666)),
                SizedBox(width: 8),
                Text(
                  'No billing cycle data available.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF133343).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Period
                _row('Period', _periodText),
                const SizedBox(height: 8),

                // Usage text
                _row(
                  'Usage',
                  '${_consumed.toStringAsFixed(1)} GB'
                      ' / ${_limit.toStringAsFixed(1)} GB',
                  valueColor: usageCol,
                ),
                const SizedBox(height: 10),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _usagePercent,
                    minHeight: 7,
                    backgroundColor: usageCol.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(usageCol),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(_usagePercent * 100).toStringAsFixed(1)}% used',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: usageCol,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Data plan badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Data Plan',
                      style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: usageCol.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _limit > 0
                            ? '${_limit.toStringAsFixed(1)} GB Plan'
                            : 'Unknown Plan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: usageCol,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? const Color(0xFF133343),
            ),
          ),
        ),
      ],
    );
  }
}
