import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:flutter/material.dart';

/// Asks before throwing away edits. True when the user chose to discard.
Future<bool> confirmDiscardChanges(BuildContext context) {
  return showAppConfirm(
    context,
    title: 'Discard changes?',
    message: "Your changes haven't been saved. If you leave now, they'll be lost.",
    confirmLabel: 'Discard',
    cancelLabel: 'Keep editing',
    icon: Icons.edit_off_outlined,
    tone: AppDialogTone.danger,
  );
}

/// Wrap a form's page, dialog or sheet: while [isDirty] is true, leaving by
/// the back arrow, the Android back button or a barrier tap asks first, and
/// the iOS edge swipe is held back. Nothing is asked when nothing changed.
///
/// Close buttons must use `Navigator.maybePop` to be guarded; a direct
/// `Navigator.pop` (as after a successful save) leaves without asking.
/// Bottom sheets also need `enableDrag: false`, because a drag pops directly.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.isDirty,
    required this.child,
    this.listenTo,
  });

  final bool Function() isDirty;
  final Widget child;

  /// Text controllers and the like, which change without a parent rebuild.
  final Listenable? listenTo;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenTo ?? const AlwaysStoppedAnimation<int>(0),
      child: child,
      builder:
          (context, child) => PopScope<Object?>(
            canPop: !isDirty(),
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              if (await confirmDiscardChanges(context) && context.mounted) {
                Navigator.of(context).pop(result);
              }
            },
            child: child!,
          ),
    );
  }
}

/// Remembers a form's values the first time they're read once it is ready,
/// so anything loaded from the server doesn't count as a change.
class FormBaseline {
  String? _baseline;

  bool changed({required bool ready, required List<Object?> values}) {
    if (!ready) return false;
    final current = values.join('\u0001');
    _baseline ??= current;
    return current != _baseline;
  }
}
