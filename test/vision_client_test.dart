import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_mate/services/ai_service.dart';

void main() {
  test(
    'image client sends bytes explicitly and preserves unknown line total',
    () async {
      final dir = await Directory.systemTemp.createTemp('expense_vision_test_');
      final file = await File('${dir.path}/receipt.png')
          .writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]);
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/receipt-image');
        final body = jsonDecode(utf8.decode(request.bodyBytes)) as Map;
        expect(body['mimeType'], 'image/png');
        expect(base64Decode(body['imageBase64'] as String).first, 137);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'source': 'gemini',
              'merchant': 'WINMART',
              'date': null,
              'amount': 80000,
              'details': {
                'invoiceNumber': 'A1',
                'discount': 0,
                'surcharge': 0,
                'items': [
                  {
                    'name': 'Sản phẩm',
                    'quantity': 1,
                    'unitPrice': 16000,
                    'lineTotal': null,
                    'needsReview': true,
                  },
                ],
              },
              'warnings': <String>[],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      try {
        final r = await AiService(client: client).analyzeImage(
          baseUrl: 'http://127.0.0.1:8787',
          token: 'a' * 32,
          path: file.path,
        );
        expect(r['date'], isNull);
        expect(
          ((r['details'] as Map)['items'] as List).first['lineTotal'],
          isNull,
        );
      } finally {
        client.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test('oversized image is rejected before contacting the service', () async {
    final dir = await Directory.systemTemp.createTemp('expense_image_limit_');
    final file = await File('${dir.path}/big.jpg')
        .writeAsBytes(List.filled(2 * 1024 * 1024 + 1, 0));
    bool called = false;
    final client = MockClient((_) async {
      called = true;
      throw StateError('not expected');
    });
    try {
      await expectLater(
        AiService(client: client).analyzeImage(
          baseUrl: 'http://127.0.0.1:8787',
          token: 'a' * 32,
          path: file.path,
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(called, isFalse);
    } finally {
      client.close();
      await dir.delete(recursive: true);
    }
  });
}
