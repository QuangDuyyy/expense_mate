import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_mate/services/ai_service.dart';

http.Response _jsonResponse(Object value, int status) => http.Response.bytes(
  utf8.encode(jsonEncode(value)),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('only HTTPS or loopback HTTP is accepted', () {
    expect(
      AiService.endpoint('http://127.0.0.1:8787', '/health').host,
      '127.0.0.1',
    );
    expect(
      AiService.endpoint('https://example.com', '/health').scheme,
      'https',
    );
    for (final value in [
      'http://192.168.1.2:8787',
      'ftp://localhost',
      'https://user:pass@example.com',
    ]) {
      expect(
        () => AiService.endpoint(value, '/health'),
        throwsA(isA<AiFailure>()),
      );
    }
  });
  test('requires a pairing code before network request', () async {
    final service = AiService(
      client: MockClient((_) async => throw StateError('must not call')),
    );
    await expectLater(
      service.suggest(
        baseUrl: 'http://127.0.0.1:8787',
        token: '',
        merchant: 'Coffee',
        receiptText: '',
      ),
      throwsA(isA<AiFailure>()),
    );
  });
  test('returns valid suggestion and sends redacted receipt', () async {
    final service = AiService(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], startsWith('Bearer '));
        expect(request.body.contains('a@example.com'), isFalse);
        return _jsonResponse({
          'category': 'Ăn uống',
          'reason': 'Cà phê',
          'source': 'gemini',
        }, 200);
      }),
    );
    final value = await service.suggest(
      baseUrl: 'http://127.0.0.1:8787',
      token: 'a' * 32,
      merchant: 'Coffee',
      receiptText: 'a@example.com',
    );
    expect(value.category, 'Ăn uống');
    expect(value.reason, 'Cà phê');
  });
  test('rejects invalid AI category rather than applying it', () async {
    final service = AiService(
      client: MockClient(
        (_) async => _jsonResponse({
          'category': 'unknown',
          'reason': 'x',
          'source': 'gemini',
        }, 200),
      ),
    );
    await expectLater(
      service.suggest(
        baseUrl: 'http://127.0.0.1:8787',
        token: 'a' * 32,
        merchant: 'Coffee',
        receiptText: '',
      ),
      throwsA(isA<AiFailure>()),
    );
  });
  test('upstream quota becomes a useful user message', () async {
    final service = AiService(
      client: MockClient(
        (_) async => _jsonResponse({'error': 'AI_QUOTA'}, 502),
      ),
    );
    await expectLater(
      service.suggest(
        baseUrl: 'http://127.0.0.1:8787',
        token: 'a' * 32,
        merchant: 'Coffee',
        receiptText: '',
      ),
      throwsA(
        isA<AiFailure>().having(
          (e) => e.message,
          'message',
          contains('hạn mức'),
        ),
      ),
    );
  });
}
