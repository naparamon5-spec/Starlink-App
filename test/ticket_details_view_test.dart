import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/ticket/ticket_details_view.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;
  var status = 'open';
  var flag = true;
  final writes = <String>[];
  final comments = <Map<String, dynamic>>[];

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api', '');
      final body = await utf8.decoder.bind(req).join();
      Object? data = const [];
      if (req.method != 'GET') {
        writes.add('${req.method} $path $body');
        if (path.contains('accept-ticket')) status = 'in_progress';
        if (path.contains('/resolved/')) status = 'resolved';
        if (path.contains('/closed/')) status = 'closed';
        if (path == '/v1/activities') {
          comments.add({
            'id': comments.length + 1,
            'user_id': 1,
            'name': 'Me',
            'comment': json.decode(body)['comment'],
            'date': '2026-11-06T01:00:00.000Z',
          });
          data = comments.last;
        }
      } else if (path == '/v1/tickets/7') {
        data = {
          'id': 7,
          'subject': 'LINE-1 - Billing',
          'description': 'help',
          'status': status,
          'ticket_type': 'Billing',
          'created_by': 'Pat Santos',
          'created_at': '2026-11-04T05:23:00.000Z',
          'flag': flag,
          'timeline': const [],
        };
      } else if (path == '/v1/activities/7') {
        data = comments;
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
    status = 'open';
    flag = true;
    writes.clear();
    comments.clear();
    SharedPreferences.setMockInitialValues({
      'accessToken': _jwt(),
      'refreshToken': 'r',
      'user_id': 1,
    });
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(seconds: 5));
    await t.pump(const Duration(seconds: 1));
  }

  /// Opens the ticket from a home page and records what it pops with.
  Future<List<Object?>> open(WidgetTester t) async {
    final popped = <Object?>[];
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => const TicketDetailsView(ticketId: '7'),
                        ),
                      ).then(popped.add),
                  child: const Text('go'),
                ),
              ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await settle(t);
    return popped;
  }

  testWidgets('staff accept, message, and leave with the new status', (
    t,
  ) async {
    final popped = await open(t);
    expect(find.text('TKT-000007'), findsOneWidget);
    expect(find.text('Resolve'), findsNothing);
    expect(
      find.text('Accept the ticket to start the conversation'),
      findsOneWidget,
    );

    await t.tap(find.text('Accept'));
    await settle(t);
    expect(writes.single, startsWith('PUT /v1/tickets/accept-ticket/7'));
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('Resolve'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'On it');
    await t.pump();
    await t.tap(find.byIcon(Icons.send_rounded));
    await settle(t);
    expect(writes.last, contains('POST /v1/activities'));
    expect(writes.last, contains('"comment":"On it"'));
    expect(find.text('On it'), findsOneWidget);
    expect(find.text('Me'), findsNothing); // Shown as "Me (You)".
    expect(find.textContaining('(You)', findRichText: true), findsOneWidget);

    await t.tap(find.byType(BackButton));
    await settle(t);
    expect(popped.single, {'id': '7', 'status': 'IN PROGRESS'});
    await t.pump(const Duration(seconds: 20)); // Idle HTTP connection.
  });

  testWidgets('leaving with an unsent message asks first', (t) async {
    status = 'in_progress';
    final popped = await open(t);
    await t.enterText(find.byType(TextField), 'draft');
    await t.pump();
    await t.tap(find.byType(BackButton));
    await settle(t);
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(popped, isEmpty);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('customers can close but not accept or resolve', (t) async {
    flag = false;
    await open(t);
    expect(find.text('Accept'), findsNothing);
    expect(
      find.text('You can reply once an agent accepts this ticket'),
      findsOneWidget,
    );

    status = 'in_progress';
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      const MaterialApp(home: TicketDetailsView(ticketId: '7')),
    );
    await settle(t);
    expect(find.text('Resolve'), findsNothing);
    await t.tap(find.text('Close'));
    await settle(t);
    await t.tap(find.text('Close ticket'));
    await settle(t);
    expect(writes.single, startsWith('PUT /v1/tickets/closed/7'));
    expect(find.text('CLOSED'), findsOneWidget);
    expect(find.text('This ticket is closed to new messages'), findsOneWidget);
    await t.pump(const Duration(seconds: 20)); // Idle HTTP connection.
  });
}
