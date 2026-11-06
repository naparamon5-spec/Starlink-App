import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/shared/widgets/app_dialog.dart';

enum _ToastKind { success, error, info }

/// The app's one way to report a result: a Success or Failed card in the centre
/// of the screen, above pages, slide-up sheets and dialogs.
///
/// Success closes by itself, with a bar counting down, or on any tap. Failed stays until OK is tapped, so
/// it can be read. It lives in the root overlay rather than on the navigator,
/// so a page can close right after showing one.
///
/// Call [success], [error] or [info] with a [BuildContext]. When the page may
/// close before the message is shown, take [AppToast.of] first and use that.
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
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 160),
  );
  static const _autoClose = Duration(milliseconds: 2800);
  Timer? _timer;
  bool _closing = false;

  bool get _isError => widget.kind == _ToastKind.error;
  bool get _hasAction => widget.actionLabel != null;

  /// Failed messages and ones with a choice wait for a tap.
  bool get _needsTap => _isError || _hasAction;

  @override
  void initState() {
    super.initState();
    _anim.forward();
    if (!_needsTap) {
      _timer = Timer(_autoClose, _close);
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

  /// Ink, gradient start, gradient end, icon, title.
  (Color, Color, Color, IconData, String) get _look => switch (widget.kind) {
    _ToastKind.success => (
      AppColors.successInk,
      AppColors.success,
      AppColors.successInk,
      Icons.check_rounded,
      'Success',
    ),
    _ToastKind.error => (
      AppColors.dangerInk,
      AppColors.danger,
      AppColors.dangerInk,
      Icons.close_rounded,
      'Failed',
    ),
    _ToastKind.info => (
      AppColors.navy,
      AppColors.navy,
      const Color(0xFF0A1F29),
      Icons.notifications_none_rounded,
      'Notice',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (ink, fill, deep, icon, title) = _look;
    final fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    final pop = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    final width = math.min(340.0, MediaQuery.sizeOf(context).width - 48);
    return Positioned.fill(
      child: Stack(
        children: [
          // Not inside a fade: a blur under one would have nothing to blur.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _needsTap ? null : _close,
              child: AnimatedBuilder(
                animation: fade,
                builder:
                    (_, __) => BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 5 * fade.value,
                        sigmaY: 5 * fade.value,
                      ),
                      child: ColoredBox(
                        color: AppColors.navy.withValues(
                          alpha: 0.5 * fade.value,
                        ),
                      ),
                    ),
              ),
            ),
          ),
          Center(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: FadeTransition(
                  opacity: fade,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.86, end: 1.0).animate(pop),
                    child: SizedBox(
                      width: width,
                      child: Semantics(
                        liveRegion: true,
                        child: GestureDetector(
                          onTap: _needsTap ? null : _close,
                          child: Material(
                            color: AppColors.paper,
                            elevation: 16,
                            shadowColor: Colors.black54,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppDialogHeader(
                                  icon: icon,
                                  color: fill,
                                  deep: deep,
                                ),
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      18,
                                      22,
                                      18,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w800,
                                            color: ink,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Flexible(
                                          child: SingleChildScrollView(
                                            child: Text(
                                              widget.message,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.45,
                                                color: AppColors.inkSoft,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        _buttons(fill),
                                      ],
                                    ),
                                  ),
                                ),
                                if (!_needsTap)
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 1, end: 0),
                                    duration: _autoClose,
                                    builder:
                                        (_, left, __) =>
                                            LinearProgressIndicator(
                                              value: left,
                                              minHeight: 4,
                                              color: fill,
                                              backgroundColor: fill.withValues(
                                                alpha: 0.12,
                                              ),
                                            ),
                                  ),
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
        ],
      ),
    );
  }

  Widget _buttons(Color fill) {
    final padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 13);
    if (!_hasAction) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _close,
          style: FilledButton.styleFrom(
            backgroundColor: fill,
            foregroundColor: Colors.white,
            padding: padding,
          ),
          child: Text(_isError ? 'OK' : 'Done'),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _close,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.lineStrong),
              padding: padding,
            ),
            child: const Text('Dismiss'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: () {
              widget.onAction?.call();
              _close();
            },
            style: FilledButton.styleFrom(
              backgroundColor: fill,
              foregroundColor: Colors.white,
              padding: padding,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(widget.actionLabel!),
            ),
          ),
        ),
      ],
    );
  }
}
