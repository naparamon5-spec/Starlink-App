import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// One row of the web portal's Tickets table, stacked for a phone: ticket
/// number, status, subject, description, type, created by and age.
class TicketListCard extends StatelessWidget {
  const TicketListCard({
    super.key,
    required this.id,
    required this.subject,
    required this.status,
    this.description = '',
    this.type = '',
    this.createdBy = '',
    this.createdAt,
    this.searchQuery = '',
    this.onTap,
  });

  final String id;
  final String subject;
  final String status;
  final String description;
  final String type;
  final String createdBy;

  /// Raw `created_at` from the API.
  final String? createdAt;
  final String searchQuery;
  final VoidCallback? onTap;

  /// Same wording as the web portal's timeAgo().
  static String timeAgo(String? raw, {DateTime? now}) {
    final d = DateTime.tryParse(raw?.trim() ?? '');
    if (d == null) return '—';
    final mins = ((now ?? DateTime.now()).difference(d).inSeconds / 60).round();
    if (mins < 1) return 'just now';
    if (mins < 60) return '${mins}m ago';
    final hours = (mins / 60).round();
    if (hours < 24) return '${hours}h ago';
    final days = (hours / 24).round();
    if (days < 30) return '${days}d ago';
    return DateFormat('MMM dd, y').format(d.toLocal());
  }

  static bool _shown(String v) {
    final t = v.trim();
    return t.isNotEmpty &&
        !const ['null', 'N/A', '—', 'No description'].contains(t);
  }

  @override
  Widget build(BuildContext context) {
    final label = status.replaceAll('_', ' ').trim().toUpperCase();
    final color = switch (label) {
      'OPEN' || 'IN PROGRESS' => AppColors.info,
      'RESOLVED' => AppColors.success,
      _ => AppColors.inkMuted,
    };
    final query = searchQuery.trim();
    const meta = TextStyle(fontSize: 12, color: AppColors.inkMuted);

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
                children: [
                  Expanded(
                    child: HighlightedText(
                      '#$id',
                      query: query,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DotBadge(label, color: color),
                ],
              ),
              const SizedBox(height: 8),
              HighlightedText(
                _shown(subject) ? subject : 'No subject',
                query: query,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppColors.ink,
                ),
              ),
              if (_shown(description)) ...[
                const SizedBox(height: 3),
                HighlightedText(
                  description,
                  query: query,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (_shown(type)) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.sell_outlined,
                      size: 14,
                      color: AppColors.inkFaint,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: HighlightedText(
                        type,
                        query: query,
                        maxLines: 1,
                        style: meta,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: AppColors.inkFaint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: HighlightedText(
                      _shown(createdBy) ? createdBy : '—',
                      query: query,
                      maxLines: 1,
                      style: meta,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    timeAgo(createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
