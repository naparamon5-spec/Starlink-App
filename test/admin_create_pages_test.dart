import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/sections/agent/admin_create_agent_page.dart';
import 'package:starlink_app/features/admin/sections/enduser/admin_create_end_user_page.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;
  final posts = <String>[];

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api', '');
      final body = await utf8.decoder.bind(req).join();
      Object? data = const [];
      if (req.method == 'POST') {
        posts.add('$path $body');
      } else if (path == '/v1/customers/list/all') {
        data = [
          {'label': 'ARDENT NETWORKS INC', 'value': 'A-1'},
        ];
      } else if (path == '/external/list/customer') {
        data = [
          {'label': 'ARDENT NETWORKS INC', 'value': 'A-1'},
          {'label': '108 ENTERPRISES INC.', 'value': '1-4A160002'},
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
    posts.clear();
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

  /// Opens [page] from a home screen, so it has somewhere to pop to.
  Future<void> open(WidgetTester t, Widget page) async {
    t.view.physicalSize = const Size(320, 1000);
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

  group('New End Users', () {
    testWidgets('an incomplete row is flagged, not sent', (t) async {
      await open(t, const AdminCreateEndUserPage());
      await t.enterText(find.byType(TextField), 'Sample Only');
      await t.pump();
      await t.tap(find.text('Create end users'));
      await t.pump();
      expect(find.text('Select a customer'), findsOneWidget);
      expect(posts, isEmpty);
      await finish(t);
    });

    testWidgets('an empty form asks for at least one', (t) async {
      await open(t, const AdminCreateEndUserPage());
      await t.tap(find.text('Create end users'));
      await t.pump();
      expect(
        find.text('Add at least one end user with a name and customer.'),
        findsOneWidget,
      );
      await finish(t);
    });

    testWidgets('sends every filled row and skips blank ones', (t) async {
      await open(t, const AdminCreateEndUserPage(initialCustomerCode: 'A-1'));
      await t.tap(find.text('Add another'));
      await t.pump();
      await t.tap(find.text('Add another'));
      await t.pump();
      await t.enterText(find.byType(TextField).at(0), 'One');
      await t.enterText(find.byType(TextField).at(1), 'Two');
      await t.pump();
      await t.tap(find.text('Create end users'));
      await settle(t);
      expect(posts.single, startsWith('/v1/end-user/ '));
      final body = json.decode(posts.single.split(' ').skip(1).join(' '));
      expect(body['formData'], [
        {'eu_name': 'One', 'customer_code': 'A-1'},
        {'eu_name': 'Two', 'customer_code': 'A-1'},
      ]);
      await finish(t);
    });

    testWidgets('leaving with text asks first', (t) async {
      await open(t, const AdminCreateEndUserPage());
      await t.enterText(find.byType(TextField), 'One');
      await t.pump();
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(find.text('Discard changes?'), findsOneWidget);
      await finish(t);
    });
  });

  group('New Customers', () {
    testWidgets('create is off until a company is added', (t) async {
      await open(t, const AdminCreateAgentPage());
      expect(find.text('No customers added yet'), findsOneWidget);
      final button = t.widget<FilledButton>(
        find.ancestor(
          of: find.text('Create customers'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      await finish(t);
    });

    testWidgets('picks from the directory and creates them', (t) async {
      await open(t, const AdminCreateAgentPage());
      await t.tap(find.text('Add from directory'));
      await settle(t);
      // Already a customer, so not offered.
      expect(find.text('ARDENT NETWORKS INC'), findsNothing);
      await t.tap(find.text('108 ENTERPRISES INC.'));
      await t.pump();
      expect(find.text('1 selected'), findsOneWidget);
      await t.tap(find.text('Add selected'));
      await settle(t);
      expect(find.text('No customers added yet'), findsNothing);
      expect(find.text('1-4A160002'), findsOneWidget);
      await t.tap(find.text('Create 1 customer'));
      await settle(t);
      expect(posts.single, startsWith('/v1/customers/ '));
      final body = json.decode(posts.single.split(' ').skip(1).join(' '));
      expect(body['formData'], [
        {
          'customer_code': '1-4A160002',
          'customer_name': '108 ENTERPRISES INC.',
        },
      ]);
      await finish(t);
    });
  });
}
