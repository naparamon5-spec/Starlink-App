import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/core/utils/billing_export.dart';
import 'package:starlink_app/features/billing/billing_details_view.dart';
import 'package:starlink_app/features/billing/billing_list_view.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

const _rows = [
  {
    'customer_code': 'A-1',
    'customer_name': 'ACME',
    'cpo_number': 'PO-1',
    'sidr_number': 'S-1',
    'amount': '100.50',
    'paid_amount': '0.00',
  },
  {
    'customer_code': 'B-2',
    'customer_name': 'BETA',
    'cpo_number': 'PO-2',
    'sidr_number': 'S-2',
    'amount': 200,
    'paid_amount': 200,
  },
];

class _FakePicker with MockPlatformInterfaceMixin implements FilePicker {
  _FakePicker(this.result);
  final FilePickerResult? result;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(result);
}

FilePickerResult _csv(String text) => FilePickerResult([
  PlatformFile(
    name: 'billing.csv',
    size: text.length,
    bytes: Uint8List.fromList(utf8.encode(text)),
  ),
]);

void main() {
  late HttpServer server;
  var role = 'admin';
  var paid = 0.0;
  var importFails = false;
  final writes = <String>[];

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = Uri.decodeComponent(req.uri.path.replaceFirst('/api', ''));
      final body = await utf8.decoder.bind(req).join();
      Object? data = const [];
      if (path == '/v1/billing/import') {
        writes.add('$path $body');
        final bad = importFails;
        req.response.statusCode = bad ? 400 : 201;
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          json.encode(
            bad
                ? {'status': 'error', 'message': 'Row 2: amount is missing.'}
                : {
                  'status': 'success',
                  'data': {
                    'counts': {'new': 1, 'update': 0},
                  },
                },
          ),
        );
        await req.response.close();
        return;
      }
      if (req.method == 'PUT') {
        writes.add('$path $body');
        paid += (json.decode(body)['amount'] as num).toDouble();
      } else if (path == '/v1/billing/') {
        data = _rows;
      } else if (path == '/v1/billing/A-1/PO-1/S-1') {
        data = {
          ..._rows[0],
          'customer_name': null, // This route has no join.
          'paid_amount': paid,
        };
      } else if (path.contains('/me')) {
        data = {'role': role};
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
    role = 'admin';
    paid = 0;
    importFails = false;
    writes.clear();
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

  test('money, dates and the export columns match the web portal', () {
    expect(billingMoney(63387.1), '₱63,387.10');
    expect(billingMoney(-3670553.18), '-₱3,670,553.18');
    expect(billingMoney(9222588, decimals: false), '₱9,222,588');
    expect(billingDate('2025-09-05T00:00:00.000Z'), 'Sep 05, 2025');
    expect(billingDate('0000-00-00'), '—');
    expect(billingDate(null), '—');
    expect(billingExportRows(_rows).last, [
      'BETA',
      'B-2',
      'PO-2',
      '',
      'S-2',
      '',
      200,
      200,
      0,
    ]);
  });

  testWidgets('list totals follow the search', (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: BillingListView(onOpen: (_) {})));
    await settle(t);
    expect(find.text('₱301'), findsOneWidget); // 100.50 + 200, no centavos.
    expect(find.text('₱200'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'beta');
    await t.pump();
    expect(find.text('₱200'), findsNWidgets(2));
    expect(find.textContaining('ACME', findRichText: true), findsNothing);
    await finish(t);
  });

  Future<void> openMenu(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(home: BillingListView(onOpen: (_) {}, showAppBar: true)),
    );
    await settle(t);
    await t.tap(find.byTooltip('Billing actions'));
    await settle(t);
  }

  for (final r in ['admin', 'biller']) {
    testWidgets('the menu offers $r all three options', (t) async {
      role = r;
      await openMenu(t);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Template'), findsOneWidget);
      expect(find.text('Import Excel'), findsOneWidget);
      await finish(t);
    });
  }

  testWidgets('Import Excel uploads the chosen file without opening a page', (
    t,
  ) async {
    role = 'admin';
    FilePicker.platform = _FakePicker(
      _csv('Customer Code,CPO #,SI/DR #,Amount\nA-9,PO-9,S-9,50\n'),
    );
    await openMenu(t);
    await t.tap(find.text('Import Excel'));
    await settle(t);
    expect(writes.single, contains('/v1/billing/import'));
    expect(writes.single, contains('"dryRun":false'));
    expect(writes.single, contains('"Customer Code":"A-9"'));
    expect(find.text('Import Billing'), findsNothing);
    expect(find.text('Billing imported: 1 new, 0 updated'), findsOneWidget);
    await finish(t);
  });

  testWidgets('a rejected file shows why', (t) async {
    role = 'admin';
    importFails = true;
    FilePicker.platform = _FakePicker(_csv('Customer Code\nA-9\n'));
    await openMenu(t);
    await t.tap(find.text('Import Excel'));
    await settle(t);
    expect(find.text('Row 2: amount is missing.'), findsOneWidget);
    await finish(t);
  });

  testWidgets('cancelling the file picker uploads nothing', (t) async {
    role = 'admin';
    FilePicker.platform = _FakePicker(null);
    await openMenu(t);
    await t.tap(find.text('Import Excel'));
    await settle(t);
    expect(writes, isEmpty);
    await finish(t);
  });

  testWidgets('the menu offers agents Export only', (t) async {
    role = 'agent';
    await openMenu(t);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Template'), findsNothing);
    expect(find.text('Import Excel'), findsNothing);
    await finish(t);
  });

  testWidgets('customers get no menu', (t) async {
    role = 'customer';
    await t.pumpWidget(
      MaterialApp(home: BillingListView(onOpen: (_) {}, showAppBar: true)),
    );
    await settle(t);
    expect(find.byTooltip('Billing actions'), findsNothing);
    await finish(t);
  });

  testWidgets('admins record a payment and the balance updates', (t) async {
    t.view.physicalSize = const Size(320, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      const MaterialApp(
        home: BillingDetailsView(
          customerCode: 'A-1',
          cpoNumber: 'PO-1',
          sidrNumber: 'S-1',
          customerName: 'ACME',
        ),
      ),
    );
    await settle(t);
    expect(find.text('ACME'), findsOneWidget);
    await t.tap(find.text('Make Payment'));
    await settle(t);
    await t.tap(find.textContaining('Pay the full balance'));
    await t.pump();
    expect(find.textContaining('balance ₱0.00'), findsOneWidget);
    await t.tap(find.text('Record payment'));
    await settle(t);
    expect(writes.single, startsWith('/v1/billing/A-1/PO-1/S-1'));
    expect(writes.single, contains('"amount":100.5'));
    expect(find.text('₱100.50'), findsNWidgets(2)); // Amount and paid.
    expect(find.text('₱0.00'), findsOneWidget); // Balance.
    await finish(t);
  });

  testWidgets('the payment amount only takes numbers', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: BillingDetailsView(
          customerCode: 'A-1',
          cpoNumber: 'PO-1',
          sidrNumber: 'S-1',
        ),
      ),
    );
    await settle(t);
    await t.tap(find.text('Make Payment'));
    await settle(t);
    final field = find.byType(TextField).last;
    String value() => t.widget<TextField>(field).controller!.text;

    await t.enterText(field, 'abc');
    expect(value(), '');
    await t.enterText(field, '12.50');
    expect(value(), '12.50');
    await t.enterText(field, '12.50x');
    expect(value(), '12.50');
    await t.enterText(field, '12.505');
    expect(value(), '12.50');
    await t.enterText(field, '-1');
    expect(value(), '12.50');
    await finish(t);
  });

  testWidgets('customers cannot record payments', (t) async {
    role = 'customer';
    await t.pumpWidget(
      const MaterialApp(
        home: BillingDetailsView(
          customerCode: 'A-1',
          cpoNumber: 'PO-1',
          sidrNumber: 'S-1',
        ),
      ),
    );
    await settle(t);
    expect(find.text('Make Payment'), findsNothing);
    await finish(t);
  });
}
