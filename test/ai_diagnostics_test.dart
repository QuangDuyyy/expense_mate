import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_mate/services/ai_service.dart';

void main() {
  test(
    'Gemini real check uses synthetic text instead of receipt data',
    () async {
      final c = MockClient((r) async {
        final body = jsonDecode(utf8.decode(r.bodyBytes));
        expect(body['receiptText'], '');
        expect(r.url.path, '/v1/category');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'source': 'gemini',
              'model': 'gemini-3.8-flash',
              'category': 'Khác',
              'reason': 'Kiểm tra.',
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      try {
        expect(
          await AiService(client: c)
              .checkGemini(baseUrl: 'http://127.0.0.1:8787', token: 'a' * 32),
          'gemini-3.8-flash',
        );
      } finally {
        c.close();
      }
    },
  );
  test('specific failure code and safe request ID are visible', () async {
    final c = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({'error': 'AI_NETWORK', 'requestId': '1234abcd'}),
        ),
        502,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    try {
      await expectLater(
        AiService(client: c)
            .checkGemini(baseUrl: 'http://127.0.0.1:8787', token: 'a' * 32),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('AI_NETWORK'), contains('1234abcd')),
          ),
        ),
      );
    } finally {
      c.close();
    }
  });
}
