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
              (ctx, setLocal) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('Resolve ticket'),
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
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed:
                        ctrl.text.trim().isEmpty
                            ? null
                            : () => Navigator.of(ctx).pop(ctrl.text.trim()),
                    child: const Text('Resolve'),
                  ),
                ],
              ),
        ),
  );
  ctrl.dispose();
  return result;
}
