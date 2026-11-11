import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/features/admin/sections/admin_dashboard_view.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 12);

  // Widgets compare end dates with the real clock, so widget tests pass
  // `from: DateTime.now()`; the pure sorting tests use the fixed [now].
  Map<String, dynamic> line(String sln, int dayOffset, {DateTime? from}) => {
    'serviceLineNumber': sln,
    'nickname': 'NICK-$sln',
    'endDate': (from ?? now).add(Duration(days: dayOffset)).toIso8601String(),
  };

  test('days are rounded up and go negative once lapsed', () {
    expect(daysUntil(now.add(const Duration(hours: 1)), now: now), 1);
    expect(daysUntil(now, now: now), 0);
    expect(daysUntil(now.subtract(const Duration(days: 2)), now: now), -2);
    expect(daysUntil(null, now: now), isNull);
  });

  test('soonest upcoming first, then most recently lapsed', () {
    final sorted = sortExpiring([
      line('lapsed-far', -9),
      line('later', 5),
      line('lapsed-near', -1),
      line('soon', 1),
      {'serviceLineNumber': 'no-date'},
    ], now: now);
    expect(sorted.map((s) => s['serviceLineNumber']), [
      'soon',
      'later',
      'lapsed-near',
      'lapsed-far',
      'no-date',
    ]);
  });

  test('announcements are the pinned ones plus the latest three', () {
    final shown = dashboardAnnouncements([
      {'id': 1},
      {'id': 2},
      {'id': 3, 'pinned': true},
      {'id': 4},
      {'id': 5},
    ]);
    expect(shown.map((a) => a['id']), [3, 1, 2, 4]);
  });

  testWidgets('shows only three recent tickets and three subscriptions', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var viewed = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminDashboardView(
              loading: false,
              firstName: 'Ramon',
              open: 8,
              inProgress: 15,
              resolved: 545,
              closed: 1140,
              announcements: const [],
              recent: [
                for (var i = 0; i < 5; i++)
                  {
                    'id': 100 + i,
                    'subject': 'Subject $i',
                    'ticket_type': 'Billing',
                    'status': 'in_progress',
                  },
              ],
              expiring: [
                for (var i = 0; i < 5; i++)
                  line('SL-$i', i + 1, from: DateTime.now()),
              ],
              onViewTickets: () => viewed++,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('Good day, Ramon'), findsOneWidget);
    expect(find.text('1,140'), findsOneWidget);
    expect(find.text('#102'), findsOneWidget);
    expect(find.text('#103'), findsNothing);
    expect(find.text('SL-2'), findsOneWidget);
    expect(find.text('SL-3'), findsNothing);
    expect(find.text('5'), findsOneWidget); // The full count stays visible.
    await t.tap(find.text('OPEN'));
    expect(viewed, 1);

    await t.tap(find.text('View all').last);
    await t.pumpAndSettle();
    expect(find.text('SL-4'), findsOneWidget); // Everything is reachable.
  });
}
