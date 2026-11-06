import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:starlink_app/services/api_service.dart';

/// Push notifications via Firebase Cloud Messaging — same setup as
/// eforward_app / hris_mobile:
///   • iOS: Firebase is the sole notification delegate and shows banners
///     natively. flutter_local_notifications must NOT be initialized on iOS,
///     or it replaces Firebase's delegate and silently breaks iOS push.
///   • Android: FCM does not show foreground notifications by itself, so we
///     show them with flutter_local_notifications.
///
/// Firebase reads the native config files (android/app/google-services.json,
/// ios/Runner/GoogleService-Info.plist), so no firebase_options.dart is needed.
/// When a config file is missing, push is skipped and the app runs normally.

/// Android channel — must match the manifest default_notification_channel_id
/// and ANDROID_CHANNEL_ID in the backend's helpers/push.js.
const AndroidNotificationChannel kStarlinkChannel = AndroidNotificationChannel(
  'starlink_notifications',
  'Starlink Notifications',
  description: 'Ticket and account updates',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

/// Runs in its own isolate for messages that arrive while the app is in the
/// background or terminated. Must be top-level.
///
/// A message with a `notification` block is already shown by the OS in that
/// case, so only data-only messages are displayed here (otherwise Android
/// would show it twice).
@pragma('vm:entry-point')
Future<void> starlinkFcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (Platform.isIOS || message.notification != null) return;
  await _local.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await _local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(kStarlinkChannel);
  await PushService.showLocalNotification(message);
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Set from main() so notification taps can open the app's navigator.
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Whether a user is signed in; foreground pushes are hidden while signed out.
  static bool signedIn = false;

  bool _ready = false;
  bool _tokenRefreshBound = false;
  String? _registeredToken;

  /// Initialize FCM once at startup. Never throws: a missing Firebase config
  /// only disables push.
  Future<void> initialize() async {
    if (_ready || kIsWeb) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();

      await _requestPermissions();

      if (Platform.isAndroid) {
        await _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(kStarlinkChannel);
        await _local.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
          onDidReceiveNotificationResponse: (r) => _handlePayloadTap(r.payload),
        );
      }

      FirebaseMessaging.onBackgroundMessage(starlinkFcmBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _onNotificationTap(m.data),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _onNotificationTap(initial.data);

      _ready = true;
      debugPrint('✅ PushService ready');
    } catch (e) {
      debugPrint('❌ PushService init skipped: $e');
    }
  }

  Future<void> _requestPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  /// Shows a system-tray notification (Android only; iOS shows it via APNs).
  static Future<void> showLocalNotification(RemoteMessage message) async {
    if (Platform.isIOS) return;
    final title =
        message.notification?.title ??
        message.data['title'] ??
        'Ardent Starlink';
    final body =
        message.notification?.body ??
        message.data['body'] ??
        'You have a new notification';
    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          kStarlinkChannel.id,
          kStarlinkChannel.name,
          channelDescription: kStarlinkChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (!signedIn) return;
    await showLocalNotification(message);
  }

  static void _handlePayloadTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _onNotificationTap(jsonDecode(payload) as Map<String, dynamic>);
    } catch (_) {}
  }

  /// A tap opens the app (the OS does that). Screen routing by `type` /
  /// `ticket_id` in the data payload can be added here later.
  static void _onNotificationTap(Map<String, dynamic> data) {
    debugPrint('👆 Notification tapped: $data');
  }

  // ─── Device token ↔ backend ───────────────────────────────────────────────

  /// The device FCM token. On iOS the APNs token must arrive first, so retry.
  Future<String?> getToken() async {
    if (!_ready) return null;
    try {
      if (Platform.isIOS) {
        var apns = await FirebaseMessaging.instance.getAPNSToken();
        for (var i = 0; apns == null && i < 6; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          apns = await FirebaseMessaging.instance.getAPNSToken();
        }
        // The iOS Simulator never gets an APNs token; on a real device a
        // missing one usually means the APNs .p8 key isn't in Firebase yet.
        if (apns == null) return null;
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('getToken error: $e');
      return null;
    }
  }

  /// Sends this device's token to the backend (POST /v1/auth/fcm-token) and
  /// keeps it updated on rotation. Call after sign-in and on session restore.
  /// Best-effort: never blocks or fails sign-in.
  Future<void> registerWithBackend() async {
    if (kIsWeb) return;
    signedIn = true;
    if (!_ready) return;

    // Bind the refresh listener first so a token that arrives late (iOS APNs
    // is often not ready at sign-in) is still sent.
    if (!_tokenRefreshBound) {
      _tokenRefreshBound = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        if (t.isNotEmpty && signedIn) _postToken(t);
      });
    }

    final token = await getToken();
    if (token != null && token.isNotEmpty) await _postToken(token);
  }

  /// Removes this device's token from the backend and invalidates it on the
  /// device. Must run before the access token is cleared.
  Future<void> unregisterFromBackend() async {
    if (kIsWeb) return;
    signedIn = false;
    if (!_ready) return;
    final t = _registeredToken ?? await getToken();
    if (t != null && t.isNotEmpty) {
      await _post('/v1/auth/fcm-token/remove', {'fcm_token': t});
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    try {
      await _local.cancelAll();
    } catch (_) {}
    _registeredToken = null;
  }

  Future<void> _postToken(String token) async {
    final ok = await _post('/v1/auth/fcm-token', {
      'fcm_token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'device_id': await _installId(),
    });
    if (ok) _registeredToken = token;
  }

  Future<bool> _post(String path, Map<String, dynamic> body) async {
    try {
      final access = await ApiService.getAccessToken();
      if (access == null || access.isEmpty) return false;
      final res = await http
          .post(
            Uri.parse('${ApiService.baseUrl}$path'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $access',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 300) {
        debugPrint('Push $path failed: ${res.statusCode} ${res.body}');
      }
      return res.statusCode < 300;
    } catch (e) {
      debugPrint('Push $path error: $e');
      return false;
    }
  }

  // Stable random id per install, so the backend keeps one token row per phone.
  static const _installIdKey = 'starlink_install_id';
  String? _installIdCache;

  Future<String?> _installId() async {
    if (_installIdCache != null) return _installIdCache;
    try {
      const storage = FlutterSecureStorage();
      var id = await storage.read(key: _installIdKey);
      if (id == null || id.isEmpty) {
        final rnd = Random.secure();
        id =
            List.generate(
              16,
              (_) => rnd.nextInt(256),
            ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        await storage.write(key: _installIdKey, value: id);
      }
      return _installIdCache = id;
    } catch (_) {
      return null;
    }
  }
}
