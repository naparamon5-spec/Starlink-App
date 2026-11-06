import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/profile/admin_manage_users_page.dart';

String _jwt() {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': 'admin', 'exp': 4102444800})}.sig';
}

void main() {
  late HttpServer server;
  final writes = <String>[];
  var lastBody = '';
  var myRole = 'admin';
  var users = <Map<String, dynamic>>[];

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api', '');
      final body = await utf8.decoder.bind(req).join();
      Object? data = const [];
      if (req.method != 'GET') {
        writes.add(path);
        lastBody = body;
        final id = path.split('/').last;
        for (final u in users) {
          if ('${u['id']}' == id) {
            u['inactive'] = path.contains('deactivate') ? 'Y' : 'N';
          }
        }
      } else if (path.contains('/me')) {
        data = {'id': 1, 'role': myRole};
      } else if (path.startsWith('/v1/users')) {
        data = users;
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
    myRole = 'admin';
    users = [
      {
        'id': 1,
        'name': 'Me Myself',
        'email': 'me@x.com',
        'role': 'admin',
        'position': 'Boss',
        'inactive': 'N',
      },
      {
        'id': 2,
        'name': 'Pat Santos',
        'email': 'pat@x.com',
        'role': 'agent',
        'position': 'Programmer',
        'inactive': 'N',
      },
      {
        'id': 3,
        'name': 'Billing Team',
        'email': 'bill@x.com',
        'role': 'end_user',
        'position': 'TOP',
        'inactive': 'Y',
      },
    ];
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
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: AdminManageUsersPage()));
    await settle(t);
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
  }

  test('who can be toggled matches the web portal', () {
    bool can(String role, Map<String, dynamic> u) =>
        canToggleUser(myRole: role, myId: '1', user: u);
    expect(can('admin', {'id': 1, 'role': 'admin'}), isFalse);
    expect(can('admin', {'id': 2, 'role': 'agent'}), isTrue);
    expect(can('agent', {'id': 2, 'role': 'agent'}), isFalse);
    expect(can('agent', {'id': 3, 'role': 'customer'}), isTrue);
    expect(can('agent', {'id': 3, 'role': 'end_user'}), isTrue);
    expect(can('', {'id': 3, 'role': 'customer'}), isFalse);
  });

  testWidgets('shows users; no button on your own account', (t) async {
    await open(t);
    expect(find.text('Pat Santos'), findsOneWidget);
    expect(find.text('END USER'), findsOneWidget);
    expect(find.text('Programmer'), findsOneWidget);
    expect(find.text('Deactivate'), findsOneWidget); // Pat, not me.
    expect(find.text('Activate'), findsOneWidget);
    expect(find.text('Invite User'), findsOneWidget);
    await finish(t);
  });

  testWidgets('deactivate asks first, then updates the card', (t) async {
    await open(t);
    await t.tap(find.text('Deactivate'));
    await settle(t);
    expect(find.text('Deactivate this user?'), findsOneWidget);
    expect(writes, isEmpty);
    await t.tap(find.text('Deactivate').last);
    await settle(t);
    expect(writes.single, '/v1/users/deactivate/2');
    expect(find.text('Activate'), findsNWidgets(2));
    await finish(t);
  });

  testWidgets('activate happens straight away', (t) async {
    await open(t);
    await t.tap(find.text('Activate'));
    await settle(t);
    expect(writes.single, '/v1/users/activate/3');
    expect(find.text('Deactivate'), findsNWidgets(2));
    await finish(t);
  });

  Future<void> openInvite(WidgetTester t) async {
    await open(t);
    await t.tap(find.text('Invite User'));
    await settle(t);
  }

  testWidgets('the page is called Users', (t) async {
    await open(t);
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Manage Users'), findsNothing);
    await finish(t);
  });

  testWidgets('Invite User checks required fields', (t) async {
    await openInvite(t);
    expect(
      find.text('Create an account and send an invitation.'),
      findsOneWidget,
    );
    expect(find.text('COMPANY EMAIL *'), findsOneWidget);
    await t.tap(find.text('Send invitation'));
    await t.pump();
    expect(find.text('Select a role.'), findsOneWidget);
    expect(find.text('First name is required.'), findsOneWidget);
    expect(find.text('Last name is required.'), findsOneWidget);
    expect(find.text('Select a company.'), findsOneWidget);
    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(writes, isEmpty);
    await finish(t);
  });

  testWidgets('Send invitation posts what the website posts', (t) async {
    t.view.physicalSize = const Size(320, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var created = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder:
                            (_) => CreateUserSheet(
                              currentUserRole: 'admin',
                              prefilledRole: 'customer',
                              prefilledCompanyCode: 'S-1',
                              prefilledCompanyName: '17th TRADING',
                              onCreated: () => created = true,
                              onError: (_) {},
                            ),
                      ),
                  child: const Text('go'),
                ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await settle(t);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('17th TRADING'), findsOneWidget);
    final fields = find.byType(TextField);
    await t.enterText(fields.at(1), 'Pat');
    await t.enterText(fields.at(3), 'Santos');
    await t.enterText(fields.at(4), 'pat@company.com.ph');
    await t.tap(find.text('Send invitation'));
    await settle(t);
    expect(writes.single, '/v1/users/');
    expect(json.decode(lastBody), {
      'first_name': 'Pat',
      'last_name': 'Santos',
      'middle_name': '',
      'email': 'pat@company.com.ph',
      'role': 'customer',
      'position': '',
      'com_eu_code': 'S-1',
    });
    expect(created, isTrue);
    await finish(t);
  });

  testWidgets('search covers role and position', (t) async {
    await open(t);
    await t.enterText(find.byType(TextField), 'programmer');
    await t.pump();
    expect(find.text('Pat Santos'), findsOneWidget);
    expect(find.text('Billing Team'), findsNothing);
    await finish(t);
  });
}
