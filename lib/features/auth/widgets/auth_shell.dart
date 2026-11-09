import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:starlink_app/core/theme/app_theme.dart';

/// Brand panel above a form: the phone layout of the web portal's auth pages
/// (ardent_starlink_client: app/layouts/auth.vue).
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paperSubtle,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BrandPanel(topPadding: padding.top),
              Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const Positioned(
                    top: -160,
                    right: -100,
                    child: _Glow(opacity: 0.14),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      28,
                      24,
                      28 + padding.bottom,
                    ),
                    child: child,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.topPadding});

  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navy,
      child: CustomPaint(
        painter: const _HexPatternPainter(),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned(
              bottom: -160,
              right: -100,
              child: _Glow(opacity: 0.28),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, topPadding + 18, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Wordmark(),
                  const SizedBox(height: 26),
                  const Text(
                    'Technology should\nfeel effortless.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ardent Networks keeps your business connected, clear, and '
                    'always moving forward. Manage your Starlink subscriptions, '
                    'tickets, and billing — all in one place.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // The mark is red and black, so it needs a light base.
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: SvgPicture.asset(
                          'assets/images/logo.svg',
                          height: 18,
                          width: 28,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Ardent Networks, Inc. · Powering Innovation',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      color: Colors.white,
      fontSize: 8.5,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    );
    return Semantics(
      label: 'Starlink Authorized Reseller',
      excludeSemantics: true,
      child: const Row(
        children: [
          Text(
            'STARLINK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
          ),
          SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AUTHORIZED', style: label),
              Text('RESELLER', style: label),
            ],
          ),
        ],
      ),
    );
  }
}

/// Soft red glow straddling the edge between the panel and the form.
class _Glow extends StatelessWidget {
  const _Glow({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.brand.withValues(alpha: opacity),
              AppColors.brand.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// The web portal's `.hex-pattern` tile (40x46, white at 5%).
class _HexPatternPainter extends CustomPainter {
  const _HexPatternPainter();

  static const _tileWidth = 40.0;
  static const _tileHeight = 46.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.05);
    final hex =
        Path()
          ..moveTo(20, 0)
          ..relativeLineTo(17.32, 10)
          ..relativeLineTo(0, 20)
          ..lineTo(20, 40)
          ..lineTo(2.68, 30)
          ..lineTo(2.68, 10)
          ..close();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var y = 0.0; y < size.height; y += _tileHeight) {
      for (var x = 0.0; x < size.width; x += _tileWidth) {
        canvas.drawPath(hex.shift(Offset(x, y)), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HexPatternPainter oldDelegate) => false;
}

/// Page title and subtitle above an auth form.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
        ),
      ],
    );
  }
}

/// Uppercase field label with the portal's red required mark.
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.inkSoft,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: text.toUpperCase(),
          style: style,
          children: const [
            TextSpan(text: ' *', style: TextStyle(color: AppColors.brand)),
          ],
        ),
      ),
    );
  }
}

InputDecoration authInputDecoration({
  required String hint,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    borderSide: BorderSide(color: color, width: 1.5),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.inkFaint, fontSize: 15),
    prefixIcon: Icon(prefixIcon, color: AppColors.inkMuted, size: 18),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.paper,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(AppColors.line),
    enabledBorder: border(AppColors.line),
    disabledBorder: border(AppColors.line),
    focusedBorder: border(AppColors.brand),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger),
    errorStyle: const TextStyle(color: AppColors.dangerInk, fontSize: 12),
    errorMaxLines: 2,
  );
}

/// Full-width red pill with a soft glow and an inline spinner while [loading].
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.7),
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child:
              loading
                  ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                  : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
      ),
    );
  }
}
