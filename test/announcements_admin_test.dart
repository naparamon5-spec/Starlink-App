import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/tools/announcements_admin_page.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;
  final writes = <String>[];

  const live = {
    'id': 1,
    'title': 'Welcome to the portal',
    'body': 'First line\nSee https://example.com/help for more',
    'category': 'feature',
    'audience': 'all',
    'pinned': true,
    'status': 'live',
    'author': 'Pat',
    'created_at': '2026-10-05T01:00:00.000Z',
    'read': false,
  };
  const expired = {
    'id': 2,
    'title': 'Old notice',
    'body': 'Gone',
    'category': 'maintenance',
    'audience': 'staff',
    'pinned': false,
    'status': 'expired',
    'author': null,
    'created_at': '2026-01-05T01:00:00.000Z',
  };

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api', '');
      final body = await utf8.decoder.bind(req).join();
      Object? data = const [];
      if (req.method != 'GET') {
        writes.add('${req.method} $path $body');
      } else if (path == '/v1/announcements/feed') {
        data = [live];
      } else if (path == '/v1/announcements' || path == '/v1/announcements/') {
        data = [live, expired];
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

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: AnnouncementsAdminPage()));
    await settle(t);
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  }

  test('the Manage date range reads like the website', () {
    expect(announcementRange(const {}), 'Right away → no end date');
  });

  testWidgets('the feed shows the announcement and marks it seen', (t) async {
    await open(t);
    expect(find.text('Welcome to the portal'), findsOneWidget);
    expect(find.text('NEW FEATURE'), findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('https://example.com/help'), findsOneWidget);
    expect(writes.single, contains('/v1/announcements/read'));
    expect(writes.single, contains('"ids":[1]'));
    await finish(t);
  });

  testWidgets('the editor previews, checks and publishes', (t) async {
    t.view.physicalSize = const Size(320, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnnouncementEditorPage(),
                      ),
                    ),
                child: const Text('go'),
              ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await settle(t);
    // Starts like the website: a new feature, with a placeholder preview.
    expect(find.text('New feature'), findsOneWidget);
    expect(find.text('NEW FEATURE'), findsOneWidget);
    expect(find.text('Your announcement appears here.'), findsOneWidget);
    expect(find.text('0 / 5,000'), findsOneWidget);

    await t.tap(find.text('Publish'));
    await t.pump();
    expect(find.text('Enter a title'), findsOneWidget);
    expect(find.text('Write the announcement'), findsOneWidget);
    expect(writes, isEmpty);

    await t.enterText(find.byType(TextFormField).first, 'Big news');
    await t.enterText(find.byType(TextFormField).last, 'Hello there');
    await t.pump();
    expect(find.text('Big news'), findsNWidgets(2)); // Field and preview.
    expect(find.text('11 / 5,000'), findsOneWidget);

    await t.tap(find.text('Publish'));
    await settle(t);
    expect(writes.single, contains('POST /v1/announcements'));
    expect(writes.single, contains('"title":"Big news"'));
    expect(writes.single, contains('"category":"feature"'));
    await finish(t);
  });

  testWidgets('Manage shows every status with edit and delete', (t) async {
    await open(t);
    await t.tap(find.text('Manage'));
    await t.pump();
    expect(find.text('Old notice'), findsOneWidget);
    expect(find.text('EXPIRED'), findsOneWidget);
    expect(find.text('Staff only'), findsOneWidget);
    expect(find.text('Edit'), findsNWidgets(2));
    await t.tap(find.text('Delete').last);
    await settle(t);
    expect(find.text('Delete this announcement?'), findsOneWidget);
    await finish(t);
  });
}
