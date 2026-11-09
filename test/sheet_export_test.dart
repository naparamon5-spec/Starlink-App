import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/core/utils/file_download/file_downloader.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/core/utils/sheet_export.dart';
import 'package:starlink_app/core/utils/subscription_export.dart';

Object? _value(Data? cell) => switch (cell?.value) {
  TextCellValue(:final value) => value.text ?? value.toString(),
  IntCellValue(:final value) => value,
  DoubleCellValue(:final value) => value,
  _ => null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a workbook reopens with its sheets, headers and values', () {
    final book = Excel.decodeBytes(
      buildWorkbook(const [
        ExportSheet('Tickets', ['Ticket #', 'Subject'], [
          [12, 'A & B <c> "d"'],
          [13, 'Línea ₱100 ✓'],
        ]),
        ExportSheet('Usage', ['GB'], [
          [1.5],
        ]),
      ]),
    );

    expect(book.tables.keys, unorderedEquals(['Tickets', 'Usage']));
    final rows = book['Tickets'].rows;
    expect(rows, hasLength(3));
    expect(_value(rows[0][0]), 'Ticket #');
    expect(_value(rows[1][0]), 12);
    expect(_value(rows[1][1]), 'A & B <c> "d"');
    expect(_value(rows[2][1]), 'Línea ₱100 ✓');
    expect(_value(book['Usage'].rows[1][0]), 1.5);
  });

  test('an export with headers only still builds (billing template)', () {
    final book = Excel.decodeBytes(
      buildWorkbook(const [
        ExportSheet('Billing', ['Customer Code', 'Amount'], []),
      ]),
    );
    expect(book['Billing'].rows, hasLength(1));
  });

  test('content Excel would reject is cleaned up', () {
    final long = 'x' * 40000;
    final book = Excel.decodeBytes(
      buildWorkbook([
        ExportSheet('Tickets / Billing: a very long report name here', ['A'], [
          ['bad\x0B\x1Ftext\nkept'],
          [long],
          [double.nan],
        ]),
      ]),
    );

    final name = book.tables.keys.single;
    expect(name.length, lessThanOrEqualTo(31));
    expect(name, isNot(matches(r'[\[\]:*?/\\]')));
    final rows = book[name].rows;
    expect(_value(rows[1][0]), 'badtext\nkept');
    expect((_value(rows[2][0]) as String).length, 32767);
    expect(_value(rows[3][0]), isNull);
  });

  test('every kit on a service line is exported, repeats are not', () async {
    Map<String, dynamic> row(String sln, String kit) => {
      'serviceLineNumber': sln,
      'kit_number': kit,
    };
    final pages = [
      [row('SL-1', 'KIT-A'), row('SL-1', 'KIT-B')],
      [row('SL-1', 'KIT-B'), row('SL-2', 'KIT-C')],
      <Map<String, dynamic>>[],
    ];

    final all = await fetchAllRows(
      fetchPage: (page, _) async => {'status': 'success', 'data': pages[page - 1]},
      keyOf: subscriptionExportKey,
    );

    expect(all.map((r) => r['kit_number']), ['KIT-A', 'KIT-B', 'KIT-C']);
  });

  group('saving', () {
    late Directory dir;
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    setUp(() {
      dir = Directory.systemTemp.createTempSync('export_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => dir.path);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      dir.deleteSync(recursive: true);
    });

    Future<String?> save(String name) => saveBytesAsFile(
      bytes: Uint8List.fromList(
        buildWorkbook(const [
          ExportSheet('S', ['A'], [
            [1],
          ]),
        ]),
      ),
      filename: name,
      mimeType: 'application/octet-stream',
    );

    test('the saved file exists and reopens', () async {
      final path = await save('report.xlsx');
      expect(path, isNotNull);
      final book = Excel.decodeBytes(File(path!).readAsBytesSync());
      expect(_value(book['S'].rows[1][0]), 1);
    });

    test('a second export keeps the first file', () async {
      final first = await save('report.xlsx');
      final second = await save('report.xlsx');
      expect(second, isNot(first));
      expect(File(first!).existsSync(), isTrue);
      expect(File(second!).existsSync(), isTrue);
    });

    test('slashes in a name stay out of the path', () async {
      final path = await save('usage-a/b:c.xlsx');
      expect(path, isNotNull);
      expect(File(path!).parent.path, dir.path);
    });
  });
}
