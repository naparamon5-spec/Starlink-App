import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class BillingCycleChart extends StatelessWidget {
  final List<Map<String, dynamic>> billingCycles;

  const BillingCycleChart({super.key, required this.billingCycles});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF133343).withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Data Usage History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF133343),
                  height: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF133343).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${billingCycles.length} Months',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF133343),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Monthly data consumption breakdown',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxUsage(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: const Color(0xFF133343),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tooltipMargin: 6,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final cycle = billingCycles[groupIndex];
                      final startDate = DateTime.parse(cycle['startDate']);
                      final endDate = DateTime.parse(cycle['endDate']);
                      final consumed = _parseDouble(cycle['consumedAmountGB']);
                      final limit = _parseDouble(cycle['usageLimitGB']);
                      final percentage = (consumed / limit * 100)
                          .toStringAsFixed(1);

                      return BarTooltipItem(
                        '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}\n\n'
                        'Total Usage: ${consumed.toStringAsFixed(1)} GB\n'
                        'Limit: ${limit.toStringAsFixed(1)} GB\n'
                        'Usage: $percentage%',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          height: 1.4,
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
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < billingCycles.length) {
                          final cycle = billingCycles[value.toInt()];
                          final startDate = DateTime.parse(cycle['startDate']);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${startDate.month}/${startDate.year}',
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()} GB',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
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
                  horizontalInterval:
                      _getMaxUsage() > 0 ? _getMaxUsage() / 5 : 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFF133343).withOpacity(0.08),
                      strokeWidth: 0.5,
                    );
                  },
                ),
                barGroups: _createBarGroups(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Usage', const Color(0xFF4CAF50)),
              const SizedBox(width: 12),
              _buildLegendItem('Limit', const Color(0xFF133343)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
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

  double _getMaxUsage() {
    if (billingCycles.isEmpty) return 100;
    return billingCycles
        .map((cycle) => _parseDouble(cycle['usageLimitGB']))
        .reduce((a, b) => a > b ? a : b)
        .ceilToDouble();
  }

  List<BarChartGroupData> _createBarGroups() {
    return List.generate(billingCycles.length, (index) {
      final cycle = billingCycles[index];
      final usage = _parseDouble(cycle['consumedAmountGB']);
      final limit = _parseDouble(cycle['usageLimitGB']);

      return BarChartGroupData(
        x: index,
        barRods: [
          // Usage Bar
          BarChartRodData(
            toY: usage,
            color: _getUsageColor(usage, limit),
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          // Limit Line
          BarChartRodData(
            toY: limit,
            color: const Color(0xFF133343),
            width: 2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      );
    });
  }

  Color _getUsageColor(double consumed, double limit) {
    final percentage = consumed / limit;
    if (percentage >= 0.9) {
      return const Color(0xFFF44336); // Red for high usage
    } else if (percentage >= 0.7) {
      return const Color(0xFFFFC107); // Yellow for medium usage
    }
    return const Color(0xFF4CAF50); // Green for low usage
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
