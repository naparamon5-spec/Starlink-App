import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Displays the app's version as embedded in the running build.
///
/// The value is read at runtime from [PackageInfo.fromPlatform], so it always
/// reflects the actually installed version/build rather than a hardcoded
/// string that can drift out of sync with `pubspec.yaml`.
///
/// Renders nothing until the platform metadata resolves (and nothing at all if
/// it can't be read), so it is safe to drop at the bottom of any screen.
class AppVersionLabel extends StatefulWidget {
  const AppVersionLabel({super.key, this.color, this.padding});

  /// Text color. Defaults to a muted grey when null.
  final Color? color;

  /// Optional padding around the label.
  final EdgeInsetsGeometry? padding;

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = 'Version ${info.version}';
      });
    } catch (_) {
      // Leave empty if platform metadata is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_version.isEmpty) return const SizedBox.shrink();

    final label = Text(
      _version,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: widget.color ?? const Color(0xFFA8A8A8),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );

    return Center(
      child: widget.padding == null
          ? label
          : Padding(padding: widget.padding!, child: label),
    );
  }
}
