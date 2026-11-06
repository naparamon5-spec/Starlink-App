import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/profile/admin_edit_profile_page.dart';
import 'package:starlink_app/features/auth/change_password.dart';
import 'package:starlink_app/shared/widgets/password_checklist.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;
  final writes = <String>[];

  setUpAll(() async {
    HttpOverrides.global = null;
    PackageInfo.setMockInitialValues(
      appName: 'a',
      packageName: 'p',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api', '');
      final body = await utf8.decoder.bind(req).join();
      Object? data = const {};
      if (req.method != 'GET') {
        writes.add('$path $body');
      } else if (path == '/v1/users/my/profile/') {
        data = {
          'id': 7,
          'name': 'Ramon Napa',
          'email': 'r@example.com',
          'role': 'admin',
          'first_name': 'Ramon',
          'middle_name': null,
          'last_name': 'Napa',
          'position': 'Employee',
          'company_name': null,
        };
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(json.encode({'status': 'success', 'data': data}));
      await req.response.close();
    });
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api',
    );
  });

  tearDownAll(() => server.close(force: true));

  setUp(() {
    writes.clear();
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

  Future<void> open(WidgetTester t, Widget page) async {
    t.view.physicalSize = const Size(320, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => page),
                      ),
                  child: const Text('go'),
                ),
              ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await settle(t);
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  }

  test('password rules match the web portal', () {
    expect(passwordMeetsRules('Abcdef1!', 'Abcdef1!'), isTrue);
    expect(passwordMeetsRules('Abcdef1!', 'different'), isFalse);
    expect(passwordMeetsRules('abcdef1!', 'abcdef1!'), isFalse); // No upper.
    expect(passwordMeetsRules('ABCDEF1!', 'ABCDEF1!'), isFalse); // No lower.
    expect(passwordMeetsRules('Abcdefg!', 'Abcdefg!'), isFalse); // No number.
    expect(passwordMeetsRules('Abcdefg1', 'Abcdefg1'), isFalse); // No special.
    expect(passwordMeetsRules('Ab1!', 'Ab1!'), isFalse); // Too short.
    expect(passwordMeetsRules('', ''), isFalse);
  });

  group('Edit Profile', () {
    testWidgets('shows who you are and saves your details', (t) async {
      await open(t, const AdminEditProfilePage());
      expect(find.text('Ramon Napa'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('COMPANY'), findsOneWidget);
      await t.enterText(find.byType(TextFormField).at(1), 'Cruz');
      await t.pump();
      await t.tap(find.text('Save details'));
      await settle(t);
      expect(writes.single, contains('/v1/users/7'));
      expect(writes.single, contains('"middle_name":"Cruz"'));
      await finish(t);
    });

    testWidgets('names are required', (t) async {
      await open(t, const AdminEditProfilePage());
      await t.enterText(find.byType(TextFormField).at(0), ' ');
      await t.pump();
      await t.tap(find.text('Save details'));
      await t.pump();
      expect(find.text('First name is required.'), findsOneWidget);
      expect(writes, isEmpty);
      await finish(t);
    });
  });

  group('Change Password', () {
    testWidgets('a weak password is refused before sending', (t) async {
      await open(t, const AdminChangePasswordPage());
      expect(find.text('One special character'), findsOneWidget);
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'old-pass');
      await t.enterText(fields.at(1), 'weak');
      await t.enterText(fields.at(2), 'weak');
      await t.pump();
      await t.tap(find.text('Update password'));
      await t.pump();
      expect(find.textContaining('meet every requirement'), findsOneWidget);
      expect(writes, isEmpty);
      await finish(t);
    });

    testWidgets('a strong password is sent', (t) async {
      await open(t, const AdminChangePasswordPage());
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'old-pass');
      await t.enterText(fields.at(1), 'Abcdef1!');
      await t.enterText(fields.at(2), 'Abcdef1!');
      await t.pump();
      await t.tap(find.text('Update password'));
      await settle(t);
      expect(writes.single, contains('change-password'));
      expect(writes.single, contains('Abcdef1!'));
      await finish(t);
    });
  });
}
