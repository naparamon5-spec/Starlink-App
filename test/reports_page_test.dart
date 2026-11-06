import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/features/admin/tools/reports_page.dart';

void main() {
  Map<String, dynamic> line(num used, num limit) => {
    'companyName': 'ACME',
    'endUser': 'BETA',
    'nickname': 'LINE-1',
    'serviceLineNumber': 'SL-1',
    'consumedAmountGB': used,
    'usageLimitGB': limit,
  };

  test('sizes read like the web portal', () {
    expect(reportGb(0), '0.00 GB');
    expect(reportGb('2.29'), '2.29 GB');
    expect(reportGb(21), '21 GB');
    expect(reportGb(1000), '1,000 GB');
  });

  test('range labels match the web portal', () {
    expect([0, 10, 25, 50, 75, 90, 100].map(reportRangeLabel), [
      'All',
      '10–24.99%',
      '25–49.99%',
      '50–74.99%',
      '75–89.99%',
      '90–99.99%',
      '100%+',
    ]);
  });

  test('a line falls in exactly one range, using the unrounded share', () {
    expect(reportInRange(line(24.99, 100), 10), isTrue);
    expect(reportInRange(line(24.99, 100), 25), isFalse);
    expect(reportInRange(line(99.99, 100), 90), isTrue);
    expect(reportInRange(line(99.99, 100), 100), isFalse);
    expect(reportInRange(line(120, 100), 100), isTrue);
    expect(reportInRange(line(5, 0), 10), isFalse);
    expect(reportInRange(line(5, 0), 0), isTrue);
  });

  test('the bar is capped at 100%', () {
    expect(reportUsagePct(line(120, 100)), 100);
    expect(reportUsagePct(line(5, 0)), 0);
  });

  test('the export has the web portal sheets and columns', () {
    final sheets = usageReportSheets(
      [line(21, 50)],
      [
        {
          'companyName': 'ACME',
          'endUser': 'BETA',
          'serviceLineNumber': 'SL-1',
          'Date': '2026-11-01T00:00:00.000Z',
          'priorityGB': '1.5',
          'optInPriorityGB': '2',
          'standardGB': '3',
          'nonBillableGB': null,
        },
      ],
    );
    expect(sheets.map((s) => s.name), ['Usage Summary', 'Daily Usage']);
    expect(sheets[0].rows.single, [
      'ACME',
      'BETA',
      'LINE-1',
      'SL-1',
      50.0,
      21.0,
      42,
    ]);
    expect(sheets[1].rows.single, [
      'ACME',
      'BETA',
      'SL-1',
      '2026-11-01',
      1.5,
      2.0,
      3.0,
      0.0,
    ]);
  });
}
