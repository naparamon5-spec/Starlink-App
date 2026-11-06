import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/core/utils/ticket_export.dart';
import 'package:starlink_app/shared/widgets/ticket_filter_bar.dart';

void main() {
  group('ticketExportRows', () {
    test('uses the website columns and reads full_data when wrapped', () {
      final rows = ticketExportRows([
        {
          'id': 'wrapper',
          'status': 'OPEN',
          'full_data': {
            'id': 101,
            'subject': 'No signal',
            'ticket_type': 'Connection issues',
            'status': 'in_progress',
            'created_by': 'Ana',
            'requester': null,
            'description': 'Down since noon',
          },
        },
      ]);
      expect(rows.single.length, ticketExportHeaders.length);
      expect(rows.single.sublist(0, 6), [
        101,
        'No signal',
        'Connection issues',
        'In Progress',
        'Ana',
        '',
      ]);
      expect(rows.single.last, 'Down since noon');
    });
  });

  test('dropdowns read the API ticket, wrapped or not', () {
    final t = {
      'full_data': {'ticket_type': 'Billing', 'requester': 'Ana'},
    };
    expect(ticketMatchesDropdowns(t, type: '', requester: ''), isTrue);
    expect(
      ticketMatchesDropdowns(t, type: 'Billing', requester: 'Ana'),
      isTrue,
    );
    expect(ticketMatchesDropdowns(t, type: 'Other', requester: ''), isFalse);
    expect(ticketMatchesDropdowns(t, type: '', requester: 'Ben'), isFalse);
  });

  group('ExportTicketsButton', () {
    testWidgets('says so when nothing matches', (t) async {
      final c = ListExportController()..loader = () async => [];
      await _pumpButton(t, c);
      await t.tap(find.byType(IconButton));
      await t.pump();
      expect(find.text('No tickets match your filters'), findsOneWidget);
    });

    testWidgets('shows a load failure', (t) async {
      final c =
          ListExportController()
            ..loader =
                () async => throw Exception('Tickets are still loading.');
      await _pumpButton(t, c);
      await t.tap(find.byType(IconButton));
      await t.pump();
      expect(find.text('Tickets are still loading.'), findsOneWidget);
    });
  });

  group('fetchAllTickets', () {
    Map<String, dynamic> ok(List<int> ids) => {
      'status': 'success',
      'data': [
        for (final i in ids) {'id': i},
      ],
    };

    test('reads every page until an empty one', () async {
      final pages = <int>[];
      final all = await fetchAllTickets(
        fetchPage: (page, limit) async {
          pages.add(page);
          return ok(
            page == 1
                ? [1, 2]
                : page == 2
                ? [3]
                : [],
          );
        },
      );
      expect(all.map((t) => t['id']), [1, 2, 3]);
      expect(pages, [1, 2, 3]);
    });

    test('stops if the server keeps repeating a page', () async {
      final all = await fetchAllTickets(
        fetchPage: (page, limit) async => ok([1, 2]),
      );
      expect(all.length, 2);
    });

    test('throws on an error instead of exporting part of the list', () {
      expect(
        fetchAllTickets(
          fetchPage:
              (page, limit) async =>
                  page == 1
                      ? ok([1])
                      : {'status': 'error', 'message': 'Server down'},
        ),
        throwsException,
      );
    });
  });
}

Future<void> _pumpButton(WidgetTester t, ListExportController c) =>
    t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [ExportTicketsButton(controller: c)]),
        ),
      ),
    );
