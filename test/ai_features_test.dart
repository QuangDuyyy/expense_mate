import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_mate/services/ai_service.dart';

http.Response reply(Object value, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(value)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, Object?> receipt({
  String? date = '2026-10-25',
  int? amount = 65000,
}) => {
  'source': 'gemini',
  'merchant': {'value': 'Cà phê An', 'evidence': 'Cà phê An'},
  'date': {'value': date, 'evidence': date == null ? '' : 'Ngày 25/10/2026'},
  'amount': {
    'value': amount,
    'evidence': amount == null ? '' : 'Thành tiền 65.000',
  },
  'warnings': <String>[],
};
const url = 'http://127.0.0.1:8787';
final token = 'a' * 32;
void main() {
  test(
    'receipt client preserves Vietnamese and nullable missing fields',
    () async {
      final service = AiService(
        client: MockClient((request) async {
          expect(request.url.path, '/v1/receipt');
          expect(request.body.contains('a@example.com'), isFalse);
          return reply(receipt(date: null));
        }),
      );
      final r = await service.parseReceipt(
        baseUrl: url,
        token: token,
        receiptText: 'Cà phê An\na@example.com\nThành tiền 65.000',
      );
      expect(r.merchant.value, 'Cà phê An');
      expect(r.amount.value, 65000);
      expect(r.date.value, isNull);
    },
  );
  test('receipt client rejects an impossible model date', () async {
    final service = AiService(
      client: MockClient((_) async => reply(receipt(date: '2026-02-31'))),
    );
    await expectLater(
      service.parseReceipt(baseUrl: url, token: token, receiptText: 'text'),
      throwsA(isA<AiFailure>()),
    );
  });
  test('receipt client rejects money without evidence', () async {
    final payload = receipt();
    payload['amount'] = {'value': 65000, 'evidence': ''};
    final service = AiService(client: MockClient((_) async => reply(payload)));
    await expectLater(
      service.parseReceipt(baseUrl: url, token: token, receiptText: 'text'),
      throwsA(isA<AiFailure>()),
    );
  });
  test(
    'outdated server gives a restart instruction for new endpoints',
    () async {
      final service = AiService(
        client: MockClient(
          (_) async => reply({'error': 'NOT_FOUND'}, status: 404),
        ),
      );
      await expectLater(
        service.parseReceipt(baseUrl: url, token: token, receiptText: 'text'),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.message,
            'message',
            contains('bản cũ'),
          ),
        ),
      );
    },
  );
  test(
    'insights client accepts fact IDs and qualitative suggestions',
    () async {
      final service = AiService(
        client: MockClient((request) async {
          expect(request.url.path, '/v1/insights');
          return reply({
            'source': 'gemini',
            'headline': 'Nhìn lại kỳ này',
            'focus': ['total', 'top_category'],
            'tips': ['Xem lại nhóm chi lớn nhất.'],
          });
        }),
      );
      final r = await service.insights(
        baseUrl: url,
        token: token,
        summary: {'budget': null},
      );
      expect(r.focus, ['total', 'top_category']);
      expect(r.tips.first, 'Xem lại nhóm chi lớn nhất.');
    },
  );
  test(
    'numeric AI claims and missing budget references are rejected',
    () async {
      for (final payload in [
        {
          'source': 'gemini',
          'headline': 'Tăng 999%',
          'focus': ['total'],
          'tips': ['Xem lại.'],
        },
        {
          'source': 'gemini',
          'headline': 'Xem lại',
          'focus': ['budget'],
          'tips': ['Đặt mục tiêu.'],
        },
      ]) {
        final service = AiService(
          client: MockClient((_) async => reply(payload)),
        );
        await expectLater(
          service.insights(
            baseUrl: url,
            token: token,
            summary: {'budget': null},
          ),
          throwsA(isA<AiFailure>()),
        );
      }
    },
  );
}
