import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the login screen offers sign-in, best first: Face ID, then fingerprint,
/// then iris, then the device PIN. Password is always the last resort.
enum BiometricMethod {
  face('Face ID'),
  fingerprint('Fingerprint'),
  iris('Iris'),
  pin('PIN code');

  const BiometricMethod(this.label);
  final String label;

  bool get isBiometric => this != BiometricMethod.pin;
}

/// Outcome of a device authentication prompt.
class BiometricResult {
  const BiometricResult._(this.success, {this.message});

  final bool success;

  /// Why it failed, when that's more than the user cancelling.
  final String? message;

  static const ok = BiometricResult._(true);
  static const cancelled = BiometricResult._(false);
  factory BiometricResult.failed(String message) =>
      BiometricResult._(false, message: message);
}

/// Biometric login, same approach as ANI HRIS: after opting in, the device
/// check releases a saved refresh token that restores the session. The
/// password is never stored.
class BiometricService {
  BiometricService._();

  static const backgroundTimeout = Duration(minutes: 3);

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kEmail = 'bio_email';
  static const _kRefresh = 'bio_refresh_token';
  static const _kBackgroundedAt = 'backgrounded_at';

  static LocalAuthentication _auth = LocalAuthentication();

  /// Bumped whenever biometric login is turned on or off, so a settings card
  /// on screen can follow a change made elsewhere (e.g. a password change).
  static final enrollmentChanges = ValueNotifier<int>(0);

  @visibleForTesting
  static set authForTesting(LocalAuthentication auth) => _auth = auth;

  // ── Device ────────────────────────────────────────────────────────────────

  /// Whether the device has a biometric or passcode it can check right now.
  static Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// The best method this device actually has.
  static Future<BiometricMethod> bestMethod() async {
    var types = const <BiometricType>[];
    try {
      types = await _auth.getAvailableBiometrics();
    } catch (_) {
      // Fall through to the PIN.
    }
    if (types.contains(BiometricType.face)) return BiometricMethod.face;
    if (types.contains(BiometricType.fingerprint)) {
      return BiometricMethod.fingerprint;
    }
    if (types.contains(BiometricType.iris)) return BiometricMethod.iris;
    // Many Android phones report only a strength, not the sensor.
    if (types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak)) {
      return BiometricMethod.fingerprint;
    }
    return BiometricMethod.pin;
  }

  static String get setupMessage =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? 'Set up Face ID, Touch ID or a passcode in your iPhone Settings first.'
          : 'Set up a fingerprint or screen lock in your phone settings first.';

  static Future<BiometricResult> authenticate(
    String reason, {
    required bool biometricOnly,
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
        ),
      );
      return ok ? BiometricResult.ok : BiometricResult.cancelled;
    } on PlatformException catch (e) {
      return BiometricResult.failed(_messageFor(e.code));
    }
  }

  static String _messageFor(String code) => switch (code) {
    auth_error.notEnrolled || auth_error.passcodeNotSet => setupMessage,
    auth_error.lockedOut =>
      'Too many failed attempts. Wait a moment, then try again.',
    auth_error.permanentlyLockedOut =>
      'Unlock your phone with its passcode first, then try again.',
    _ => "This device can't authenticate you right now.",
  };

  // ── Enrollment ────────────────────────────────────────────────────────────

  static Future<String?> _read(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> savedEmail() async =>
      await savedRefreshToken() == null ? null : _read(_kEmail);

  static Future<String?> savedRefreshToken() => _read(_kRefresh);

  static Future<bool> isEnrolled() async => await savedEmail() != null;

  static Future<void> enroll(String email, String refreshToken) async {
    await _storage.write(key: _kEmail, value: email.trim());
    await _storage.write(key: _kRefresh, value: refreshToken);
    enrollmentChanges.value++;
  }

  static Future<void> clearEnrollment() async {
    try {
      await _storage.delete(key: _kEmail);
      await _storage.delete(key: _kRefresh);
    } catch (_) {
      // Nothing saved to remove.
    }
    enrollmentChanges.value++;
  }

  /// The backend replaces the refresh token on every use, so the saved copy
  /// has to follow it or biometric login would stop working.
  static Future<void> syncRefreshToken(String refreshToken) async {
    if (!await isEnrolled()) return;
    try {
      await _storage.write(key: _kRefresh, value: refreshToken);
    } catch (_) {
      // Keeps the previous token; the worst case is signing in by password.
    }
  }

  /// Enrollment belongs to one person. Call before saving a new sign-in's
  /// tokens, so someone else on this device doesn't inherit it.
  static Future<void> handleSignIn(String email) async {
    final saved = await savedEmail();
    if (saved != null && saved.toLowerCase() != email.trim().toLowerCase()) {
      await clearEnrollment();
    }
  }

  // ── Time away from the app ────────────────────────────────────────────────

  static Future<void> markBackgrounded(DateTime? at) async {
    final prefs = await SharedPreferences.getInstance();
    if (at == null) {
      await prefs.remove(_kBackgroundedAt);
    } else {
      await prefs.setString(_kBackgroundedAt, at.toIso8601String());
    }
  }

  /// True when the app was left for [backgroundTimeout] before being closed.
  /// Clears the stamp either way.
  static Future<bool> consumeBackgroundExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final at = DateTime.tryParse(prefs.getString(_kBackgroundedAt) ?? '');
    await prefs.remove(_kBackgroundedAt);
    return at != null && DateTime.now().difference(at) >= backgroundTimeout;
  }
}
