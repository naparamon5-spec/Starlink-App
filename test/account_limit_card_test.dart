import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/shared/widgets/account_limit_card.dart';

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
      req.response.write(
        json.encode({
          'status': 'success',
          'data': {'limit': 3, 'used': 1, 'isDefault': true},
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

  testWidgets('closing the limit dialog animates out without crashing', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AccountLimitCard(code: 'S-1')),
      ),
    );
    await settle(t);
    await t.tap(find.text('Change limit'));
    await t.pumpAndSettle();

    await t.tap(find.text('Cancel'));
    // Step through the closing transition: the TextField is still built here.
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 30));
    }
    await t.pumpAndSettle();

    expect(find.text('Maximum accounts'), findsNothing);
    expect(t.takeException(), isNull);

    // Let the HTTP client's keep-alive timer run out.
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  });
}
