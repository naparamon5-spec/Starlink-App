import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/services/biometric_service.dart';

/// Biometric-first sign-in: shows who's signing in and the single best method
/// this device has, with the password as the way out. Same as ANI HRIS.
class BiometricSignInPanel extends StatelessWidget {
  const BiometricSignInPanel({
    super.key,
    required this.email,
    required this.method,
    required this.busy,
    required this.onSignIn,
    required this.onUsePassword,
  });

  final String email;
  final BiometricMethod method;
  final bool busy;
  final VoidCallback onSignIn;
  final VoidCallback onUsePassword;

  Widget get _icon => switch (method) {
    BiometricMethod.face => const FaceIdIcon(size: 48, color: AppColors.brand),
    BiometricMethod.fingerprint => const Icon(
      Icons.fingerprint_rounded,
      size: 50,
      color: AppColors.brand,
    ),
    BiometricMethod.iris => const Icon(
      Icons.remove_red_eye_rounded,
      size: 48,
      color: AppColors.brand,
    ),
    BiometricMethod.pin => const Icon(
      Icons.pin_rounded,
      size: 46,
      color: AppColors.brand,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          const Text(
            'Signing in as',
            style: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  size: 18,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Semantics(
            button: true,
            label: 'Sign in with ${method.label}',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : onSignIn,
              child: Column(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.brand.withValues(alpha: 0.25),
                      ),
                    ),
                    child:
                        busy
                            ? const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.brand,
                              ),
                            )
                            : _icon,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    busy ? 'Signing in…' : 'Tap to sign in with ${method.label}',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: busy ? null : onUsePassword,
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            child: const Text(
              'Enter password',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The iOS Face ID glyph: corner brackets framing a simple face.
class FaceIdIcon extends StatelessWidget {
  const FaceIdIcon({super.key, this.size = 48, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _FaceIdPainter(color)),
  );
}

class _FaceIdPainter extends CustomPainter {
  const _FaceIdPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.055
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final corner = w * 0.22;
    final inset = w * 0.06;
    final radius = Radius.circular(w * 0.14);
    final r = w * 0.14;

    canvas.drawPath(
      Path()
        ..moveTo(inset, inset + corner)
        ..lineTo(inset, inset + r)
        ..arcToPoint(Offset(inset + r, inset), radius: radius)
        ..lineTo(inset + corner, inset),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - inset - corner, inset)
        ..lineTo(w - inset - r, inset)
        ..arcToPoint(Offset(w - inset, inset + r), radius: radius)
        ..lineTo(w - inset, inset + corner),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - inset, h - inset - corner)
        ..lineTo(w - inset, h - inset - r)
        ..arcToPoint(Offset(w - inset - r, h - inset), radius: radius)
        ..lineTo(w - inset - corner, h - inset),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(inset + corner, h - inset)
        ..lineTo(inset + r, h - inset)
        ..arcToPoint(Offset(inset, h - inset - r), radius: radius)
        ..lineTo(inset, h - inset - corner),
      p,
    );

    canvas.drawLine(Offset(w * 0.36, h * 0.36), Offset(w * 0.36, h * 0.46), p);
    canvas.drawLine(Offset(w * 0.64, h * 0.36), Offset(w * 0.64, h * 0.46), p);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.42)
        ..lineTo(w * 0.5, h * 0.56)
        ..lineTo(w * 0.57, h * 0.56),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.36, h * 0.64)
        ..arcToPoint(
          Offset(w * 0.64, h * 0.64),
          radius: Radius.circular(w * 0.22),
          clockwise: false,
        ),
      p,
    );
  }

  @override
  bool shouldRepaint(_FaceIdPainter oldDelegate) => oldDelegate.color != color;
}
