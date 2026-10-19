import 'package:flutter/material.dart';

/// Asks the user to confirm logging out. Returns true only if they confirm.
Future<bool> confirmLogout(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Log out?'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEB1E23),
              ),
              child: const Text('Log out'),
            ),
          ],
        ),
  );
  return result ?? false;
}
