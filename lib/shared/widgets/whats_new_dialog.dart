import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/notifications.dart';

/// "What's new" after sign-in (web portal's WhatsNewModal): the
/// announcements this user hasn't seen yet. However it's closed, the ones
/// shown are marked as seen (POST /announcements/read) so it doesn't pop up
/// again. Shown at most once per app run.
class WhatsNew {
  WhatsNew._();

  static bool _shownThisRun = false;

  static Future<void> maybeShow(BuildContext context) async {
    if (_shownThisRun) return;
    _shownThisRun = true;
    final res = await ApiService.getAnnouncementFeed();
    if (!context.mounted || res['status'] != 'success') return;
    final data = res['data'];
    if (data is! List) return;
    final unread =
        data
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .where((a) => a['read'] != true)
            .toList();
    if (unread.isEmpty) return;

    final openAll = await showDialog<bool>(
      context: context,
      builder: (ctx) => _WhatsNewDialog(items: unread),
    );
    final ids = [
      for (final a in unread)
        if (int.tryParse('${a['id']}') != null) int.parse('${a['id']}'),
    ];
    // Not critical if it fails: it simply shows again next time.
    ApiService.markAnnouncementsRead(ids);
    if (openAll == true && context.mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    }
  }

  /// Lets the next sign-in in this run show the dialog again.
  static void reset() => _shownThisRun = false;
}

class _WhatsNewDialog extends StatelessWidget {
  const _WhatsNewDialog({required this.items});
  final List<Map<String, dynamic>> items;

  static const _categories = {
    'feature': ('New feature', AppColors.brand),
    'improvement': ('Improvement', AppColors.info),
    'maintenance': ('Maintenance', AppColors.warning),
    'notice': ('Notice', AppColors.navy),
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("What's new"),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (_, i) {
              final a = items[i];
              final cat =
                  _categories[a['category']] ?? ('Notice', AppColors.navy);
              final date = DateTime.tryParse(
                '${a['starts_at'] ?? a['created_at'] ?? ''}',
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cat.$2.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cat.$1.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: cat.$2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (date != null)
                        Text(
                          DateFormat('MMM d, yyyy').format(date.toLocal()),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkFaint,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${a['title'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    // Markdown on the web; show it as plain text here.
                    '${a['body'] ?? ''}'
                        .replaceAll(RegExp(r'[*_`#>]+'), '')
                        .trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                      height: 1.45,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('View notifications'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
