import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/profile/view-user/admin_view_user_details_page.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;
  final writes = <String>[];
  var myRole = 'admin';
  var position = 'Programmer';

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api', '');
      final body = await utf8.decoder.bind(req).join();
      Object? data = const {};
      if (req.method != 'GET') {
        writes.add('$path $body');
        if (path == '/v1/users/10') position = json.decode(body)['position'];
      } else if (path.contains('/auth/me')) {
        data = {'id': 1, 'role': myRole};
      } else if (path == '/v1/auth/user/mfa-status/10') {
        data = {'enabled': true, 'enabled_at': null, 'required': false};
      } else if (path == '/v1/users/10') {
        data = {
          'id': 10,
          'name': 'Mark Canal',
          'email': 'mark@example.com',
          'role': 'admin',
          'company_name': 'ARDENT NETWORKS INC',
          'first_name': 'Mark',
          'middle_name': null,
          'last_name': 'Canal',
          'position': position,
          'inactive': 'N',
        };
      } else if (path == '/v1/users/1') {
        data = {
          'id': 1,
          'name': 'Me Myself',
          'email': 'me@example.com',
          'role': 'admin',
          'first_name': 'Me',
          'last_name': 'Myself',
          'inactive': 'N',
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
    myRole = 'admin';
    position = 'Programmer';
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

  Future<void> open(WidgetTester t, String id) async {
    t.view.physicalSize = const Size(320, 1300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: AdminUserDetailPage(userId: id)));
    await settle(t);
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  }

  testWidgets('admins see details, status and security', (t) async {
    await open(t, '10');
    expect(find.text('Mark Canal'), findsOneWidget);
    expect(find.text('ARDENT NETWORKS INC'), findsOneWidget);
    expect(find.text('Deactivate'), findsOneWidget);
    await t.ensureVisible(find.text('Two-step verification'));
    await t.pump();
    expect(find.text('Two-step verification'), findsOneWidget);
    expect(find.text('ON'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    expect(find.text('Set password'), findsOneWidget);
    await finish(t);
  });

  testWidgets('saving sends the edits and leaves nothing unsaved', (t) async {
    await open(t, '10');
    await t.enterText(find.byType(TextField).at(3), 'Lead');
    await t.pump();
    await t.tap(find.text('Save changes'));
    await settle(t);
    expect(writes.single, contains('/v1/users/10'));
    expect(writes.single, contains('"position":"Lead"'));
    expect(find.text('Lead'), findsOneWidget);
    await finish(t);
  });

  testWidgets('names are required', (t) async {
    await open(t, '10');
    await t.enterText(find.byType(TextField).at(0), ' ');
    await t.pump();
    await t.tap(find.text('Save changes'));
    await t.pump();
    expect(find.text('First and last name are required.'), findsOneWidget);
    expect(writes, isEmpty);
    await finish(t);
  });

  testWidgets('Set password needs every rule, then sends it', (t) async {
    await open(t, '10');
    await t.tap(find.text('Set password'));
    await settle(t);
    final fields = find.byType(TextField);
    await t.enterText(fields.at(fields.evaluate().length - 2), 'Abcdef1!');
    await t.enterText(fields.last, 'Abcdef1!');
    await t.pump();
    await t.tap(find.text('Set password').last);
    await settle(t);
    expect(writes.single, contains('/v1/auth/user/set-password/10'));
    expect(writes.single, contains('Abcdef1!'));
    await finish(t);
  });

  testWidgets('your own account has no status or admin password tools', (
    t,
  ) async {
    await open(t, '1');
    expect(find.text('Deactivate'), findsNothing);
    expect(find.text('Send reset link'), findsNothing);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    await finish(t);
  });

  testWidgets('agents get a read-only view of staff accounts', (t) async {
    myRole = 'agent';
    await open(t, '10');
    expect(find.text('Save changes'), findsNothing);
    expect(find.text('Only admins can change staff accounts.'), findsOneWidget);
    expect(find.text('Deactivate'), findsNothing);
    await finish(t);
  });
}
