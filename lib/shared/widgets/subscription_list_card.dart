import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/status_labels.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// One row of the web portal's Subscriptions table, stacked for a phone:
/// subscription, plan usage, customer, service location, status and end date.
class SubscriptionListCard extends StatelessWidget {
  const SubscriptionListCard({
    super.key,
    required this.sub,
    this.searchQuery = '',
    this.onTap,
  });

  /// A row from `GET /subscriptions/paginated`.
  final Map<String, dynamic> sub;
  final String searchQuery;
  final VoidCallback? onTap;

  String _text(String key) {
    final t = sub[key]?.toString().trim() ?? '';
    return t == 'null' ? '' : t;
  }

  Widget _status() {
    final label = subscriptionStatusLabel(sub['active']);
    return DotBadge(
      label,
      color: label == 'ACTIVE' ? AppColors.info : AppColors.inkMuted,
    );
  }

  String get _endDate {
    final t = _text('endDate');
    if (t.isEmpty || t.startsWith('0000')) return '—';
    final d = DateTime.tryParse(t.split(RegExp('[T ]')).first);
    return d == null ? t : DateFormat('MMM dd, y').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final sln = _text('serviceLineNumber');
    final nickname = _text('nickname');
    final kit = _text('kit_number');
    final company = _text('company_name');
    final endUser = _text('end_user_name');
    final address = _text('address');
    final query = searchQuery.trim();

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: HighlightedText(
                      nickname.isNotEmpty ? nickname : sln,
                      query: query,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _status(),
                ],
              ),
              const SizedBox(height: 4),
              if (nickname.isNotEmpty && sln.isNotEmpty)
                HighlightedText(
                  sln,
                  query: query,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              if (kit.isNotEmpty) ...[
                const SizedBox(height: 1),
                HighlightedText(
                  kit,
                  query: query,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _PlanUsage(
                used: num.tryParse(_text('totalPriorityGB')) ?? 0,
                plan: num.tryParse(_text('dataplan')) ?? 0,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (company.isNotEmpty || endUser.isNotEmpty) ...[
                _DetailRow(
                  icon: Icons.business_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (company.isNotEmpty)
                        HighlightedText(
                          company,
                          query: query,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: AppColors.ink,
                          ),
                        ),
                      if (endUser.isNotEmpty)
                        HighlightedText(
                          endUser,
                          query: query,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: AppColors.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
              ],
              if (address.isNotEmpty) ...[
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  child: HighlightedText(
                    address,
                    query: query,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
              ],
              _DetailRow(
                icon: Icons.event_outlined,
                child: Text(
                  'Ends $_endDate',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Priority data used against the plan's data, as the web table shows it.
class _PlanUsage extends StatelessWidget {
  const _PlanUsage({required this.used, required this.plan});
  final num used;
  final num plan;

  @override
  Widget build(BuildContext context) {
    final hasPlan = plan > 0;
    final pct = hasPlan ? used / plan * 100 : 0.0;
    final over = hasPlan && used > plan;
    final accent =
        pct >= 90
            ? AppColors.brand
            : pct >= 75
            ? AppColors.warning
            : AppColors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${NumberFormat('#,##0.00').format(used)} GB',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: over ? AppColors.warning : AppColors.ink,
                ),
              ),
              TextSpan(
                text:
                    hasPlan
                        ? '  of ${NumberFormat('#,##0.##').format(plan)} GB'
                        : '  of —',
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        if (hasPlan) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.paperMuted,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: AppColors.inkFaint),
      const SizedBox(width: 8),
      Expanded(child: child),
    ],
  );
}
