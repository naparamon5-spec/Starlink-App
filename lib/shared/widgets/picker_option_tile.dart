import 'package:flutter/material.dart';

const _primary = Color(0xFF133341);

/// Picks an icon that fits a picker option's label.
IconData pickerOptionIcon(String label) {
  final l = label.toLowerCase();
  if (l.contains('ssid') || l.contains('password')) {
    return Icons.wifi_password_rounded;
  }
  if (l.contains('connection')) return Icons.wifi_rounded;
  if (l.contains('billing')) return Icons.receipt_long_rounded;
  if (l.contains('device') || l.contains('router') || l.contains('kit')) {
    return Icons.router_rounded;
  }
  if (l.contains('top') && l.contains('up')) return Icons.data_usage_rounded;
  if (l.contains('admin')) return Icons.admin_panel_settings_outlined;
  if (l.contains('agent') || l.contains('customer')) {
    return Icons.storefront_outlined;
  }
  if (l.contains('end user') || l.contains('end_user')) {
    return Icons.person_outline_rounded;
  }
  if (l.contains('biller')) return Icons.account_balance_wallet_outlined;
  if (l.contains('account')) return Icons.person_add_alt_1_rounded;
  if (l.contains('request')) return Icons.assignment_outlined;
  return Icons.label_outline_rounded;
}

/// Card-style row used inside selection bottom sheets.
class PickerOptionTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final IconData? trailingIcon;
  final VoidCallback onTap;

  const PickerOptionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  selected
                      ? _primary.withOpacity(0.06)
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    selected
                        ? _primary.withOpacity(0.5)
                        : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? _primary : _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected ? Colors.white : _primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? _primary : const Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : (trailingIcon ?? Icons.chevron_right_rounded),
                  color:
                      selected || trailingIcon != null
                          ? _primary
                          : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
