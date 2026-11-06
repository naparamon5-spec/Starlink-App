import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';

/// The password rules with whether each passes, same as the web portal's.
List<(String, bool)> passwordRuleResults(String password, String confirm) => [
  ('At least 8 characters', password.length >= 8),
  ('One uppercase letter', RegExp(r'[A-Z]').hasMatch(password)),
  ('One lowercase letter', RegExp(r'[a-z]').hasMatch(password)),
  ('One number', RegExp(r'[0-9]').hasMatch(password)),
  ('One special character', RegExp(r'[^A-Za-z0-9]').hasMatch(password)),
  ('Passwords match', password.isNotEmpty && password == confirm),
];

bool passwordMeetsRules(String password, String confirm) =>
    passwordRuleResults(password, confirm).every((r) => r.$2);

/// Live list of the password rules, ticked as they're met.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({
    super.key,
    required this.password,
    required this.confirm,
  });

  final String password;
  final String confirm;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final rule in passwordRuleResults(password, confirm))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color:
                      rule.$2
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.paperMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  rule.$2 ? Icons.check_rounded : Icons.close_rounded,
                  size: 12,
                  color: rule.$2 ? AppColors.successInk : AppColors.inkFaint,
                  semanticLabel: rule.$2 ? 'Met' : 'Not met',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rule.$1,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: rule.$2 ? AppColors.successInk : AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
