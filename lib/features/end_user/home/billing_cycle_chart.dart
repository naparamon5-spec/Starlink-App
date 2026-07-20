import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class BillingCycleChart extends StatelessWidget {
  final List<Map<String, dynamic>> billingCycles;

  const BillingCycleChart({super.key, required this.billingCycles});

  // ── Safe parsers ──────────────────────────────────────────────────────────

  /// Handles "2024-01-15 00:00:00", "2024-01-15T00:00:00Z", "2024-01-15"
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

  // ── Field readers with key fallbacks ─────────────────────────────────────

  double _consumed(Map<String, dynamic> c) => _parseDouble(
    c['consumedAmountGB'] ??
        c['consumed_amount_gb'] ??
        c['consumed'] ??
        c['usage_gb'],
  );

  double _limit(Map<String, dynamic> c) => _parseDouble(
    c['usageLimitGB'] ??
        c['usage_limit_gb'] ??
        c['limit'] ??
        c['data_limit_gb'] ??
        100,
  );

  DateTime? _start(Map<String, dynamic> c) =>
      _parseDate(c['startDate'] ?? c['start_date']);

  DateTime? _end(Map<String, dynamic> c) =>
      _parseDate(c['endDate'] ?? c['end_date']);

  // ── Chart helpers ─────────────────────────────────────────────────────────

  double _maxY() {
    if (billingCycles.isEmpty) return 100;
    final m = billingCycles
        .map((c) => _limit(c))
        .reduce((a, b) => a > b ? a : b);
    return m <= 0 ? 100 : m.ceilToDouble();
  }

  Color _usageColor(double consumed, double limit) {
    if (limit <= 0) return const Color(0xFF4CAF50);
    final pct = consumed / limit;
    if (pct >= 0.9) return const Color(0xFFF44336);
    if (pct >= 0.7) return const Color(0xFFFFC107);
    return const Color(0xFF4CAF50);
  }

  List<BarChartGroupData> _barGroups() {
    return List.generate(billingCycles.length, (i) {
      final c = billingCycles[i];
      final usage = _consumed(c);
      final lim = _limit(c);
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: usage,
            color: _usageColor(usage, lim),
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          BarChartRodData(
            toY: lim,
            color: const Color(0xFF133343),
            width: 2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (billingCycles.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 20, color: Color(0xFFA8A8A8)),
            SizedBox(width: 8),
            Text(
              'No billing history available.',
              style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ],
        ),
      );
    }

    final maxY = _maxY();
    final interval = maxY / 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Data Usage History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF133343),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF133343).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${billingCycles.length} '
                'Month${billingCycles.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF133343),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Monthly data consumption breakdown',
          style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
        ),
        const SizedBox(height: 18),

        // ── Bar chart ────────────────────────────────────────────────────
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  // Use tooltipColor (fl_chart ≥ 0.66) with
                  // tooltipBgColor as compile-time fallback for older versions.
                  // If your version uses tooltipBgColor, swap the name below.
                  // tooltipColor: const Color(0xFF133343),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  tooltipMargin: 6,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex >= billingCycles.length) return null;
                    final c = billingCycles[groupIndex];
                    final s = _start(c);
                    final e = _end(c);
                    final usage = _consumed(c);
                    final lim = _limit(c);
                    final pct =
                        lim > 0 ? (usage / lim * 100).toStringAsFixed(1) : '—';
                    final sLabel = s != null ? '${s.day}/${s.month}' : '—';
                    final eLabel = e != null ? '${e.day}/${e.month}' : '—';
                    return BarTooltipItem(
                      '$sLabel – $eLabel\n\n'
                      'Usage : ${usage.toStringAsFixed(1)} GB\n'
                      'Limit : ${lim.toStringAsFixed(1)} GB\n'
                      'Used  : $pct%',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= billingCycles.length) {
                        return const SizedBox.shrink();
                      }
                      final dt = _start(billingCycles[idx]);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          dt != null ? '${dt.month}/${dt.year}' : '—',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        '${value.toInt()} GB',
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF133343).withOpacity(0.08),
                    width: 0.5,
                  ),
                  left: BorderSide(
                    color: const Color(0xFF133343).withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine:
                    (_) => FlLine(
                      color: const Color(0xFF133343).withOpacity(0.08),
                      strokeWidth: 0.5,
                    ),
              ),
              barGroups: _barGroups(),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Legend ───────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend('Usage', const Color(0xFF4CAF50)),
            const SizedBox(width: 12),
            _legend('Limit', const Color(0xFF133343)),
          ],
        ),
      ],
    );
  }

  Widget _legend(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
