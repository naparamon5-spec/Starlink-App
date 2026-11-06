import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/tools/report_builder_page.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

const _sources = [
  {
    'key': 'tickets',
    'label': 'Tickets',
    'description': 'Support tickets.',
    'defaultColumns': ['id', 'status'],
    'defaultFilters': [],
    'defaultSort': {'key': 'id', 'dir': 'desc'},
    'fields': [
      {'key': 'id', 'label': 'Ticket #', 'type': 'id'},
      {'key': 'subject', 'label': 'Subject', 'type': 'text'},
      {
        'key': 'status',
        'label': 'Status',
        'type': 'enum',
        'options': [
          {'value': 'in_progress', 'label': 'In progress'},
        ],
      },
    ],
  },
];

void main() {
  late HttpServer server;
  final runs = <Map<String, dynamic>>[];

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api', '');
      final body = await utf8.decoder.bind(req).join();
      Object? data = const [];
      if (path == '/v1/reports/sources') {
        data = _sources;
      } else if (path == '/v1/reports/run') {
        runs.add(Map<String, dynamic>.from(json.decode(body)));
        data = {
          'total': 1,
          'ms': 5,
          'truncated': false,
          'columns': [
            {'key': 'id', 'label': 'Ticket #', 'type': 'id'},
            {'key': 'status', 'label': 'Status', 'type': 'enum'},
          ],
          'rows': [
            {'id': 1046, 'status': 'in_progress'},
          ],
        };
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
    runs.clear();
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
    t.view.physicalSize = const Size(320, 2200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: ReportBuilderPage()));
    await settle(t);
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  }

  bool enabled(WidgetTester t, String label) =>
      t
          .widget<TextButton>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed !=
      null;

  test('share links open on the web portal and decode to the request', () {
    final link = reportShareLink({
      'source': 'tickets',
      'columns': ['id'],
    });
    final uri = Uri.parse(link);
    expect(uri.host, 'starlink.ardentnetworks.com.ph');
    expect(uri.path, '/report-builder');
    final code = uri.queryParameters['r']!;
    expect(code, isNot(contains('=')));
    expect(
      json.decode(utf8.decode(base64Url.decode(base64Url.normalize(code)))),
      {
        'source': 'tickets',
        'columns': ['id'],
      },
    );
  });

  test('cells read like the web portal', () {
    expect(reportCellText(null, 'text'), '—');
    expect(reportCellText('1234.5', 'money'), '₱1,234.50');
    expect(reportCellText(2, 'gb'), '2.00 GB');
    expect(reportCellText(80.25, 'percent'), '80.3%');
    expect(reportCellText('1200', 'number'), '1,200');
    expect(reportCellText('0000-00-00', 'date'), '—');
    expect(reportCellText('in_progress', 'enum'), 'In progress');
    expect(
      reportCellText(
        'a',
        'enum',
        options: const [
          {'value': 'a', 'label': 'Open'},
        ],
      ),
      'Open',
    );
  });

  test('exports keep real numbers and drop placeholder dates', () {
    expect(reportExportValue('1.5', 'money'), 1.5);
    expect(reportExportValue('0000-00-00', 'date'), isNull);
    expect(reportExportValue('', 'text'), isNull);
    expect(reportExportValue('x', 'text'), 'x');
  });

  testWidgets('shows the website form and three actions', (t) async {
    await open(t);
    expect(find.text('REPORT ON'), findsOneWidget);
    expect(find.text('GROUP BY'), findsOneWidget);
    expect(find.text('COLUMNS'), findsOneWidget);
    expect(find.text('FILTERS'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget);
    expect(enabled(t, 'Copy link'), isTrue);
    expect(enabled(t, 'Export'), isFalse);
    expect(find.text('Set up a report and press Run'), findsOneWidget);
    await finish(t);
  });

  testWidgets('Run shows results and enables Export', (t) async {
    await open(t);
    await t.tap(find.text('Run report'));
    await settle(t);
    expect(runs.single['source'], 'tickets');
    expect(find.text('1 row'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(enabled(t, 'Export'), isTrue);
    await finish(t);
  });

  testWidgets('Templates lists all eight and running one applies it', (
    t,
  ) async {
    await open(t);
    await t.tap(find.text('Templates'));
    await settle(t);
    for (final name in [
      'Open tickets by company',
      'Tickets per month by type',
      'Tickets open longer than 7 days',
      'Service lines ending in 30 days',
      'Unpaid billing by customer',
      'Lines over 80% of their limit',
      'Data used per company (30 days)',
      'Active accounts by company and role',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    await t.tap(find.text('Open tickets by company'));
    await settle(t);
    expect(runs.single['source'], 'tickets');
    expect(find.byType(BottomSheet), findsNothing);
    await finish(t);
  });

  testWidgets('Copy link copies the web address', (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(t);
    await t.tap(find.text('Copy link'));
    await settle(t);
    expect(
      copied,
      startsWith('https://starlink.ardentnetworks.com.ph/report-builder?r='),
    );
    expect(find.textContaining('Link copied'), findsOneWidget);
    await finish(t);
  });

  testWidgets('All selects every column', (t) async {
    await open(t);
    await t.tap(find.text('All'));
    await t.pump();
    await t.tap(find.text('Run report'));
    await settle(t);
    expect(runs.single['columns'], ['id', 'subject', 'status']);
    await finish(t);
  });
}
