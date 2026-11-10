// Pumps the app's main screens at real phone and tablet sizes, in portrait and
// landscape and with larger system text, using the real font and long values.
// Any layout overflow fails the test and names the widget that caused it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/admin/admin_home_screen.dart';
import 'package:starlink_app/features/admin/profile/admin_manage_users_page.dart';
import 'package:starlink_app/features/admin/profile/view-user/admin_view_user_details_page.dart';
import 'package:starlink_app/features/admin/sections/enduser/admin_end_user_details_page.dart';
import 'package:starlink_app/features/admin/sections/enduser/admin_end_users_page.dart';
import 'package:starlink_app/features/admin/sections/subscription/admin_subscriptions_page.dart';
import 'package:starlink_app/features/admin/sections/ticket/admin_create_ticket_page.dart';
import 'package:starlink_app/features/admin/sections/ticket/admin_tickets_page.dart';
import 'package:starlink_app/features/admin/tools/announcements_admin_page.dart';
import 'package:starlink_app/features/admin/tools/report_builder_page.dart';
import 'package:starlink_app/features/admin/tools/reports_page.dart';
import 'package:starlink_app/features/auth/forgot_password.dart';
import 'package:starlink_app/features/auth/login_screen.dart';
import 'package:starlink_app/features/auth/otp_verification_page.dart';
import 'package:starlink_app/features/billing/billing_details_view.dart';
import 'package:starlink_app/features/billing/billing_list_view.dart';
import 'package:starlink_app/features/customer/home/customer_home_screen.dart';
import 'package:starlink_app/features/customer/subscription/customer_subscription_page.dart';
import 'package:starlink_app/features/customer/ticket/customer_ticket.dart';
import 'package:starlink_app/features/end_user/home/home_screen.dart';
import 'package:starlink_app/features/end_user/subscription/end_user_subscription_page.dart';
import 'package:starlink_app/features/end_user/ticket/ticket_screen.dart';
import 'package:starlink_app/features/security/security_page.dart';
import 'package:starlink_app/features/subscription/subscription_details_view.dart';
import 'package:starlink_app/features/ticket/ticket_details_view.dart';
import 'package:starlink_app/features/user_guide/user_guide_page.dart';
import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:starlink_app/shared/widgets/notifications.dart';

const _devices = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'small Android 360x640': Size(360, 640),
  'Android 360x800': Size(360, 800),
  'iPhone SE 375x667': Size(375, 667),
  'iPhone 393x852': Size(393, 852),
  'Pixel 412x915': Size(412, 915),
  'Pro Max 440x956': Size(440, 956),
  'Android 7in 600x960': Size(600, 960),
  'iPad mini 744x1133': Size(744, 1133),
  'Android 10in 800x1280': Size(800, 1280),
  'iPad 13in 1032x1376': Size(1032, 1376),
  'landscape 640x360': Size(640, 360),
  'landscape 852x393': Size(852, 393),
  'landscape iPad 1376x1032': Size(1376, 1032),
};

/// System text settings to try on the sizes people commonly enlarge text on.
const _largeTextDevices = {'Android 360x800', 'iPhone 393x852'};
const _largeText = 1.3;

const _long = 'ZELIANT-STANDARD-143-DICT REGION 12 MAIN OFFICE BUILDING';
const _company = 'SOCIAL HOUSING FINANCE CORPORATION - MAKATI BRANCH';
const _person = 'Maria Consuelo Dela Cruz-Santos Jr.';
const _email = 'maria.consuelo.delacruz@ardentnetworks.com.ph';

String _jwt(String role) {
  String b(Map m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.'
      '${b({'id': 1, 'role': role, 'exp': 4102444800})}.sig';
}

final _ticket = {
  'id': 1046,
  'subject': '$_long - Request for Gen 3 Router change SSID and/or Password',
  'description': 'The router at the site keeps disconnecting ' * 6,
  'status': 'in_progress',
  'ticket_type': 'Request for Gen 3 Router change SSID and/or Password',
  'created_by': _person,
  'requested_by': _person,
  'contact_name': _person,
  'company_name': _company,
  'created_at': '2026-11-04T05:23:00.000Z',
  'updated_at': '2026-11-04T05:23:00.000Z',
  'flag': true,
  'timeline': const [],
};

final _subscription = {
  'id': 1,
  'serviceLineNumber': 'SL-DF-16811466-52275-10',
  'nickname': _long,
  'company_name': _company,
  'end_user_name': _company,
  'kit_number': 'KIT4023803428GZ',
  'address': 'FRMV+WM Koronadal, South Cotabato, Philippines, Region XII',
  'serviceLocation': 'FRMV+WM Koronadal, South Cotabato',
  'active': 'Y',
  'subscriptionPlan': 'IMP',
  'dataplan': 2000,
  'totalPriorityGB': '836.35',
  'startDate': '2026-10-03',
  'endDate': '2027-10-02',
  'billingCycle': {'totalPriorityGB': '836.35'},
  'servicePlan': const [],
  'serviceTopUp': const [],
};

final _billing = {
  'customer_code': 'A-07600020',
  'customer_name': _company,
  'cpo_number': '2025-0065-1-LONG-REFERENCE',
  'sidr_number': '40000003909',
  'cpo_date': '2025-09-05',
  'sidr_date': '2025-09-05',
  'amount': '9222588.10',
  'paid_amount': '7413163.25',
};

final _user = {
  'id': 10,
  'name': _person,
  'first_name': 'Maria Consuelo',
  'last_name': 'Dela Cruz-Santos Jr.',
  'email': _email,
  'role': 'admin',
  'position': 'Senior Network Operations Manager',
  'company_name': _company,
  'inactive': 'N',
  'phone': '+63 917 123 4567',
};

final _notification = {
  'id': 7,
  'type': 'ticket_reply',
  'title': 'New reply on TKT-001046 for $_long',
  'body': 'Billing and account concerns',
  'read_at': null,
  'created_at': '2026-11-04T05:23:00.000Z',
  'data': {'ticket_id': 1046},
};

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

/// Set with --dart-define=RESP_PLATFORM=ios to lay out as iOS.
const _platformName = String.fromEnvironment(
  'RESP_PLATFORM',
  defaultValue: 'android',
);

Object? _respond(String path) {
  if (path.startsWith('/v1/attachments/download')) return _onePixelPng;
  if (path.startsWith('/v1/attachments/')) {
    return [
      for (var i = 21; i < 25; i++)
        {
          'id': i,
          'original_name': 'site-photo-$i.png',
          'file_type': 'image/png',
        },
      {
        'id': 30,
        'original_name': 'a-very-long-signed-service-report-for-the-site.pdf',
        'file_type': 'application/pdf',
      },
    ];
  }
  if (path.contains('/auth/me') || path.endsWith('/me')) {
    return {..._user, 'id': 1};
  }
  if (path.contains('/mfa-status/')) return {'enabled': false};
  if (path == '/v1/notifications/unread-count') return {'count': 128};
  if (path == '/v1/notifications') return [_notification, _notification];
  if (path.startsWith('/v1/tickets/stats') || path.contains('/counts')) {
    return {
      'open': 12345,
      'in_progress': 678,
      'resolved': 54321,
      'closed': 987,
    };
  }
  if (RegExp(r'^/v1/tickets/\d+$').hasMatch(path)) return _ticket;
  if (path == '/v1/tickets' || path == '/v1/tickets/')
    return [_ticket, _ticket];
  if (path.startsWith('/v1/tickets/mine') ||
      path.startsWith('/v1/tickets/recent')) {
    return [_ticket];
  }
  if (path == '/v1/subscriptions/paginated') {
    return {
      'data': [_subscription, _subscription],
      'pagination': {'currentPage': 1, 'totalPages': 1, 'totalItems': 1872},
    };
  }
  if (path.startsWith('/v1/subscriptions/billing-cycle')) {
    return {
      'totalPriorityGB': '836.35',
      'totalStandardGB': '12345.67',
      'totalOptInPriorityGB': '0',
      'totalNonBillableGB': '0',
    };
  }
  if (path.startsWith('/v1/subscriptions/list')) return [_subscription];
  if (path.startsWith('/v1/subscriptions/end-user') ||
      path.startsWith('/v1/subscriptions/customer')) {
    return [_subscription];
  }
  if (RegExp(r'^/v1/subscriptions/SL').hasMatch(path)) return _subscription;
  if (path.startsWith('/v1/billing/A-')) return _billing;
  if (path.startsWith('/v1/billing')) return [_billing, _billing];
  if (path == '/v1/usage/summary') {
    return [
      {
        'companyName': _company,
        'endUser': _company,
        'nickname': _long,
        'serviceLineNumber': 'SL-DF-16811466-52275-10',
        'consumedAmountGB': 836.35,
        'usageLimitGB': 2000,
      },
    ];
  }
  if (path.startsWith('/v1/users/10')) return _user;
  if (path.startsWith('/v1/users/company')) return [_user];
  if (path == '/v1/users' || path == '/v1/users/') return [_user, _user];
  if (path.startsWith('/v1/end-user/')) {
    return {
      'eu_code': '63674',
      'eu_name': _company,
      'customer_code': 'A-4A100426',
      'inactive': 'N',
    };
  }
  if (path.startsWith('/v1/end-user') || path.startsWith('/v1/end_user')) {
    return [
      {
        'eu_code': '63674',
        'eu_name': _company,
        'customer_code': 'A-4A100426',
        'company_name': _company,
        'inactive': 'N',
      },
    ];
  }
  return const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  final seen = <String>{};

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
      final path = req.uri.path.replaceFirst('/api', '');
      seen.add('${req.method} $path');
      await utf8.decoder.bind(req).join();
      req.response.headers.contentType = ContentType.json;
      req.response.write(
        json.encode({'status': 'success', 'data': _respond(path)}),
      );
      await req.response.close();
    });
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api',
    );
  });

  tearDownAll(() async {
    await server.close(force: true);
    stdout.writeln('ENDPOINTS\n${(seen.toList()..sort()).join('\n')}');
  });

  Future<void> check(
    WidgetTester t,
    Widget Function() screen, {
    String role = 'admin',
    Future<void> Function(WidgetTester t)? after,
  }) async {
    SharedPreferences.setMockInitialValues({
      'accessToken': _jwt(role),
      'refreshToken': 'r',
      'user_id': 1,
      'userType': role,
      'role': role,
    });
    final problems = <String>{};
    final original = FlutterError.onError;
    var label = '';
    FlutterError.onError = (details) {
      final text = details.toString();
      final first =
          text
              .split('\n')
              .firstWhere(
                (l) => l.contains('overflowed') || l.contains('Exception'),
                orElse: () => details.exceptionAsString().split('\n').first,
              )
              .replaceAll(RegExp(r'[═╡╞]+'), '')
              .trim();
      final where = RegExp(r'lib/[^\s:]+:\d+').firstMatch(text)?.group(0) ?? '';
      if (text.contains('overflowed')) problems.add('$label: $first  $where');
    };

    Future<void> run(String name, Size size, double scale) async {
      label = '$name @${scale}x';
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.light.copyWith(
            platform:
                _platformName == 'ios'
                    ? TargetPlatform.iOS
                    : TargetPlatform.android,
          ),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
          home: screen(),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await t.runAsync(
          () => Future.delayed(const Duration(milliseconds: 30)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      await after?.call(t);
    }

    try {
      for (final e in _devices.entries) {
        await run(e.key, e.value, 1);
        if (_largeTextDevices.contains(e.key)) {
          await run(e.key, e.value, _largeText);
        }
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 40));
    } finally {
      FlutterError.onError = original;
      t.view.reset();
    }
    expect(problems.toList()..sort(), isEmpty);
  }

  final screens = <String, Widget Function()>{
    'Login': () => const LoginScreen(),
    'Forgot password': () => const ForgotPasswordPage(),
    'OTP': () => const OtpVerificationPage(email: _email),
    'Admin home': () => const AdminHomeScreen(),
    'Tickets': () => const Scaffold(body: AdminTicketsPage()),
    'Subscriptions': () => const Scaffold(body: AdminSubscriptionsPage()),
    'End users': () => const Scaffold(body: AdminEndUsersPage()),
    'Users': () => const AdminManageUsersPage(),
    'Reports': () => const ReportsPage(),
    'Report builder': () => const ReportBuilderPage(),
    'Announcements': () => const AnnouncementsAdminPage(),
    'Security': () => const SecurityPage(),
    'User guide': () => const UserGuidePage(),
    'Notifications': () => const NotificationsPage(),
    'Create ticket': () => const AdminCreateTicketPage(),
    'Billing list': () => BillingListView(onOpen: (_) {}, showAppBar: true),
    'Billing details':
        () => const BillingDetailsView(
          customerCode: 'A-07600020',
          cpoNumber: 'PO-1',
          sidrNumber: 'S-1',
          customerName: _company,
        ),
    'Ticket details': () => const TicketDetailsView(ticketId: '1046'),
    'Subscription details':
        () => const SubscriptionDetailsView(
          serviceLineNumber: 'SL-DF-16811466-52275-10',
          title: _long,
          canEditEndDate: true,
          canManageKits: true,
          canViewRouter: true,
        ),
    'End user details':
        () => const AdminEndUserDetailsPage(
          endUserId: '63674',
          endUserCode: '63674',
          endUserName: _company,
        ),
    'User details': () => const AdminUserDetailPage(userId: '10'),
  };

  screens.forEach((name, screen) {
    testWidgets('$name fits every device', (t) => check(t, screen));
  });

  Future<void> settleAfterTap(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Ticket images and files panel fits every device', (t) async {
    await check(
      t,
      () => const TicketDetailsView(ticketId: '1046'),
      after: (t) async {
        await t.tap(find.text('Details'), warnIfMissed: false);
        await settleAfterTap(t);
      },
    );
  });

  testWidgets('Make Payment sheet fits every device', (t) async {
    await check(
      t,
      () => const BillingDetailsView(
        customerCode: 'A-07600020',
        cpoNumber: 'PO-1',
        sidrNumber: 'S-1',
        customerName: _company,
      ),
      after: (t) async {
        // On a short screen the button starts out below the fold.
        await t.scrollUntilVisible(
          find.text('Make Payment'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await t.pump();
        await t.tap(find.text('Make Payment').first, warnIfMissed: false);
        await settleAfterTap(t);
      },
    );
  });

  testWidgets('Customer screens fit every device', (t) async {
    await check(
      t,
      () => const CustomerHomeScreen(loginMessage: ''),
      role: 'customer',
    );
  });
  testWidgets('Customer tickets fit every device', (t) async {
    await check(t, () => const CustomerTicketScreen(), role: 'customer');
  });
  testWidgets('Customer subscriptions fit every device', (t) async {
    await check(t, () => const CustomerSubscriptionPage(), role: 'customer');
  });
  testWidgets('End user home fits every device', (t) async {
    await check(t, () => const HomeScreen(userId: 1), role: 'end_user');
  });
  testWidgets('End user tickets fit every device', (t) async {
    await check(
      t,
      () => const Scaffold(body: TicketScreen()),
      role: 'end_user',
    );
  });
  testWidgets('End user subscriptions fit every device', (t) async {
    await check(t, () => const UserSubscriptionPage(), role: 'end_user');
  });

  testWidgets('Dialogs fit every device', (t) async {
    await check(
      t,
      () => Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              AppToast.result(
                context,
                'Saved subscriptions-2026-11-09_2.xlsx to the Files app, '
                'in the Ardent Dashboard folder',
                ok: true,
              );
            }
          });
          return const Scaffold(body: AppDialogPreview());
        },
      ),
    );
  });
}

class AppDialogPreview extends StatelessWidget {
  const AppDialogPreview({super.key});

  @override
  Widget build(BuildContext context) => const AppDialog(
    icon: Icons.logout_rounded,
    title: 'Log out of your account?',
    message: 'You will need to sign in again to use the app.',
    confirmLabel: 'Log out',
    onConfirm: null,
    cancelLabel: 'Cancel',
  );
}
