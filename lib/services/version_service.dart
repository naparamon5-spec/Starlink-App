import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:starlink_app/core/config/app_env.dart';

// ---------------------------------------------------------------------------
// AppVersionInfo
// ---------------------------------------------------------------------------

class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    required this.downloadUrl,
    this.isMandatory = false,
    this.minSupportedVersion,
  });

  final AppComparableVersion latestVersion;
  final Uri downloadUrl;
  final bool isMandatory;

  /// Oldest version the backend still supports. Clients below this get a
  /// blocking "update required" wall. Null → soft prompt only (plus the
  /// legacy [isMandatory] flag still works for backward compat).
  final AppComparableVersion? minSupportedVersion;
}

/// Launch-time decision for the version gate.
enum AppUpdateAction { none, soft, forced }

// ---------------------------------------------------------------------------
// AppComparableVersion  (replaces AppVersion / app_version_comparer.dart)
// ---------------------------------------------------------------------------

/// Compares major.minor.patch only — build number is intentionally ignored.
class AppComparableVersion implements Comparable<AppComparableVersion> {
  const AppComparableVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  final int major;
  final int minor;
  final int patch;

  static AppComparableVersion? tryParse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final normalized =
        trimmed.startsWith('v') || trimmed.startsWith('V')
            ? trimmed.substring(1)
            : trimmed;

    // Strip any +build suffix before splitting.
    final coreParts = normalized.split('+').first.split('.');
    if (coreParts.isEmpty) return null;

    // Tolerate "2", "2.0" and "2.0.0" — missing segments default to 0.
    final major = int.tryParse(coreParts[0]);
    final minor = coreParts.length > 1 ? int.tryParse(coreParts[1]) : 0;
    final patch = coreParts.length > 2 ? int.tryParse(coreParts[2]) : 0;
    if (major == null || minor == null || patch == null) return null;

    return AppComparableVersion(major: major, minor: minor, patch: patch);
  }

  @override
  int compareTo(AppComparableVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return 0;
  }

  bool isOutdated(AppComparableVersion other) => compareTo(other) < 0;

  bool operator <(AppComparableVersion other) => compareTo(other) < 0;
  bool operator <=(AppComparableVersion other) => compareTo(other) <= 0;
  bool operator >(AppComparableVersion other) => compareTo(other) > 0;
  bool operator >=(AppComparableVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is AppComparableVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

// ---------------------------------------------------------------------------
// AppVersionService  (replaces VersionService)
// ---------------------------------------------------------------------------

class AppVersionService {
  AppVersionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Value of `application` in the `mobile_versioning` table for this app.
  static const String applicationName = 'Starlink';

  // Without `platform` the backend defaults to android and hands iPhones the
  // APK URL, which iOS can't open.
  static Uri get _versionEndpoint => Uri.parse(
      '${AppEnv.apiBaseUrl}/mobile-version/'
      '?platform=${Platform.isIOS ? 'ios' : 'android'}');

  /// Picks this app's row out of the `mobile-version` payload, which is a list
  /// of `{ id, application, version, url }` rows — one per mobile app.
  static Map? _rowForThisApp(dynamic decoded) {
    // Unwrap common envelopes: `{ data: [...] }`, `{ results: [...] }`.
    dynamic body = decoded;
    if (body is Map) {
      body = body['data'] ?? body['results'] ?? body;
    }

    if (body is Map) return body; // already a single row

    if (body is List) {
      for (final row in body) {
        if (row is! Map) continue;
        final app = row['application']?.toString().trim().toLowerCase();
        if (app == applicationName.toLowerCase()) return row;
      }
    }
    return null;
  }

  Future<AppVersionInfo?> fetchLatestVersion({
    Uri? endpoint,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = endpoint ?? _versionEndpoint;

    try {
      final res = await _client.get(uri).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final dynamic decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      final payload = _rowForThisApp(decoded);
      if (payload == null) return null;

      final latestStr =
          (payload['version'] ??
                  payload['latest_version'] ??
                  payload['latestVersion'] ??
                  payload['mobile_version'] ??
                  payload['mobileVersion'])
              ?.toString()
              .trim();

      final urlStr =
          (payload['url'] ??
                  payload['download_url'] ??
                  payload['downloadUrl'] ??
                  payload['mobile_url'] ??
                  payload['mobileUrl'])
              ?.toString()
              .trim();

      // `version` is nullable in the table — no version published means
      // there is nothing to compare against, so never gate the user.
      if (latestStr == null || latestStr.isEmpty || latestStr == 'null') {
        return null;
      }
      if (urlStr == null || urlStr.isEmpty || urlStr == 'null') return null;

      final latest = AppComparableVersion.tryParse(latestStr);
      if (latest == null) return null;

      final url = Uri.tryParse(urlStr);
      if (url == null || !url.hasScheme) return null;

      // Optional "oldest supported" floor from the backend. When present and
      // the installed version is below it, we show the blocking force wall.
      // Older builds that don't send this just degrade to soft-prompt-only.
      final minStr = (payload['min_version'] ??
              payload['minVersion'] ??
              payload['min_supported_version'] ??
              payload['minSupportedVersion'])
          ?.toString()
          .trim();

      return AppVersionInfo(
        latestVersion: latest,
        downloadUrl: url,
        // The table carries no "optional update" flag: any published version
        // newer than the installed one is a hard gate, same as eForward/ARM.
        isMandatory: _asBool(
          payload['is_mandatory'] ?? payload['isMandatory'] ?? true,
        ),
        minSupportedVersion: (minStr == null || minStr.isEmpty || minStr == 'null')
            ? null
            : AppComparableVersion.tryParse(minStr),
      );
    } catch (e) {
      debugPrint('fetchLatestVersion failed: $e');
      return null;
    }
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value?.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  Future<AppComparableVersion?> getInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      if (v.isEmpty) return null;
      return AppComparableVersion.tryParse(v.split('+').first);
    } catch (e) {
      debugPrint('getInstalledVersion failed: $e');
      return null;
    }
  }

  Future<String?> getPackageName() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final pkg = info.packageName.trim();
      return pkg.isEmpty ? null : pkg;
    } catch (e) {
      debugPrint('getPackageName failed: $e');
      return null;
    }
  }

  Future<void> launchUninstallFlow({required String packageName}) async {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(
      action: 'android.intent.action.DELETE',
      data: 'package:$packageName',
    );
    await intent.launch();
  }

  Future<bool> launchDownload(Uri url) async {
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Classifies the installed version against the backend's min + latest.
  /// Below [AppVersionInfo.minSupportedVersion] → forced wall.
  /// Below [AppVersionInfo.latestVersion] (but at/above min) → soft prompt.
  /// Otherwise → none.
  static AppUpdateAction decideUpdate(
    AppComparableVersion installed,
    AppVersionInfo remote,
  ) {
    final min = remote.minSupportedVersion;
    if (min != null && installed < min) return AppUpdateAction.forced;
    // Backwards-compat: if the backend's old `is_mandatory` flag is set and
    // we're below latest, treat as forced (preserves pre-min_version behavior).
    if (remote.isMandatory && installed < remote.latestVersion) {
      return AppUpdateAction.forced;
    }
    if (installed < remote.latestVersion) return AppUpdateAction.soft;
    return AppUpdateAction.none;
  }

  /// Convenience: run the full version check and return a result map
  /// (same shape as the old VersionService.checkVersion, plus `action`).
  Future<Map<String, dynamic>> checkVersion() async {
    final current = await getInstalledVersion();
    if (current == null) return {'isOutdated': false, 'action': AppUpdateAction.none};

    final remote = await fetchLatestVersion();
    if (remote == null) return {'isOutdated': false, 'action': AppUpdateAction.none};

    final action = decideUpdate(current, remote);
    return {
      'isOutdated': current.isOutdated(remote.latestVersion),
      'action': action,
      'downloadUrl': remote.downloadUrl.toString(),
      'isMandatory': remote.isMandatory,
      'currentVersion': current.toString(),
      'latestVersion': remote.latestVersion.toString(),
    };
  }

  void dispose() {
    _client.close();
  }
}

// ---------------------------------------------------------------------------
// ForceUpdateDialog  (replaces force_update_dialog.dart)
// ---------------------------------------------------------------------------

/// Dismissible "update available" prompt. Returns `true` if the user tapped
/// "Update" (download link launched); `false` for Later or dismissal.
Future<bool> showSoftUpdateDialog({
  required BuildContext context,
  required AppVersionInfo remote,
  required AppComparableVersion current,
}) async {
  var updateInitiated = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Update Available'),
      content: Text(
        'A newer version of the app is available (${remote.latestVersion}). '
        'Update now for improvements and fixes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () async {
            final svc = AppVersionService();
            try {
              final ok = await svc.launchDownload(remote.downloadUrl);
              if (!dialogContext.mounted) return;
              if (ok) {
                updateInitiated = true;
                Navigator.of(dialogContext).pop();
              } else {
                ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                  const SnackBar(
                    content: Text('Unable to open update link. Please try again.'),
                  ),
                );
              }
            } finally {
              svc.dispose();
            }
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );
  return updateInitiated;
}

Future<void> showForceUpdateDialog({
  required BuildContext context,
  required AppVersionInfo remote,
  required AppComparableVersion current,
  required String? packageName,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Update Required'),
          content: Text(
            'Your app version is outdated.\n\n'
            'Current: $current\n'
            'Latest: ${remote.latestVersion}\n\n'
            'Tap "Update Now" to download and install the latest version.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  final svc = AppVersionService();
                  final ok = await svc.launchDownload(remote.downloadUrl);
                  svc.dispose();
                  if (!ok) {
                    final messenger = ScaffoldMessenger.maybeOf(dialogContext);
                    messenger?.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to open update link. Check the APK URL.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Update launch failed: $e');
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      );
    },
  );
}
