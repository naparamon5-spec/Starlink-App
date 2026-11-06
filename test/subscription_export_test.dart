import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/core/utils/subscription_export.dart';

void main() {
  test('uses the website columns and wording', () {
    final rows = subscriptionExportRows([
      {
        'nickname': 'ZELIANT-STANDARD-143',
        'serviceLineNumber': 'SL-DF-1',
        'company_name': 'ZELIANT IT SOLUTIONS',
        'end_user_name': 'MAIN DICT REGION 12',
        'address': 'Koronadal',
        'kit_number': 'KIT1',
        'active': 'ACTIVE',
        'subscriptionPlan': 'NOR',
        'totalPriorityGB': '771.80',
        'dataplan': 2000,
        'startDate': '2026-10-02',
        'endDate': null,
      },
    ]);
    expect(rows.single.length, subscriptionExportHeaders.length);
    expect(rows.single, [
      'ZELIANT-STANDARD-143',
      'SL-DF-1',
      'ZELIANT IT SOLUTIONS',
      'MAIN DICT REGION 12',
      'Koronadal',
      'KIT1',
      'Active',
      'Normal',
      771.80,
      2000,
      '2026-10-02',
      '',
    ]);
  });

  test('missing numbers stay blank instead of zero', () {
    final row = subscriptionExportRows([{}]).single;
    expect(row[8], '');
    expect(row[9], '');
    expect(row[6], '');
  });
}
