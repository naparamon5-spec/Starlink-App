import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/sections/enduser/admin_end_user_details_page.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;
  final writes = <String>[];
  var inactive = 'N';

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api', '');
      final body = await utf8.decoder.bind(req).join();
      Object? data = const [];
      if (req.method != 'GET') {
        writes.add('$path $body');
      } else if (path == '/v1/end-user/63674') {
        data = {
          'eu_code': '63674',
          'eu_name': 'Sample Only',
          'customer_code': 'A-4A100426',
          'inactive': inactive,
        };
      } else if (path == '/v1/subscriptions/end-user/63674') {
        data = [
          {
            'serviceLineNumber': 'SL-1',
            'nickname': 'MAIN LINE',
            'totalPriorityGB': '1',
            'dataplan': 25,
            'kit_number': 'KIT1',
            'active': 'Y',
          },
        ];
      } else if (path == '/v1/users/company/63674') {
        data = [
          {
            'id': 9,
            'name': 'Pat Santos',
            'email': 'pat@x.com',
            'role': 'end_user',
            'position': 'Manager',
            'inactive': 'N',
          },
        ];
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
    inactive = 'N';
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

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      const MaterialApp(
        home: AdminEndUserDetailsPage(
          endUserId: '63674',
          endUserCode: '63674',
          endUserName: 'Sample Only',
        ),
      ),
    );
    await settle(t);
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  }

  testWidgets('shows name, codes, lines and users', (t) async {
    await open(t);
    expect(find.text('Sample Only'), findsOneWidget);
    expect(find.textContaining('A-4A100426'), findsOneWidget);
    expect(find.text('MAIN LINE'), findsOneWidget);
    expect(find.text('1.00 GB / 25 GB'), findsOneWidget);
    await t.tap(find.text('Users'));
    await t.pump();
    expect(find.text('Pat Santos'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Add user'), findsOneWidget);
    await finish(t);
  });

  testWidgets('deactivate asks first, then shows Activate', (t) async {
    await open(t);
    await t.tap(find.text('Deactivate'));
    await settle(t);
    expect(writes, isEmpty);
    await t.tap(find.text('Deactivate').last);
    await settle(t);
    expect(writes.single, contains('/v1/end-user/deactivate/63674'));
    expect(find.text('Activate'), findsOneWidget);
    await finish(t);
  });

  testWidgets('rename saves the new name', (t) async {
    await open(t);
    await t.tap(find.byTooltip('Rename'));
    await settle(t);
    await t.enterText(find.byType(TextField), 'NEW NAME');
    await t.tap(find.text('Save'));
    await settle(t);
    expect(writes.single, contains('/v1/end-user/name/63674'));
    expect(writes.single, contains('NEW NAME'));
    expect(find.text('NEW NAME'), findsOneWidget);
    await finish(t);
  });
}
