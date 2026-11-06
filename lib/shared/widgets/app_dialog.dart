import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';

/// What a dialog's main button does: [danger] for losing or removing something,
/// [primary] for everything else.
enum AppDialogTone { primary, danger }

/// Asks a yes/no question. True only when the main button was tapped.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  required IconData icon,
  AppDialogTone tone = AppDialogTone.primary,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AppDialog(
          icon: icon,
          tone: tone,
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          onConfirm: () => Navigator.pop(ctx, true),
          cancelLabel: cancelLabel,
          onCancel: () => Navigator.pop(ctx, false),
        ),
  );
  return result == true;
}

/// The app's one dialog look: icon, title, message or [content], and full-width
/// buttons. Leave [cancelLabel] out for a dialog with a single button.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    this.tone = AppDialogTone.primary,
    this.message,
    this.content,
    this.cancelLabel,
    this.onCancel,
    this.extraLabel,
    this.onExtra,
  });

  final IconData icon;
  final AppDialogTone tone;
  final String title;
  final String? message;

  /// A field or other widget, shown below [message].
  final Widget? content;

  final String confirmLabel;

  /// Null shows the main button disabled.
  final VoidCallback? onConfirm;

  final String? cancelLabel;
  final VoidCallback? onCancel;

  /// A third, quieter choice, shown under the buttons.
  final String? extraLabel;
  final VoidCallback? onExtra;

  Widget _label(String text) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));

  @override
  Widget build(BuildContext context) {
    final color =
        tone == AppDialogTone.danger ? AppColors.danger : AppColors.navy;
    final buttonPadding = const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 13,
    );
    final confirm = FilledButton(
      onPressed: onConfirm,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: buttonPadding,
      ),
      child: _label(confirmLabel),
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDialogHeader(
              icon: icon,
              color: color,
              deep:
                  tone == AppDialogTone.danger
                      ? AppColors.dangerInk
                      : const Color(0xFF0A1F29),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: AppColors.navy,
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (message != null)
                              Text(
                                message!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            if (message != null && content != null)
                              const SizedBox(height: 14),
                            if (content != null) content!,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (cancelLabel == null)
                      SizedBox(width: double.infinity, child: confirm)
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.navy,
                                side: const BorderSide(
                                  color: AppColors.lineStrong,
                                ),
                                padding: buttonPadding,
                              ),
                              child: _label(cancelLabel!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: confirm),
                        ],
                      ),
                    if (extraLabel != null) ...[
                      const SizedBox(height: 6),
                      TextButton(onPressed: onExtra, child: Text(extraLabel!)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The coloured band on top of dialogs and Success/Failed messages: a gradient
/// with soft circles and an icon that pops in with a ring spreading behind it.
class AppDialogHeader extends StatelessWidget {
  const AppDialogHeader({
    super.key,
    required this.icon,
    required this.color,
    required this.deep,
  });

  final IconData icon;

  /// The gradient runs from [color] to [deep].
  final Color color;
  final Color deep;

  static Widget _bubble(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, deep],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: -34, left: -22, child: _bubble(104, 0.10)),
          Positioned(bottom: -46, right: -18, child: _bubble(124, 0.08)),
          Positioned(top: 18, right: 46, child: _bubble(12, 0.28)),
          Positioned(bottom: 22, left: 44, child: _bubble(8, 0.32)),
          Positioned(top: 30, left: 62, child: _bubble(5, 0.4)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            builder: (context, t, _) {
              final pop = Curves.elasticOut.transform(t);
              return Stack(
                alignment: Alignment.center,
                children: [
                  // The ring spreads and fades once.
                  Container(
                    width: 60 + 34 * t,
                    height: 60 + 34 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(
                        alpha: 0.28 * (1 - t) + 0.14,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: pop,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: deep.withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 32, color: color),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
