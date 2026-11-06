import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/admin/sections/subscription/admin_subscription_details_page.dart';
import 'package:starlink_app/features/admin/sections/ticket/admin_ticket_details_page.dart';
import 'package:starlink_app/features/admin/tools/announcements_admin_page.dart';
import 'package:starlink_app/shared/widgets/account_detail_parts.dart';
import 'package:starlink_app/shared/widgets/ticket_list_card.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// How many recent tickets and subscriptions the dashboard shows.
const dashboardListSize = 3;

DateTime? _endDateOf(Map<String, dynamic> s) =>
    DateTime.tryParse(accountText(s['endDate'] ?? s['end_date']));

/// Whole days until [end], rounded up; negative once it has passed.
int? daysUntil(DateTime? end, {DateTime? now}) {
  if (end == null) return null;
  final ms = end.difference(now ?? DateTime.now()).inMilliseconds;
  return (ms / Duration.millisecondsPerDay).ceil();
}

/// Upcoming end dates first (soonest on top), then lapsed ones (most recently
/// lapsed first), like the web portal.
List<Map<String, dynamic>> sortExpiring(
  List<Map<String, dynamic>> rows, {
  DateTime? now,
}) {
  int? days(Map<String, dynamic> s) => daysUntil(_endDateOf(s), now: now);
  final upcoming =
      rows.where((s) => (days(s) ?? -1) >= 0).toList()
        ..sort((a, b) => days(a)!.compareTo(days(b)!));
  final lapsed =
      rows.where((s) => (days(s) ?? -1) < 0).toList()..sort((a, b) {
        final x = days(a), y = days(b);
        if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
        return y.compareTo(x);
      });
  return [...upcoming, ...lapsed];
}

/// Pinned announcements plus the latest 3.
List<Map<String, dynamic>> dashboardAnnouncements(
  List<Map<String, dynamic>> feed,
) => [
  ...feed.where((a) => a['pinned'] == true),
  ...feed.where((a) => a['pinned'] != true).take(3),
];

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({
    super.key,
    required this.loading,
    required this.firstName,
    required this.open,
    required this.inProgress,
    required this.resolved,
    required this.closed,
    required this.announcements,
    required this.recent,
    required this.expiring,
    required this.onViewTickets,
    this.error,
  });

  final bool loading;
  final String firstName;
  final int open;
  final int inProgress;
  final int resolved;
  final int closed;
  final List<Map<String, dynamic>> announcements;
  final List<Map<String, dynamic>> recent;
  final List<Map<String, dynamic>> expiring;
  final VoidCallback onViewTickets;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final shown = dashboardAnnouncements(announcements);
    final sorted = sortExpiring(expiring);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstName.isEmpty ? 'Good day' : 'Good day, $firstName',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          "Here's what's happening across your Starlink services.",
          style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: const TextStyle(fontSize: 12.5, color: AppColors.dangerInk),
          ),
        ],
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(
            icon: Icons.campaign_outlined,
            title: 'Announcements',
            action: 'View all',
            onAction:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AnnouncementsAdminPage(),
                  ),
                ),
          ),
          const SizedBox(height: 8),
          FadingHScroll(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    SizedBox(
                      width: math.min(
                        280,
                        MediaQuery.sizeOf(context).width - 56,
                      ),
                      child: AnnouncementCard(
                        announcement: shown[i],
                        compact: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _StatGrid(
          loading: loading,
          stats: [
            (
              'Open',
              open,
              AppColors.info,
              Icons.inbox_outlined,
              AppColors.info,
            ),
            (
              'In Progress',
              inProgress,
              AppColors.warning,
              Icons.autorenew_rounded,
              AppColors.warningInk,
            ),
            (
              'Resolved',
              resolved,
              AppColors.success,
              Icons.check_circle_outline_rounded,
              AppColors.successInk,
            ),
            (
              'Closed',
              closed,
              AppColors.navy,
              Icons.inventory_2_outlined,
              AppColors.navy,
            ),
          ],
          onTap: onViewTickets,
        ),
        const SizedBox(height: 18),
        _RecentActivity(
          loading: loading,
          rows: recent.take(dashboardListSize).toList(),
          onViewAll: onViewTickets,
        ),
        if (sorted.isNotEmpty) ...[
          const SizedBox(height: 18),
          _ExpiringCard(rows: sorted),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.icon,
    this.iconColor = AppColors.navy,
    this.count,
    this.action,
    this.onAction,
  });
  final String title;
  final IconData? icon;
  final Color iconColor;
  final int? count;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
      ],
      Expanded(
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  NumberFormat('#,##0').format(count),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningInk,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      if (action != null)
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
          ),
        ),
    ],
  );
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.loading,
    required this.stats,
    required this.onTap,
  });
  final bool loading;
  final List<(String, int, Color, IconData, Color)> stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var row = 0; row < stats.length; row += 2) ...[
        if (row > 0) const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _tile(stats[row])),
              const SizedBox(width: 10),
              Expanded(child: _tile(stats[row + 1])),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _tile((String, int, Color, IconData, Color) s) => Material(
    color: AppColors.paper,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: s.$3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: s.$3.withValues(alpha: 0.12),
                    child: Icon(s.$4, size: 18, color: s.$5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            s.$1.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            loading ? '—' : NumberFormat('#,##0').format(s.$2),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.loading,
    required this.rows,
    required this.onViewAll,
  });
  final bool loading;
  final List<Map<String, dynamic>> rows;
  final VoidCallback onViewAll;

  Color _statusColor(String label) => switch (label) {
    'OPEN' || 'IN PROGRESS' => AppColors.info,
    'RESOLVED' => AppColors.successInk,
    _ => AppColors.inkMuted,
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        title: 'Recent activity',
        action: 'View all',
        onAction: onViewAll,
      ),
      const SizedBox(height: 8),
      if (loading)
        const AccountEmptyCard('Loading…')
      else if (rows.isEmpty)
        const AccountEmptyCard('No recent tickets.')
      else
        for (final t in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ticketRow(context, t),
          ),
    ],
  );

  Widget _ticketRow(BuildContext context, Map<String, dynamic> t) {
    final id = accountText(t['id'] ?? t['ticket_id']);
    final subject = accountText(t['subject']);
    final type = accountText(t['ticket_type'] ?? t['type']);
    final status = accountText(t['status']).replaceAll('_', ' ').toUpperCase();
    final age = TicketListCard.timeAgo(
      accountText(t['updated_at'] ?? t['created_at']),
    );
    return AccountRowCard(
      onTap:
          id.isEmpty
              ? null
              : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => AdminTicketDetailsPage(
                        ticketId: id,
                        subject: subject,
                      ),
                ),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#$id',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (status.isNotEmpty)
                DotBadge(status, color: _statusColor(status)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            subject.isEmpty ? 'No subject' : subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.3,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                age,
                style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpiringRow extends StatelessWidget {
  const _ExpiringRow({required this.sub});
  final Map<String, dynamic> sub;

  @override
  Widget build(BuildContext context) {
    final sln = accountText(sub['serviceLineNumber']);
    final nickname = accountText(sub['nickname']);
    final end = _endDateOf(sub);
    final days = daysUntil(end);
    final label =
        days == null
            ? 'No date'
            : days < 0
            ? 'Expired'
            : '$days day${days == 1 ? '' : 's'}';
    final color =
        days != null && days > 3 ? AppColors.warningInk : AppColors.dangerInk;
    return AccountRowCard(
      onTap:
          sln.isEmpty
              ? null
              : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => AdminSubscriptionDetailsPage(
                        serviceLineNumber: sln,
                        title: nickname.isEmpty ? sln : nickname,
                      ),
                ),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  nickname.isEmpty ? sln : nickname,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            sln,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
          if (end != null) ...[
            const SizedBox(height: 2),
            Text(
              'Ends ${DateFormat('MMM dd, y').format(end.toLocal())}',
              style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpiringCard extends StatelessWidget {
  const _ExpiringCard({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final top = rows.take(dashboardListSize).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Subscription end dates',
          icon: Icons.schedule_rounded,
          iconColor: AppColors.warningInk,
          count: rows.length,
          action: rows.length > top.length ? 'View all' : null,
          onAction:
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => _AllExpiringPage(rows: rows)),
              ),
        ),
        const Text(
          'Ending within 7 days or already lapsed',
          style: TextStyle(fontSize: 12, color: AppColors.inkFaint),
        ),
        const SizedBox(height: 8),
        for (final s in top)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ExpiringRow(sub: s),
          ),
      ],
    );
  }
}

class _AllExpiringPage extends StatelessWidget {
  const _AllExpiringPage({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.paperSubtle,
    appBar: AppBar(title: const Text('Subscription end dates')),
    body: ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: rows.length,
      itemBuilder:
          (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ExpiringRow(sub: rows[i]),
          ),
    ),
  );
}
