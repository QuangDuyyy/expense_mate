import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:expense_mate/models/expense.dart';
import 'package:expense_mate/services/spending_summary.dart';
import 'package:expense_mate/services/csv_export_service.dart';

Expense row(
  int amount,
  DateTime date, {
  String category = 'Ăn uống',
  String merchant = 'PRIVATE_SHOP',
  String note = 'PRIVATE_NOTE',
}) => Expense(
  merchant: merchant,
  amount: amount,
  date: date,
  category: category,
  note: note,
);
void main() {
  test('week groups real entries and compares the previous complete week', () {
    final s = SpendingSummary.build(
      [
        row(65000, DateTime(2026, 10, 20)),
        row(35000, DateTime(2026, 10, 25), category: 'Di chuyển'),
        row(50000, DateTime(2026, 10, 13)),
        row(90000, DateTime(2026, 10, 26)),
      ],
      period: SummaryPeriod.week,
      anchor: DateTime(2026, 10, 25),
      now: DateTime(2026, 10, 25),
    );
    expect(s.start, DateTime(2026, 10, 19));
    expect(s.total, 100000);
    expect(s.previousTotal, 50000);
    expect(s.observedDays, 7);
    expect(s.comparisonDays, 7);
    expect(s.changePercent, 100);
    expect(s.average, 14286);
    expect(s.daily.length, 7);
    expect(s.daily[6], 35000);
  });
  test(
    'current week excludes future entries and uses elapsed comparison days',
    () {
      final s = SpendingSummary.build(
        [
          row(65000, DateTime(2026, 10, 20)),
          row(35000, DateTime(2026, 10, 25)),
          row(50000, DateTime(2026, 10, 13)),
          row(99000, DateTime(2026, 10, 18)),
        ],
        period: SummaryPeriod.week,
        anchor: DateTime(2026, 10, 21),
        now: DateTime(2026, 10, 21),
      );
      expect(s.total, 65000);
      expect(s.previousTotal, 50000);
      expect(s.observedDays, 3);
      expect(s.comparisonDays, 3);
    },
  );
  test(
    'current month compares through the same elapsed day where available',
    () {
      final s = SpendingSummary.build(
        [
          row(100000, DateTime(2026, 10, 25)),
          row(300000, DateTime(2026, 10, 30)),
          row(50000, DateTime(2026, 9, 25)),
          row(90000, DateTime(2026, 9, 30)),
        ],
        period: SummaryPeriod.month,
        anchor: DateTime(2026, 10, 25),
        now: DateTime(2026, 10, 25),
        budget: 3000000,
      );
      expect(s.total, 100000);
      expect(s.previousTotal, 50000);
      expect(s.observedDays, 25);
      expect(s.comparisonDays, 25);
      expect(s.budget, 3000000);
      expect(s.daily.length, 31);
    },
  );
  test('leap month and year rollover use calendar boundaries', () {
    final leap = SpendingSummary.build(
      [],
      period: SummaryPeriod.month,
      anchor: DateTime(2024, 2, 15),
      now: DateTime(2024, 3, 1),
    );
    expect(leap.daily.length, 29);
    expect(leap.observedDays, 29);
    expect(leap.comparisonDays, 31);
    final jan = SpendingSummary.build(
      [],
      period: SummaryPeriod.month,
      anchor: DateTime(2027, 1, 10),
      now: DateTime(2027, 1, 10),
    );
    expect(jan.previousStart, DateTime(2026, 12, 1));
  });
  test(
    'empty and future periods never divide by zero or fabricate percent',
    () {
      final s = SpendingSummary.build(
        [],
        period: SummaryPeriod.week,
        anchor: DateTime(2027, 1, 20),
        now: DateTime(2026, 10, 25),
      );
      expect(s.total, 0);
      expect(s.average, 0);
      expect(s.observedDays, 0);
      expect(s.changePercent, isNull);
      expect(s.topIndex, isNull);
    },
  );
  test('weekly summary does not treat a monthly target as weekly budget', () {
    final s = SpendingSummary.build(
      [row(65000, DateTime(2026, 10, 20))],
      period: SummaryPeriod.week,
      anchor: DateTime(2026, 10, 25),
      now: DateTime(2026, 10, 25),
      budget: 3000000,
    );
    expect(s.budget, isNull);
  });
  test('AI payload contains aggregates and never merchant or notes', () {
    final s = SpendingSummary.build(
      [row(65000, DateTime(2026, 10, 20))],
      period: SummaryPeriod.week,
      anchor: DateTime(2026, 10, 25),
      now: DateTime(2026, 10, 25),
    );
    final json = jsonEncode(s.toAiPayload());
    expect(json.contains('PRIVATE_SHOP'), isFalse);
    expect(json.contains('PRIVATE_NOTE'), isFalse);
    expect(s.toAiPayload()['count'], 1);
    expect(
      (s.toAiPayload()['totals'] as List).fold<int>(
        0,
        (a, b) => a + (b as int),
      ),
      s.total,
    );
  });
  test('CSV preserves Vietnamese, quotes and prevents formula injection', () {
    final csv = CsvExportService.encode([
      row(
        65000,
        DateTime(2026, 10, 25),
        merchant: '=HYPERLINK("x")',
        note: 'Cà phê, bánh\nGhi chú',
      ),
    ]);
    expect(csv.startsWith('\ufeff'), isTrue);
    expect(csv.contains("'=HYPERLINK"), isTrue);
    expect(csv.contains('""x""'), isTrue);
    expect(csv.contains('Cà phê, bánh'), isTrue);
    expect(csv.contains(',65000,'), isTrue);
  });
}
