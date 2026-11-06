import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/sections/agent/admin_agents_page.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;
  final requests = <Uri>[];

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      requests.add(req.uri);
      await utf8.decoder.bind(req).join();
      final page = int.parse(req.uri.queryParameters['page'] ?? '1');
      final search = req.uri.queryParameters['search'] ?? '';
      req.response.headers.contentType = ContentType.json;
      req.response.write(
        json.encode({
          'status': 'success',
          'data': {
            'data':
                search == 'nothing'
                    ? []
                    : [
                      for (var i = 0; i < 10; i++)
                        {
                          'id': '$page$i',
                          'code': 'CODE-$page-$i',
                          'name': 'COMPANY $page $i',
                          'inactive': i == 1 ? 'Y' : 'N',
                        },
                    ],
            'pagination': {'totalPages': 2, 'totalItems': 20},
          },
        }),
      );
      await req.response.close();
    });
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api',
    );
  });

  tearDownAll(() => server.close(force: true));

  setUp(() {
    requests.clear();
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
  }

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: AdminAgentsPage()));
    await settle(t);
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  }

  testWidgets('shows customer cards with code, company and status', (t) async {
    await open(t);
    expect(find.text('20 customers'), findsOneWidget);
    expect(find.text('CODE-1-0'), findsOneWidget);
    expect(find.text('COMPANY 1 0'), findsOneWidget);
    expect(find.text('ACTIVE'), findsWidgets);
    expect(find.text('INACTIVE'), findsOneWidget);
    expect(find.text('New Customer'), findsOneWidget);
    await finish(t);
  });

  testWidgets('scrolling down loads the next page', (t) async {
    await open(t);
    await t.drag(find.byType(ListView), const Offset(0, -1200));
    await settle(t);
    expect(requests.last.queryParameters['page'], '2');
    await t.drag(find.byType(ListView), const Offset(0, -1400));
    await settle(t);
    expect(find.text('CODE-2-9'), findsOneWidget);
    await finish(t);
  });

  testWidgets('search asks the server for page 1', (t) async {
    await open(t);
    await t.enterText(find.byType(TextField), 'nothing');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    expect(requests.last.queryParameters['search'], 'nothing');
    expect(requests.last.queryParameters['page'], '1');
    expect(find.text('No customers found.'), findsOneWidget);
    await finish(t);
  });
}
