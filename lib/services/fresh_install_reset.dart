import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clears secure storage on a fresh install.
///
/// iOS keeps Keychain items after the app is deleted, so a reinstall would
/// find the previous biometric login and stay enrolled. SharedPreferences are
/// deleted with the app, so a missing marker means this is a new install.
class FreshInstallReset {
  FreshInstallReset._();

  static const _kInstalled = 'fresh_install_checked';

  /// Call first in `main()`, before anything reads secure storage.
  static Future<void> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kInstalled) == true) return;
      // Existing data means an older build was updated, not reinstalled.
      final isUpdate = prefs.getKeys().isNotEmpty;
      if (!isUpdate) {
        await const FlutterSecureStorage().deleteAll();
        await const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ).deleteAll();
      }
      await prefs.setBool(_kInstalled, true);
    } catch (e) {
      debugPrint('[FreshInstallReset] skipped: $e');
    }
  }
}
