import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/features/ticket/ticket_details_view.dart';
import 'package:starlink_app/services/api_service.dart';

void main() {
  group('sorting attachments into Images and Files', () {
    bool image(String name, String? type) =>
        isImageAttachment({'original_name': name, 'file_type': type});

    test('an older image stored as octet-stream is still an image', () {
      expect(image('photo.jpg', 'application/octet-stream'), isTrue);
      expect(image('PHOTO.PNG', 'application/octet-stream'), isTrue);
      expect(image('scan.heic', 'application/octet-stream'), isTrue);
    });

    test('a correctly typed image is an image', () {
      expect(image('photo', 'image/png'), isTrue);
      expect(image('photo.png', null), isTrue);
    });

    test('documents stay under Files', () {
      expect(image('report.pdf', 'application/pdf'), isFalse);
      expect(image('notes.docx', 'application/octet-stream'), isFalse);
      expect(image('readme.txt', null), isFalse);
    });
  });

  test('only images get an upload type', () {
    expect(ApiService.attachmentImageType('a.JPG')?.mimeType, 'image/jpeg');
    expect(ApiService.attachmentImageType('a.png')?.mimeType, 'image/png');
    expect(ApiService.attachmentImageType('a.docx'), isNull);
    expect(ApiService.attachmentImageType('a.pdf'), isNull);
  });

  test('an image and a document uploaded together keep their types', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    late String body;
    server.listen((req) async {
      body = await latin1.decoder.bind(req).join();
      req.response.headers.contentType = ContentType.json;
      req.response.write(json.encode({'data': const []}));
      await req.response.close();
    });
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api',
    );
    final dir = Directory.systemTemp.createTempSync('upload_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = File('${dir.path}/photo.png')..writeAsBytesSync([1, 2, 3]);
    final doc = File('${dir.path}/report.pdf')..writeAsBytesSync([4, 5, 6]);

    final res = await ApiService.uploadAttachments(
      ticketId: '9',
      files: [
        {'name': 'photo.png', 'path': photo.path},
        {'name': 'report.pdf', 'path': doc.path},
      ],
      bearerToken: 'token',
    );

    expect(res['status'], 'success');
    final parts = body.toLowerCase().split('--dart-http-boundary');
    final imagePart = parts.firstWhere((p) => p.contains('photo.png'));
    final docPart = parts.firstWhere((p) => p.contains('report.pdf'));
    expect(imagePart, contains('content-type: image/png'));
    expect(docPart, isNot(contains('content-type: image/')));
  });
}
