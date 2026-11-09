import 'dart:async';

import 'package:flutter/material.dart';
import 'package:starlink_app/shared/widgets/app_dialog.dart';

enum _ToastKind { success, error, info, neutral }

/// The app's one way to report a result: a dialog in the center of the screen,
/// above pages, slide-up sheets and other dialogs, in the same style as the
/// logout dialog. It stays up until it's dismissed.
///
/// It opens just after the calling code finishes, so a page can show a message
/// and close itself straight away: the page closes, not the message.
///
/// Call [success], [error], [info] or [neutral] with a [BuildContext]. When the
/// page may close before the message is shown, take [AppToast.of] first and use
/// that.
class AppToast {
  AppToast._(this._navigator);

  final NavigatorState? _navigator;

  /// Only one message shows at a time; a new one replaces it.
  static DialogRoute<void>? _current;

  static AppToast of(BuildContext context) =>
      AppToast._(Navigator.maybeOf(context, rootNavigator: true));

  static void success(BuildContext context, String message) =>
      of(context).showSuccess(message);

  static void error(BuildContext context, String message) =>
      of(context).showError(message);

  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => of(
    context,
  ).showInfo(message, actionLabel: actionLabel, onAction: onAction);

  static void neutral(BuildContext context, String message) =>
      of(context).showNeutral(message);

  /// Success when [ok], otherwise an error.
  static void result(
    BuildContext context,
    String message, {
    required bool ok,
  }) => ok ? success(context, message) : error(context, message);

  void showSuccess(String message) => _show(message, _ToastKind.success);

  void showError(String message) => _show(message, _ToastKind.error);

  void showInfo(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    message,
    _ToastKind.info,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  void showNeutral(String message) => _show(message, _ToastKind.neutral);

  void showResult(String message, {required bool ok}) =>
      ok ? showSuccess(message) : showError(message);

  void _show(
    String message,
    _ToastKind kind, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final navigator = _navigator;
    if (navigator == null || !navigator.mounted) return;
    scheduleMicrotask(() {
      if (!navigator.mounted) return;
      _removeCurrent();
      final route = DialogRoute<void>(
        context: navigator.context,
        builder:
            (ctx) => _MessageDialog(
              message: message,
              kind: kind,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
      );
      _current = route;
      navigator.push(route);
      route.popped.whenComplete(() {
        if (identical(_current, route)) _current = null;
      });
    });
  }

  static void _removeCurrent() {
    final route = _current;
    _current = null;
    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }
}

class _MessageDialog extends StatelessWidget {
  const _MessageDialog({
    required this.message,
    required this.kind,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final _ToastKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  (String, IconData) get _look => switch (kind) {
    _ToastKind.success => ('Success', Icons.check_circle_outline_rounded),
    _ToastKind.error => ('Something went wrong', Icons.highlight_off_rounded),
    _ToastKind.info => ('Notice', Icons.info_outline_rounded),
    _ToastKind.neutral => ('Notice', Icons.sync_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final (title, icon) = _look;
    final hasAction = actionLabel != null;
    void close() => Navigator.of(context).pop();
    return AppDialog(
      icon: icon,
      tone:
          kind == _ToastKind.error
              ? AppDialogTone.danger
              : AppDialogTone.primary,
      title: title,
      message: message,
      confirmLabel: actionLabel ?? 'OK',
      onConfirm: () {
        close();
        if (hasAction) onAction?.call();
      },
      cancelLabel: hasAction ? 'Close' : null,
      onCancel: hasAction ? close : null,
    );
  }
}
