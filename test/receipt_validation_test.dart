import 'package:flutter_test/flutter_test.dart';
import 'package:expense_mate/models/receipt_details.dart';

void main() {
  test(
    'single 30000 line identifies unreviewed row and exact missing total',
    () {
      const d = ReceiptDetails(
        items: [
          ReceiptItem(
            name: 'Xúc xích',
            quantity: 3,
            unitPrice: 10000,
            lineTotal: 30000,
          ),
        ],
      );
      final p = d.validationProblems(80000).join(' ');
      expect(p, contains('Dòng 1'));
      expect(p, contains('chưa xác nhận'));
      expect(p, contains('50000'));
    },
  );
  test(
    'missing field, arithmetic and verification have distinct explanations',
    () {
      const d = ReceiptDetails(
        items: [
          ReceiptItem(name: 'A', quantity: 1, unitPrice: 10000),
          ReceiptItem(
            name: 'B',
            quantity: 3,
            unitPrice: 10000,
            lineTotal: 9,
            needsReview: false,
          ),
        ],
      );
      final p = d.validationProblems(80000).join(' ');
      expect(p, contains('thành tiền'));
      expect(p, contains('Dòng 2'));
      expect(p, contains('30000 VND'));
      expect(p, contains('9 VND'));
    },
  );
  test('reviewed correct lines and adjustments allow validation', () {
    const d = ReceiptDetails(
      discount: 1000,
      surcharge: 2000,
      items: [
        ReceiptItem(
          name: 'A',
          quantity: 1,
          unitPrice: 80000,
          lineTotal: 80000,
          needsReview: false,
        ),
      ],
    );
    expect(d.validationProblems(81000), isEmpty);
  });
}
