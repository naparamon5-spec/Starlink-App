import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/auth/change_password.dart';
import 'package:starlink_app/features/auth/two_factor/two_factor_settings_card.dart';
import 'package:starlink_app/features/security/biometric_settings_card.dart';
import 'package:starlink_app/features/security/security_icon_tile.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// Change password, two-factor and biometric unlock in one place.
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperSubtle,
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const SectionHeading('Password'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                horizontalTitleGap: 14,
                leading: const SecurityIconTile(Icons.lock_outline_rounded),
                title: const Text(
                  'Change password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.inkFaint,
                ),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminChangePasswordPage(),
                      ),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeading('Two-factor authentication'),
          const AppCard(child: TwoFactorSettingsCard()),
          const SizedBox(height: 20),
          const SectionHeading('Biometrics'),
          const AppCard(child: BiometricSettingsCard()),
        ],
      ),
    );
  }
}
