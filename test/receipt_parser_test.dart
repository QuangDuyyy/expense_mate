import 'package:flutter_test/flutter_test.dart';
import 'package:expense_mate/services/receipt_parser.dart';

void main() {
  group('VND amounts', () {
    test('supports plain digits and thousands separators', () {
      for (final input in [
        '150000',
        '150.000',
        '150,000',
        '150 000',
        '150.000 VND',
      ]) {
        expect(ReceiptParser.parseAmount(input), 150000, reason: input);
      }
      expect(ReceiptParser.parseAmount('1.250.000'), 1250000);
    });
    test('does not guess malformed or decimal amounts', () {
      for (final input in ['', 'abc', '65.00', '12,34', '-100', '1.000,000']) {
        expect(ReceiptParser.parseAmount(input), isNull, reason: input);
      }
    });
  });
  test('reads accented total, merchant and date; ignores change', () {
    final r = ReceiptParser.parse(
      'HIGHLANDS COFFEE\nHÓA ĐƠN\nNgày: 25/10/2026\nTổng tiền: 65.000 đ\nTiền khách đưa: 100.000\nTiền thừa: 35.000',
    );
    expect(r.merchant, 'HIGHLANDS COFFEE');
    expect(r.amount, 65000);
    expect(r.date, DateTime(2026, 10, 25));
  });
  test('prefers final total over subtotal', () {
    final r = ReceiptParser.parse(
      'SHOP\nSubtotal 100.000\nGrand total 110.000\nCash 200.000\nChange 90.000',
    );
    expect(r.amount, 110000);
  });
  test('reads amount on a standalone following line', () {
    expect(ReceiptParser.parse('SHOP\nTỔNG CỘNG\n150000').amount, 150000);
  });
  test('does not use a later product line as a total', () {
    expect(ReceiptParser.parse('SHOP\nTOTAL\n2 COFFEE 50000').amount, isNull);
  });
  test('rejects impossible date and missing total', () {
    final r = ReceiptParser.parse('SHOP\n31/02/2026\nĐiện thoại: 0901234567');
    expect(r.date, isNull);
    expect(r.amount, isNull);
  });
  test('does not truncate decimal amount into integer', () {
    expect(ReceiptParser.parse('SHOP\nTOTAL 65.000,50').amount, isNull);
  });
  test('does not turn a negative total into positive spending', () {
    expect(ReceiptParser.parse('SHOP\nTOTAL -65.000').amount, isNull);
  });
}
