import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/auth/two_factor/two_factor_settings_card.dart';
import 'package:starlink_app/features/security/biometric_settings_card.dart';
import 'package:starlink_app/features/security/security_page.dart';
import 'package:starlink_app/features/auth/login_screen.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/services/biometric_service.dart';
import 'package:starlink_app/shared/widgets/background_sign_out.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

class _FakeAuth implements LocalAuthentication {
  bool supported = true;
  bool answer = true;
  int prompts = 0;
  List<BiometricType> types = [BiometricType.fingerprint];

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => types;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    prompts++;
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late HttpServer server;
  late _FakeAuth auth;
  var status = <String, dynamic>{'enabled': false, 'required': false};
  final writes = <String>[];
  String? logoutCookie;
  var refreshStatus = 200;
  String? changePasswordCookie;

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      final path = req.uri.path.replaceFirst('/api', '');
      if (req.method != 'GET') writes.add('$path $body');
      req.response.headers.contentType = ContentType.json;
      if (path == '/v1/auth/logout') {
        logoutCookie = req.headers.value('cookie');
        req.response.statusCode = 204;
        await req.response.close();
        return;
      }
      if (path == '/v1/auth/refresh') {
        req.response.statusCode = refreshStatus;
        req.response.write(json.encode({'accessToken': 'a2'}));
        await req.response.close();
        return;
      }
      if (path == '/v1/auth/login') {
        final password = (json.decode(body) as Map)['password'];
        if (password == 'good2fa') {
          req.response.write(
            json.encode({
              'status': 'success',
              'data': {'userId': 1, 'flag': false, 'setupRequired': false},
            }),
          );
          await req.response.close();
          return;
        }
        final good = password == 'good';
        if (good) {
          req.response.headers.add(
            'set-cookie',
            'refreshToken=issued; Path=/api/v1/auth; HttpOnly',
          );
        } else {
          req.response.statusCode = 401;
        }
        req.response.write(
          json.encode(
            good
                ? {
                  'status': 'success',
                  'data': {
                    'accessToken': 'a1',
                    'user': {'id': 1, 'email': 'me@example.com'},
                  },
                }
                : {'message': 'Invalid credentials'},
          ),
        );
        await req.response.close();
        return;
      }
      if (path == '/v1/auth/change-password') {
        changePasswordCookie = req.headers.value('cookie');
        req.response.statusCode = 204;
        await req.response.close();
        return;
      }
      if (path == '/v1/auth/me') {
        req.response.write(
          json.encode({
            'status': 'success',
            'data': {'id': 1, 'email': 'me@example.com', 'role': 'admin'},
          }),
        );
        await req.response.close();
        return;
      }
      if (path == '/v1/auth/2fa/disable') {
        status = {...status, 'enabled': false};
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(json.encode({'status': 'success', 'data': status}));
      await req.response.close();
    });
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api',
    );
  });

  tearDownAll(() => server.close(force: true));

  setUp(() {
    writes.clear();
    logoutCookie = null;
    refreshStatus = 200;
    FlutterSecureStorage.setMockInitialValues({});
    status = {'enabled': false, 'required': false};
    auth = _FakeAuth();
    BiometricService.authForTesting = auth;
    SharedPreferences.setMockInitialValues({
      'accessToken': _jwt(),
      'refreshToken': 'r',
    });
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  }

  Future<void> show(WidgetTester t, Widget child) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await settle(t);
  }

  Switch theSwitch(WidgetTester t) => t.widget<Switch>(find.byType(Switch));

  group('two-factor switch', () {
    testWidgets('reflects the backend and offers no re-link when off', (
      t,
    ) async {
      await show(t, const TwoFactorSettingsCard());
      expect(theSwitch(t).value, isFalse);
      expect(find.text('Link a new phone'), findsNothing);
      await finish(t);
    });

    testWidgets('is locked on when the role requires it', (t) async {
      status = {'enabled': true, 'required': true};
      await show(t, const TwoFactorSettingsCard());
      expect(theSwitch(t).value, isTrue);
      expect(theSwitch(t).onChanged, isNull);
      await finish(t);
    });

    testWidgets('cancelling the turn-off dialog changes nothing', (t) async {
      status = {'enabled': true, 'required': false};
      await show(t, const TwoFactorSettingsCard());
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 30));
      }
      await t.pumpAndSettle();
      expect(writes, isEmpty);
      expect(theSwitch(t).value, isTrue);
      await finish(t);
    });

    testWidgets('a code turns it off through the real endpoint', (t) async {
      status = {'enabled': true, 'required': false};
      await show(t, const TwoFactorSettingsCard());
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, '123456');
      await settle(t);
      expect(writes.single, '/v1/auth/2fa/disable {"code":"123456"}');
      expect(theSwitch(t).value, isFalse);
      await t.pump(const Duration(seconds: 6));
      await finish(t);
    });
  });

  testWidgets('the Security page builds without framework errors', (t) async {
    await show(t, const SecurityPage());
    expect(t.takeException(), isNull);
    expect(find.text('Change password'), findsOneWidget);
    await finish(t);
  });

  group('biometric login switch', () {
    Future<void> confirm(WidgetTester t, String password) async {
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, password);
      await t.tap(find.textContaining('Confirm &'));
      await settle(t);
    }

    testWidgets('needs the right password, then saves the session', (t) async {
      await show(t, const BiometricSettingsCard());
      await confirm(t, 'wrong');
      expect(await t.runAsync(BiometricService.isEnrolled), isFalse);
      await t.tap(find.text('OK'));
      await settle(t);

      await confirm(t, 'good');
      expect(theSwitch(t).value, isTrue);
      expect(await t.runAsync(BiometricService.savedEmail), 'me@example.com');
      expect(await t.runAsync(BiometricService.savedRefreshToken), 'issued');
      await t.pump(const Duration(seconds: 6));
      await finish(t);
    });

    testWidgets('with 2FA on, the password alone is enough', (t) async {
      await show(t, const BiometricSettingsCard());
      await confirm(t, 'good2fa');
      expect(theSwitch(t).value, isTrue);
      expect(await t.runAsync(BiometricService.savedRefreshToken), 'r');
      await t.pump(const Duration(seconds: 6));
      await finish(t);
    });

    testWidgets('a password change turns it off, and the switch follows', (
      t,
    ) async {
      await t.runAsync(() => BiometricService.enroll('me@example.com', 'r'));
      await show(t, const BiometricSettingsCard());
      expect(theSwitch(t).value, isTrue);

      await t.runAsync(
        () => ApiService.changePassword(oldPassword: 'a', newPassword: 'b'),
      );
      await settle(t);
      expect(await t.runAsync(BiometricService.isEnrolled), isFalse);
      expect(theSwitch(t).value, isFalse);
      expect(changePasswordCookie, contains('refreshToken=r'));
      await finish(t);
    });

    testWidgets('is disabled on a device with no screen lock', (t) async {
      auth.supported = false;
      await show(t, const BiometricSettingsCard());
      expect(theSwitch(t).onChanged, isNull);
      await finish(t);
    });
  });

  group('sign-in method', () {
    Future<BiometricMethod?> best(WidgetTester t, List<BiometricType> types) {
      auth.types = types;
      return t.runAsync(BiometricService.bestMethod);
    }

    testWidgets('prefers face, then fingerprint, then PIN', (t) async {
      expect(
        await best(t, [BiometricType.fingerprint, BiometricType.face]),
        BiometricMethod.face,
      );
      expect(
        await best(t, [BiometricType.fingerprint]),
        BiometricMethod.fingerprint,
      );
      expect(await best(t, const []), BiometricMethod.pin);
    });

    testWidgets('login shows the panel, with password as the way out', (
      t,
    ) async {
      auth.types = [BiometricType.face];
      await t.runAsync(() => BiometricService.enroll('me@example.com', 'r1'));
      await t.pumpWidget(const MaterialApp(home: LoginScreen()));
      await settle(t);
      expect(find.text('Tap to sign in with Face ID'), findsOneWidget);
      expect(find.text('me@example.com'), findsOneWidget);

      await t.ensureVisible(find.text('Enter password'));
      await t.pump();
      await t.tap(find.text('Enter password'));
      await settle(t);
      expect(find.text('Use biometrics instead'), findsOneWidget);
      await finish(t);
    });
  });

  testWidgets('with no device lock at all, login is the password form', (
    t,
  ) async {
    auth
      ..types = const []
      ..supported = false;
    await t.runAsync(() => BiometricService.enroll('me@example.com', 'r1'));
    await t.pumpWidget(const MaterialApp(home: LoginScreen()));
    await settle(t);
    expect(find.textContaining('Tap to sign in'), findsNothing);
    expect(find.text('Use biometrics instead'), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await finish(t);
  });

  testWidgets('with only a device PIN, login offers the PIN', (t) async {
    auth.types = const [];
    await t.runAsync(() => BiometricService.enroll('me@example.com', 'r1'));
    await t.pumpWidget(const MaterialApp(home: LoginScreen()));
    await settle(t);
    expect(find.text('Tap to sign in with PIN code'), findsOneWidget);
    await finish(t);
  });

  group('saved session', () {
    testWidgets('logout keeps the session biometric login relies on', (
      t,
    ) async {
      await t.runAsync(() async {
        await BiometricService.enroll('me@example.com', 'r');
        await ApiService.logout();
      });
      expect(logoutCookie, isNull);
      expect(await t.runAsync(BiometricService.isEnrolled), isTrue);
    });

    testWidgets('logout still ends the session when it is off', (t) async {
      await t.runAsync(ApiService.logout);
      expect(logoutCookie, contains('refreshToken=r'));
    });

    testWidgets('the saved token follows each rotation', (t) async {
      await t.runAsync(() async {
        await BiometricService.enroll('me@example.com', 'old');
        await ApiService.setRefreshToken('new');
      });
      expect(await t.runAsync(BiometricService.savedRefreshToken), 'new');
    });

    testWidgets('someone else signing in removes the enrollment', (t) async {
      await t.runAsync(() async {
        await BiometricService.enroll('me@example.com', 'r');
        await BiometricService.handleSignIn('other@example.com');
      });
      expect(await t.runAsync(BiometricService.isEnrolled), isFalse);
    });

    testWidgets('a revoked token ends enrollment and leaves no tokens', (
      t,
    ) async {
      refreshStatus = 401;
      final result = await t.runAsync(() async {
        await BiometricService.enroll('me@example.com', 'dead');
        return ApiService.restoreBiometricSession();
      });
      expect(result!['expired'], isTrue);
      expect(await t.runAsync(BiometricService.isEnrolled), isFalse);
      expect(await t.runAsync(ApiService.getRefreshToken), isNull);
    });
  });

  group('time away', () {
    Future<void> pumpGuard(WidgetTester t, VoidCallback onExpired) async {
      await t.pumpWidget(
        BackgroundSignOut(
          timeout: Duration.zero,
          onExpired: () async => onExpired(),
          child: const SizedBox(),
        ),
      );
    }

    Future<void> leaveAndReturn(WidgetTester t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
    }

    testWidgets('signs out when biometric login is on', (t) async {
      await t.runAsync(() => BiometricService.enroll('me@example.com', 'r'));
      var expired = false;
      await pumpGuard(t, () => expired = true);
      await leaveAndReturn(t);
      expect(expired, isTrue);
      await finish(t);
    });

    testWidgets('leaves everyone else alone', (t) async {
      var expired = false;
      await pumpGuard(t, () => expired = true);
      await leaveAndReturn(t);
      expect(expired, isFalse);
      await finish(t);
    });
  });
}
