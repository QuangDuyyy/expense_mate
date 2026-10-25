import 'package:flutter_test/flutter_test.dart';
import 'package:expense_mate/models/expense.dart';
import 'package:expense_mate/models/receipt_details.dart';
import 'package:expense_mate/services/receipt_layout.dart';
import 'package:expense_mate/services/receipt_parser.dart';

void main() {
  test(
    'WinMart table retains quantities and missing total without guessing',
    () {
      final d = ReceiptDocument.parseItems(
        'SIÊU THỊ WINMART\nĐơn giá SL Thành tiền\nSữa chua trân châu đường\nđen\n34.000 1 34.000\nXúc xích sườn hầm (cái)\n10.000 3 30.000\nXúc xích siu to (cái)\n16.000 1\nTổng cộng 80.000',
      );
      expect(d.items.length, 3);
      expect(d.items[0].name, 'Sữa chua trân châu đường đen');
      expect(d.items[1].quantity, 3);
      expect(d.items[2].lineTotal, isNull);
      expect(d.incomplete, isTrue);
      expect(d.itemSum, 64000);
    },
  );
  test('geometric OCR merges numbers on the same row before parsing', () {
    final d = ReceiptDocument.fromLines([
      const ReceiptLine('Tổng cộng', 10, 100, 100, 120),
      const ReceiptLine('80.000', 200, 101, 270, 121),
      const ReceiptLine('WINMART', 10, 0, 100, 20),
    ]);
    expect(ReceiptParser.parse(d.text).amount, 80000);
  });
  test('table numeric rows can include Vietnamese currency suffixes', () {
    final d = ReceiptDocument.parseItems(
      'Đơn giá SL Thành tiền\nBánh\n10.000đ 2 20.000đ\nTổng cộng 20.000',
    );
    expect(d.items.single.lineTotal, 20000);
  });
  test('noisy OCR digits are not salvaged into a one digit total', () {
    expect(ReceiptParser.parse('SHOP\nTổng cộng 9O.OOO').amount, isNull);
    expect(ReceiptParser.parse('SHOP\nTổng cộng 9').amount, 9);
  });
  test('receipt details survive SQLite and backup map round trips', () {
    const d = ReceiptDetails(
      invoiceNumber: 'A1',
      discount: 1000,
      surcharge: 2000,
      items: [
        ReceiptItem(
          name: 'Sản phẩm',
          quantity: 3,
          unitPrice: 10000,
          lineTotal: 30000,
          needsReview: false,
        ),
      ],
    );
    final e = Expense(
      id: 1,
      merchant: 'SHOP',
      amount: 31000,
      date: DateTime(2026, 10, 25),
      category: 'Ăn uống',
      details: d,
    );
    final copy = Expense.fromMap(e.toMap());
    expect(copy.details.items.single.quantity, 3);
    expect(copy.details.calculatedTotal, 31000);
    expect(copy.details.needsReview, isFalse);
    final legacy = e.toMap()..remove('receipt_details');
    expect(Expense.fromMap(legacy).details.items, isEmpty);
  });
  test('invalid product data is rejected; weighted quantity and free line are allowed', () {
    expect(
      () => ReceiptItem.fromJson({
        'name': 'X',
        'quantity': -1,
        'unitPrice': 1,
        'lineTotal': 1,
      }),
      throwsFormatException,
    );
    final item = ReceiptItem.fromJson({
      'name': 'Rau',
      'quantity': 0.5,
      'unitPrice': 20000,
      'lineTotal': 10000,
    });
    expect(item.arithmeticMismatch, isFalse);
    expect(
      const ReceiptItem(
        name: 'Tặng',
        quantity: 1,
        unitPrice: 0,
        lineTotal: 0,
      ).complete,
      isTrue,
    );
  });
  test('arithmetic mismatch and pending verification remain distinct', () {
    const i = ReceiptItem(
      name: 'X',
      quantity: 3,
      unitPrice: 10000,
      lineTotal: 9,
    );
    expect(i.arithmeticMismatch, isTrue);
    expect(i.reviewed().arithmeticMismatch, isTrue);
  });
}
