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
  });

  final AppComparableVersion latestVersion;
  final Uri downloadUrl;
  final bool isMandatory;
}

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
    if (coreParts.length < 3) return null;

    final major = int.tryParse(coreParts[0]);
    final minor = int.tryParse(coreParts[1]);
    final patch = int.tryParse(coreParts[2]);
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

  static Uri get _versionEndpoint =>
      Uri.parse('${AppEnv.apiBaseUrl}/app/version');

  Future<AppVersionInfo?> fetchLatestVersion({
    Uri? endpoint,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = endpoint ?? _versionEndpoint;

    try {
      final res = await _client.get(uri).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final dynamic decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      if (decoded is! Map) return null;

      // Support both wrapped `{ data: {...} }` and flat payloads.
      final payload = decoded['data'] is Map ? decoded['data'] : decoded;

      final latestStr =
          (payload['latest_version'] ??
                  payload['latestVersion'] ??
                  payload['mobile_version'] ??
                  payload['mobileVersion'])
              ?.toString()
              .trim();

      final urlStr =
          (payload['download_url'] ??
                  payload['downloadUrl'] ??
                  payload['mobile_url'] ??
                  payload['mobileUrl'] ??
                  payload['url'])
              ?.toString()
              .trim();

      if (latestStr == null || latestStr.isEmpty) return null;
      if (urlStr == null || urlStr.isEmpty) return null;

      final latest = AppComparableVersion.tryParse(latestStr);
      if (latest == null) return null;

      final url = Uri.tryParse(urlStr);
      if (url == null) return null;

      final isMandatory =
          payload['is_mandatory'] ??
          payload['isMandatory'] ??
          payload['mandatory'] ??
          false;

      return AppVersionInfo(
        latestVersion: latest,
        downloadUrl: url,
        isMandatory: isMandatory as bool,
      );
    } catch (e) {
      debugPrint('fetchLatestVersion failed: $e');
      return null;
    }
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

  /// Convenience: run the full version check and return a result map
  /// (same shape as the old VersionService.checkVersion).
  Future<Map<String, dynamic>> checkVersion() async {
    final current = await getInstalledVersion();
    if (current == null) return {'isOutdated': false};

    final remote = await fetchLatestVersion();
    if (remote == null) return {'isOutdated': false};

    return {
      'isOutdated': current.isOutdated(remote.latestVersion),
      'downloadUrl': remote.downloadUrl.toString(),
      'isMandatory': remote.isMandatory,
    };
  }

  void dispose() {
    _client.close();
  }
}

// ---------------------------------------------------------------------------
// ForceUpdateDialog  (replaces force_update_dialog.dart)
// ---------------------------------------------------------------------------

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
