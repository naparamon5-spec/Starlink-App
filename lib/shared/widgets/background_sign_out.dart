import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/services/biometric_service.dart';

/// With biometric login on, returning after [timeout] away signs the user out
/// to the biometric sign-in panel, same as ANI HRIS. Does nothing otherwise.
class BackgroundSignOut extends StatefulWidget {
  const BackgroundSignOut({
    super.key,
    required this.child,
    required this.onExpired,
    this.timeout = BiometricService.backgroundTimeout,
  });

  final Widget child;
  final Future<void> Function() onExpired;
  final Duration timeout;

  @override
  State<BackgroundSignOut> createState() => _BackgroundSignOutState();
}

class _BackgroundSignOutState extends State<BackgroundSignOut>
    with WidgetsBindingObserver {
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (_leftAt == null) {
        _leftAt = DateTime.now();
        unawaited(BiometricService.markBackgrounded(_leftAt));
      }
    } else if (state == AppLifecycleState.resumed) {
      final leftAt = _leftAt;
      _leftAt = null;
      unawaited(BiometricService.markBackgrounded(null));
      if (leftAt != null &&
          DateTime.now().difference(leftAt) >= widget.timeout) {
        unawaited(_expire());
      }
    }
  }

  Future<void> _expire() async {
    if (!await BiometricService.isEnrolled()) return;
    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) return;
    await widget.onExpired();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
