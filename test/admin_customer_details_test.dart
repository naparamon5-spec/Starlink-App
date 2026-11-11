import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/sections/agent/admin_agent_details_page.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;
  final writes = <String>[];
  var linked = <Map<String, dynamic>>[];

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api', '');
      final body = await utf8.decoder.bind(req).join();
      Object? data = const [];
      if (req.method != 'GET') {
        writes.add('$path $body');
        if (path.contains('/unlink/')) linked = [];
      } else if (path == '/v1/customers/189') {
        data = {
          'id': 189,
          'code': 'S-1',
          'name': '17th TRADING',
          'inactive': 'N',
        };
      } else if (path == '/v1/subscriptions/customer/S-1') {
        data = linked;
      } else if (path == '/v1/users/company/S-1') {
        data = [
          {
            'id': 5,
            'name': 'Pat Santos',
            'email': 'pat@example.com',
            'role': 'customer',
            'inactive': 'N',
          },
        ];
      } else if (path == '/v1/end-user/customer/S-1') {
        data = [
          {'eu_code': 'EU-1', 'eu_name': 'UPLB', 'inactive': 'N'},
        ];
      } else if (path == '/v1/subscriptions/none/customer') {
        data = [
          {'serviceLineNumber': 'SL-NEW', 'nickname': 'NEW LINE'},
          {'serviceLineNumber': 'SL-1', 'nickname': 'ALREADY LINKED'},
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
    linked = [
      {
        'serviceLineNumber': 'SL-1',
        'nickname': 'MAIN LINE',
        'totalPriorityGB': '2.5',
        'dataplan': 50,
        'eu_code': 'EU-1',
        'eu_name': 'UPLB',
        'kit_number': 'KIT1',
        'active': 'Y',
      },
    ];
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
        home: AdminAgentDetailsPage(
          agentId: '189',
          agentCode: 'S-1',
          agentName: '17th TRADING',
        ),
      ),
    );
    await settle(t);
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  }

  testWidgets('shows the customer and linked lines; tabs switch', (t) async {
    await open(t);
    expect(find.text('17th TRADING'), findsOneWidget);
    expect(find.text('S-1'), findsOneWidget);
    expect(find.text('MAIN LINE'), findsOneWidget);
    expect(find.text('2.50 GB / 50 GB'), findsOneWidget);
    expect(find.text('ACTIVE'), findsNWidgets(2));

    await t.tap(find.text('Users'));
    await t.pump();
    expect(find.text('Pat Santos'), findsOneWidget);
    expect(find.text('Customer'), findsWidgets);

    await t.tap(find.text('End Users'));
    await t.pump();
    expect(find.text('EU-1'), findsOneWidget);
    await finish(t);
  });

  testWidgets('links a picked service line with its end user', (t) async {
    await open(t);
    await t.tap(find.text('Link service lines'));
    await settle(t);
    expect(find.text('NEW LINE'), findsOneWidget);
    expect(find.text('ALREADY LINKED'), findsNothing);
    await t.tap(find.text('NEW LINE'));
    await t.pump();
    await t.tap(find.text('Add 1 to assign'));
    await settle(t);
    expect(find.text('Assign end users, then save'), findsOneWidget);
    await t.tap(find.text('Save links'));
    await settle(t);
    expect(writes.single, contains('/v1/subscriptions/link/S-1'));
    expect(writes.single, contains('"serviceLineNumber":"SL-NEW"'));
    expect(find.text('Assign end users, then save'), findsNothing);
    await finish(t);
  });

  testWidgets('unlink asks first, then removes the line', (t) async {
    await open(t);
    await t.tap(find.text('Unlink'));
    await settle(t);
    expect(find.text('Unlink service line?'), findsOneWidget);
    expect(writes, isEmpty);
    await t.tap(find.text('Unlink').last);
    await settle(t);
    expect(writes.single, contains('/v1/subscriptions/unlink/SL-1'));
    expect(find.text('No linked service lines.'), findsOneWidget);
    await finish(t);
  });

  testWidgets('saving end users with no change sends nothing', (t) async {
    await open(t);
    await t.tap(find.text('Edit end users'));
    await t.pump();
    await t.tap(find.text('Save end users'));
    await settle(t);
    expect(writes, isEmpty);
    expect(find.text('Edit end users'), findsOneWidget);
    await finish(t);
  });

  testWidgets('editing end users swaps in Cancel and Save; Cancel backs out', (
    t,
  ) async {
    await open(t);
    expect(find.text('Link service lines'), findsOneWidget);
    await t.tap(find.text('Edit end users'));
    await t.pump();
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save end users'), findsOneWidget);
    expect(find.text('Link service lines'), findsNothing);

    await t.tap(find.text('Cancel'));
    await t.pump();
    expect(find.text('Edit end users'), findsOneWidget);
    expect(find.text('Link service lines'), findsOneWidget);
    expect(writes, isEmpty);
    await finish(t);
  });
}
