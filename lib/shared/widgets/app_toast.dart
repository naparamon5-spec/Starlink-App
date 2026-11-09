import 'dart:async';

import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';

enum _ToastKind { success, error, info, neutral }

/// The app's one way to report a result: a card at the top of the screen,
/// above pages, slide-up sheets and dialogs, matching the web portal's toast
/// (ardent_starlink_client: app/components/ui/Toast.vue).
///
/// It doesn't block the page. It closes by itself (errors stay up longer so
/// they can be read) or with its X; one with an action waits for a tap. It
/// lives in the root overlay rather than on the navigator, so a page can close
/// right after showing one.
///
/// Call [success], [error], [info] or [neutral] with a [BuildContext]. When the
/// page may close before the message is shown, take [AppToast.of] first and use
/// that.
class AppToast {
  AppToast._(this._overlay);

  final OverlayState? _overlay;

  /// Only one message shows at a time; a new one replaces it.
  static OverlayEntry? _current;

  static AppToast of(BuildContext context) =>
      AppToast._(Overlay.maybeOf(context, rootOverlay: true));

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
    final overlay = _overlay;
    if (overlay == null || !overlay.mounted) return;
    _removeCurrent();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (_) => _ToastView(
            message: message,
            kind: kind,
            actionLabel: actionLabel,
            onAction: onAction,
            onClosed: () {
              if (identical(_current, entry)) _current = null;
              if (entry.mounted) entry.remove();
            },
          ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static void _removeCurrent() {
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.kind,
    required this.onClosed,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final _ToastKind kind;
  final VoidCallback onClosed;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );
  Timer? _timer;
  bool _closing = false;

  bool get _hasAction => widget.actionLabel != null;

  @override
  void initState() {
    super.initState();
    _anim.forward();
    if (!_hasAction) {
      _timer = Timer(
        Duration(seconds: widget.kind == _ToastKind.error ? 8 : 5),
        _close,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _anim.reverse();
    if (mounted) widget.onClosed();
  }

  /// Accent bar, icon tile, icon colour, icon, action text.
  (Color, Color, Color, IconData, Color) get _look => switch (widget.kind) {
    _ToastKind.success => (
      AppColors.success,
      AppColors.success.withValues(alpha: 0.08),
      AppColors.successInk,
      Icons.check_circle_outline_rounded,
      AppColors.successInk,
    ),
    _ToastKind.error => (
      AppColors.brand,
      AppColors.brand.withValues(alpha: 0.08),
      AppColors.dangerInk,
      Icons.highlight_off_rounded,
      AppColors.dangerInk,
    ),
    _ToastKind.info => (
      AppColors.info,
      AppColors.info.withValues(alpha: 0.08),
      AppColors.infoInk,
      Icons.info_outline_rounded,
      AppColors.infoInk,
    ),
    _ToastKind.neutral => (
      AppColors.navy,
      AppColors.navyLight,
      Colors.white,
      Icons.sync_rounded,
      AppColors.navy,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (bar, tile, iconColor, icon, actionColor) = _look;
    final curve = CurvedAnimation(
      parent: _anim,
      curve: const Cubic(0.22, 1, 0.36, 1),
      reverseCurve: Curves.easeIn,
    );
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: FadeTransition(
                opacity: curve,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.5),
                    end: Offset.zero,
                  ).animate(curve),
                  child: Semantics(
                    liveRegion: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.md,
                      ),
                      child: Material(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        clipBehavior: Clip.antiAlias,
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ColoredBox(
                                color: bar,
                                child: const SizedBox(width: 4),
                              ),
                              Container(
                                width: 44,
                                color: tile,
                                alignment: Alignment.topCenter,
                                padding: const EdgeInsets.only(top: 14),
                                child: Icon(icon, size: 18, color: iconColor),
                              ),
                              Expanded(child: _body(actionColor)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(Color actionColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    widget.message,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _close,
                tooltip: 'Dismiss',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                color: AppColors.inkFaint,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (_hasAction)
            TextButton(
              onPressed: () {
                widget.onAction?.call();
                _close();
              },
              style: TextButton.styleFrom(
                foregroundColor: actionColor,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                widget.actionLabel!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
