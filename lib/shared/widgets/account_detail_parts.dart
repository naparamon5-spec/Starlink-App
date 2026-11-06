import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// Pieces shared by the customer and end user detail screens.

String accountText(dynamic v) {
  final t = v?.toString().trim() ?? '';
  return t == 'null' ? '' : t;
}

String accountInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (name.trim().isEmpty) return '?';
  final first = parts.first[0];
  return (parts.length > 1 ? '$first${parts.last[0]}' : first).toUpperCase();
}

/// Underlined tabs with a count on each.
class AccountTabs extends StatelessWidget {
  const AccountTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<(String, int)> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < tabs.length; i++)
        Expanded(
          flex: tabs[i].$1.length > 10 ? 5 : 4,
          child: InkWell(
            onTap: () => onSelected(i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected == i ? AppColors.brand : AppColors.line,
                    width: selected == i ? 2 : 1,
                  ),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[i].$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            selected == i ? AppColors.navy : AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected == i
                                ? AppColors.brand.withValues(alpha: 0.1)
                                : AppColors.paperMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${tabs[i].$2}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color:
                              selected == i
                                  ? AppColors.brand
                                  : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class AccountRowCard extends StatelessWidget {
  const AccountRowCard({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.paper,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      ),
    ),
  );
}

class AccountDetailRow extends StatelessWidget {
  const AccountDetailRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 92,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
        ),
      ),
    ],
  );
}

class AccountEmptyCard extends StatelessWidget {
  const AccountEmptyCard(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
      ),
    ),
  );
}

/// A portal account: avatar, name, status, email, role and position.
class AccountUserCard extends StatelessWidget {
  const AccountUserCard({super.key, required this.user, this.onTap});
  final Map<String, dynamic> user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final full =
        '${accountText(user['first_name'])} ${accountText(user['last_name'])}'
            .trim();
    final name =
        accountText(user['name']).isNotEmpty ? accountText(user['name']) : full;
    final email = accountText(user['email']);
    final role = accountText(user['role']).replaceAll('_', ' ');
    final position = accountText(user['position']);
    final active = accountText(user['inactive']) == 'N';
    return AccountRowCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.navy,
            child: Text(
              accountInitials(name),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name.isEmpty ? '—' : name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DotBadge(
                      active ? 'ACTIVE' : 'INACTIVE',
                      color: active ? AppColors.successInk : AppColors.inkMuted,
                    ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
                if (role.isNotEmpty || position.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (role.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${role[0].toUpperCase()}${role.substring(1)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      if (position.isNotEmpty)
                        Text(
                          position,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkFaint,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
