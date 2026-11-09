import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/core/utils/file_download/file_downloader.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('messages name a place the user can open, not a raw path', () {
    const path = '/var/mobile/Containers/Data/Application/X/Documents/a.xlsx';

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(savedLocationLabel(path), contains('Files app'));

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(savedLocationLabel(path), 'your Downloads folder');

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(savedLocationLabel(path), path);
  });
}
