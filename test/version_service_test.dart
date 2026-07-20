import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:starlink_app/services/version_service.dart';

void main() {
  AppVersionService serviceReturning(String body) => AppVersionService(
    client: MockClient((_) async => http.Response(body, 200)),
  );

  test('parses the Starlink row out of the list payload', () async {
    final info =
        await serviceReturning(
          '[{"id":1,"application":"eForward","version":"9.9.9","url":"https://e/app.apk"},'
          '{"id":2,"application":"Starlink","version":"2.1.0","url":"https://s/app.apk"}]',
        ).fetchLatestVersion();

    expect(info, isNotNull);
    expect(info!.latestVersion.toString(), '2.1.0');
    expect(info.downloadUrl.toString(), 'https://s/app.apk');
    expect(info.isMandatory, isTrue);
  });

  test('returns null when version is null', () async {
    final info =
        await serviceReturning(
          '[{"id":2,"application":"Starlink","version":null,"url":"https://s/app.apk"}]',
        ).fetchLatestVersion();

    expect(info, isNull);
  });

  test('returns null when this app has no row', () async {
    final info =
        await serviceReturning(
          '[{"id":1,"application":"ARM","version":"1.0.0","url":"https://a/app.apk"}]',
        ).fetchLatestVersion();

    expect(info, isNull);
  });

  test('accepts short version strings', () async {
    final info =
        await serviceReturning(
          '[{"id":2,"application":"starlink","version":"2.1","url":"https://s/app.apk"}]',
        ).fetchLatestVersion();

    expect(info!.latestVersion.toString(), '2.1.0');
  });

  test('compares versions ignoring the build suffix', () {
    final installed = AppComparableVersion.tryParse('2.0.0+2')!;
    expect(installed.isOutdated(AppComparableVersion.tryParse('2.0.1')!), true);
    expect(installed.isOutdated(AppComparableVersion.tryParse('2.0.0+9')!), false);
  });
}
