import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/features/admin/sections/subscription/admin_subscriptions_page.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;
  final queries = <Map<String, String>>[];

  setUpAll(() async {
    HttpOverrides.global = null;
    final loader = FontLoader(AppTheme.fontFamily);
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final bytes = File('assets/fonts/Montserrat-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await utf8.decoder.bind(req).join();
      if (req.uri.path.endsWith('/subscriptions/paginated')) {
        queries.add(req.uri.queryParameters);
      }
      final page = int.tryParse(req.uri.queryParameters['page'] ?? '1') ?? 1;
      final near = req.uri.queryParameters['near_limit'] == '1';
      req.response.headers.contentType = ContentType.json;
      req.response.write(
        json.encode({
          'status': 'success',
          'data': {
            'data':
                page > 1
                    ? const []
                    : [
                      {
                        'serviceLineNumber': near ? 'SL-NEAR' : 'SL-ALL',
                        'nickname': near ? 'NEAR LINE' : 'ANY LINE',
                        'kit_number': 'KIT',
                      },
                    ],
            'pagination': {
              'currentPage': page,
              'totalPages': 1,
              'totalItems': near ? 7 : 1872,
            },
          },
        }),
      );
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

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('on a phone the controls keep their full size', (t) async {
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AdminSubscriptionsPage()),
      ),
    );
    await settle(t);

    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.text('1872'), findsOneWidget);
    // Nothing was shrunk to fit, and the dropdown is at the right edge.
    expect(t.getRect(find.byType(Switch)).width, greaterThan(36));
    final dropdown = t.getRect(find.byType(AppSelect<int>));
    expect(dropdown.width, closeTo(132, 0.5));
    expect(dropdown.right, closeTo(402 - 16, 0.5));

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  });

  testWidgets('the 90%+ toggle filters the list and the export', (t) async {
    queries.clear();
    final export = ListExportController();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminSubscriptionsPage(exportController: export)),
      ),
    );
    await settle(t);
    expect(find.text('ANY LINE'), findsOneWidget);
    expect(find.text('1872'), findsOneWidget);

    // The switch and dropdown share the first row; the count is below it.
    final switchAt = t.getCenter(find.text('90%+ data usage'));
    final dropdownAt = t.getCenter(find.text('10 per page'));
    final titleAt = t.getCenter(find.text('Subscriptions'));
    expect(switchAt.dy, closeTo(dropdownAt.dy, 2));
    expect(switchAt.dx, lessThan(dropdownAt.dx));
    expect(titleAt.dy, greaterThan(dropdownAt.dy));
    expect(titleAt.dx, lessThan(dropdownAt.dx));
    expect(t.getCenter(find.text('1872')).dy, closeTo(titleAt.dy, 3));
    expect(queries.last.containsKey('near_limit'), isFalse);

    await t.tap(find.text('90%+ data usage'));
    await settle(t);
    expect(queries.last['near_limit'], '1');
    expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(queries.last['page'], '1');
    expect(find.text('NEAR LINE'), findsOneWidget);
    expect(find.text('ANY LINE'), findsNothing);
    expect(find.text('7'), findsOneWidget);

    final rows = await t.runAsync(() => export.loader!());
    expect(rows!.single['serviceLineNumber'], 'SL-NEAR');

    await t.tap(find.text('90%+ data usage'));
    await settle(t);
    expect(find.text('ANY LINE'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  });
}
