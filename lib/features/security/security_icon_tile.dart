import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';

/// The icon block used across Settings, in the app's navy.
class SecurityIconTile extends StatelessWidget {
  const SecurityIconTile(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: AppColors.navy.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: AppColors.navy, size: 20),
  );
}
