import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:flutter/material.dart';

/// Asks for the remarks the backend requires to resolve a ticket.
/// Returns null if the user cancels.
Future<String?> askResolveRemarks(BuildContext context) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setLocal) => AppDialog(
                icon: Icons.task_alt_rounded,
                title: 'Resolve ticket',
                content: TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 2,
                  onChanged: (_) => setLocal(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Remarks (required)',
                    border: OutlineInputBorder(),
                  ),
                ),
                confirmLabel: 'Resolve',
                onConfirm:
                    ctrl.text.trim().isEmpty
                        ? null
                        : () => Navigator.of(ctx).pop(ctrl.text.trim()),
                cancelLabel: 'Cancel',
                onCancel: () => Navigator.of(ctx).pop(),
              ),
        ),
  );
  ctrl.dispose();
  return result;
}
