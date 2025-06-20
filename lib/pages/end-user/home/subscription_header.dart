import 'package:flutter/material.dart';

class SubscriptionHeader extends StatelessWidget {
  final String serviceLineNumber;
  final String nickname;
  final String address;
  final bool active;
  final Map<String, dynamic>? currentBillingCycle;

  const SubscriptionHeader({
    super.key,
    required this.serviceLineNumber,
    required this.nickname,
    required this.address,
    required this.active,
    this.currentBillingCycle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Line Number and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Service Line: $serviceLineNumber',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF133343),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(active).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  active ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(active),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nickname
          Text(
            nickname,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF133343),
            ),
          ),
          const SizedBox(height: 8),

          // Address
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Color(0xFF666666),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Current Billing Cycle
          const Text(
            'Current Billing Period',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF133343),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF133343).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Period',
                      style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                    ),
                    Text(
                      _getBillingPeriodText(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF133343),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Usage',
                      style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                    ),
                    Text(
                      _getUsageText(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _getUsageColor(
                          _parseDouble(
                            currentBillingCycle?['consumedAmountGB'] ?? 0,
                          ),
                          _parseDouble(
                            currentBillingCycle?['usageLimitGB'] ?? 100,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getUsageColor(
                          _parseDouble(
                            currentBillingCycle?['consumedAmountGB'] ?? 0,
                          ),
                          _parseDouble(
                            currentBillingCycle?['usageLimitGB'] ?? 100,
                          ),
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getDataPlanText(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _getUsageColor(
                            _parseDouble(
                              currentBillingCycle?['consumedAmountGB'] ?? 0,
                            ),
                            _parseDouble(
                              currentBillingCycle?['usageLimitGB'] ?? 100,
                            ),
                          ),
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

  String _getBillingPeriodText() {
    if (currentBillingCycle == null) {
      return 'No billing data available';
    }

    try {
      final startDate = DateTime.parse(currentBillingCycle!['startDate']);
      final endDate = DateTime.parse(currentBillingCycle!['endDate']);
      return '${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}';
    } catch (e) {
      print('Error parsing dates: $e');
      return 'Invalid date format';
    }
  }

  String _getUsageText() {
    if (currentBillingCycle == null) {
      return 'No usage data available';
    }

    try {
      final consumed = _parseDouble(currentBillingCycle!['consumedAmountGB']);
      final limit = _parseDouble(currentBillingCycle!['usageLimitGB']);
      return '${consumed.toStringAsFixed(1)} GB / ${limit.toStringAsFixed(1)} GB';
    } catch (e) {
      print('Error formatting usage: $e');
      return 'Invalid usage data';
    }
  }

  String _getDataPlanText() {
    if (currentBillingCycle == null) {
      return 'No plan data';
    }

    try {
      final limit = _parseDouble(currentBillingCycle!['usageLimitGB']);
      return '${limit.toStringAsFixed(1)} GB Plan';
    } catch (e) {
      print('Error formatting data plan: $e');
      return 'Invalid plan data';
    }
  }

  Color _getStatusColor(bool active) {
    return active ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
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
