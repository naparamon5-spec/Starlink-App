import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/shared/widgets/notifications.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

Map<String, dynamic> _row(
  int id,
  String type,
  String title, {
  String? readAt,
}) => {
  'id': id,
  'type': type,
  'title': title,
  'body': 'Body $id',
  'link': null,
  'data': null,
  'read_at': readAt,
  'created_at': '2026-11-09T01:00:00.000Z',
};

void main() {
  late HttpServer server;
  final requests = <String>[];
  var rows = <Map<String, dynamic>>[];
  var unread = 0;

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api', '');
      requests.add('${req.method} ${req.uri}'.replaceFirst('/api', ''));
      await utf8.decoder.bind(req).join();
      if (req.method == 'PUT') {
        req.response.statusCode = 204;
        await req.response.close();
        return;
      }
      Object? data = const [];
      if (path == '/v1/notifications/unread-count') {
        data = {'count': unread};
      } else if (path == '/v1/notifications') {
        final before = int.tryParse(req.uri.queryParameters['before'] ?? '');
        data =
            rows
                .where((r) => before == null || (r['id'] as int) < before)
                .take(20)
                .toList();
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(
        json.encode({'data': data, 'message': 'Success', 'StatusCode': 200}),
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
    rows = [];
    unread = 0;
    SharedPreferences.setMockInitialValues({
      'accessToken': _jwt(),
      'refreshToken': 'r',
    });
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  }

  testWidgets('the bell shows the unread count from the backend', (t) async {
    unread = 3;
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: NotificationBell())),
    );
    await settle(t);
    expect(find.text('3'), findsOneWidget);
    expect(requests, contains('GET /v1/notifications/unread-count'));
    expect(requests.where((r) => r.contains('announcements')), isEmpty);
    await finish(t);
  });

  testWidgets('lists notifications and marks one read', (t) async {
    rows = [
      _row(2, 'usage_alert', 'Line used 90%'),
      _row(1, 'announcement', 'Maintenance', readAt: '2026-11-09T02:00:00Z'),
    ];
    unread = 1;
    await t.pumpWidget(const MaterialApp(home: NotificationsPage()));
    await settle(t);
    expect(find.text('Line used 90%'), findsOneWidget);
    expect(find.text('USAGE ALERT'), findsOneWidget);
    expect(find.text('1 UNREAD'), findsOneWidget);

    await t.tap(find.text('Line used 90%'));
    await settle(t);
    expect(requests, contains('PUT /v1/notifications/2/read'));
    expect(find.text('ALL CAUGHT UP'), findsOneWidget);
    await finish(t);
  });

  testWidgets('mark all uses the read-all route', (t) async {
    rows = [_row(5, 'ticket_reply', 'New reply on TKT-000005')];
    unread = 4; // More than the page holds.
    await t.pumpWidget(const MaterialApp(home: NotificationsPage()));
    await settle(t);
    expect(find.text('4 UNREAD'), findsOneWidget);
    await t.tap(find.byTooltip('Mark all as read'));
    await settle(t);
    expect(requests, contains('PUT /v1/notifications/read-all'));
    expect(find.byTooltip('Mark all as read'), findsNothing);
    await finish(t);
  });

  testWidgets('load more asks for rows before the last id', (t) async {
    rows = [
      for (var i = 25; i > 0; i--) _row(i, 'announcement', 'Item $i'),
    ];
    await t.pumpWidget(const MaterialApp(home: NotificationsPage()));
    await settle(t);
    await t.scrollUntilVisible(
      find.text('Load more'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Load more'));
    await settle(t);
    expect(
      requests.where((r) => r.contains('before=6')),
      hasLength(1),
    );
    expect(find.text('Load more'), findsNothing);
    await finish(t);
  });
}
