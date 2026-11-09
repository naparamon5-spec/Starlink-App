import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/tools/reports_page.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await utf8.decoder.bind(req).join();
      req.response.headers.contentType = ContentType.json;
      req.response.write(json.encode({'data': const [], 'StatusCode': 200}));
      await req.response.close();
    });
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api',
    );
    SharedPreferences.setMockInitialValues({
      'accessToken': _jwt(),
      'refreshToken': 'r',
    });
  });

  tearDownAll(() => server.close(force: true));

  testWidgets('List and Graph sit right of the usage pills on a phone', (
    t,
  ) async {
    t.view.physicalSize = const Size(375, 812);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(const MaterialApp(home: ReportsPage()));
    for (var i = 0; i < 12; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 100));
    }

    final usage = t.getCenter(find.text('USAGE'));
    expect(find.text('List'), findsNothing);
    expect(find.text('Graph'), findsNothing);
    final list = t.getCenter(find.byTooltip('List'));
    final graph = t.getRect(find.byTooltip('Graph'));
    expect((usage.dy - list.dy).abs(), lessThan(1));
    expect(usage.dx, lessThan(list.dx));
    expect(list.dx, lessThan(graph.center.dx));
    expect(graph.right, lessThanOrEqualTo(375 - 16));
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  });
}
