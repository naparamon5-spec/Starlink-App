import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/shared/widgets/ticket_list_card.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 12);

  test('timeAgo uses the web portal wording', () {
    String at(Duration d) =>
        TicketListCard.timeAgo(now.subtract(d).toIso8601String(), now: now);
    expect(at(const Duration(seconds: 10)), 'just now');
    expect(at(const Duration(minutes: 5)), '5m ago');
    expect(at(const Duration(hours: 3)), '3h ago');
    expect(at(const Duration(days: 9)), '9d ago');
    expect(at(const Duration(days: 40)).contains('2026'), isTrue);
    expect(TicketListCard.timeAgo(null), '—');
    expect(TicketListCard.timeAgo('not a date'), '—');
  });

  testWidgets('shows the ticket, marks the search term and opens on tap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketListCard(
            id: '1046',
            subject: 'ARDENT-001 - Billing',
            status: 'in_progress',
            description: 'No description',
            type: 'Billing',
            createdBy: 'Pat Santos',
            searchQuery: 'ardent',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('#1046'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('No description'), findsNothing);
    expect(find.textContaining('ARDENT', findRichText: true), findsOneWidget);
    await tester.tap(find.text('#1046'));
    expect(tapped, isTrue);
  });
}
