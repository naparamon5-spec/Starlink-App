import 'package:flutter/material.dart';
import 'package:starlink_app/shared/widgets/app_dialog.dart';

/// Asks the user to confirm logging out. Returns true only if they confirm.
Future<bool> confirmLogout(BuildContext context) => showAppConfirm(
  context,
  title: 'Log out?',
  message:
      "Are you sure you want to log out?\nYou'll need to sign in again to continue.",
  confirmLabel: 'Log out',
  icon: Icons.logout_rounded,
  tone: AppDialogTone.danger,
);
