import 'dart:convert';
import 'dart:math' as math;

import '../models/expense.dart';
import '../core/expense_values.dart';

enum SummaryPeriod { week, month }

class SpendingSummary {
  final SummaryPeriod period;
  final DateTime start;
  final DateTime end;
  final DateTime previousStart;
  final int observedDays;
  final int comparisonDays;
  final List<Expense> entries;
  final List<Expense> previousEntries;
  final List<int> totals;
  final List<int> previousTotals;
  final List<int> daily;
  final int? budget;
  const SpendingSummary._({
    required this.period,
    required this.start,
    required this.end,
    required this.previousStart,
    required this.observedDays,
    required this.comparisonDays,
    required this.entries,
    required this.previousEntries,
    required this.totals,
    required this.previousTotals,
    required this.daily,
    this.budget,
  });

  static int calendarDays(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  factory SpendingSummary.build(
    List<Expense> items, {
    required SummaryPeriod period,
    required DateTime anchor,
    required DateTime now,
    int? budget,
  }) {
    final date = dayOnly(anchor), today = dayOnly(now);
    final start = period == SummaryPeriod.week
        ? date.subtract(Duration(days: date.weekday - 1))
        : DateTime(date.year, date.month);
    final end = period == SummaryPeriod.week
        ? start.add(const Duration(days: 7))
        : DateTime(date.year, date.month + 1);
    final previousStart = period == SummaryPeriod.week
        ? start.subtract(const Duration(days: 7))
        : DateTime(date.year, date.month - 1);
    final fullDays = calendarDays(start, end),
        previousFull = calendarDays(previousStart, start);
    final observed = today.isBefore(start)
        ? 0
        : today.isBefore(end)
        ? calendarDays(start, today) + 1
        : fullDays;
    final closed = !today.isBefore(end);
    final comparison = closed ? previousFull : math.min(observed, previousFull);
    final usedEnd = start.add(Duration(days: observed));
    final previousEnd = previousStart.add(Duration(days: comparison));
    final selected = items.where((e) {
      final d = dayOnly(e.date);
      return !d.isBefore(start) && d.isBefore(usedEnd);
    }).toList();
    final previous = items.where((e) {
      final d = dayOnly(e.date);
      return !d.isBefore(previousStart) && d.isBefore(previousEnd);
    }).toList();
    List<int> group(List<Expense> rows) {
      final values = List<int>.filled(categories.length, 0);
      for (final row in rows) {
        values[categoryIndex(row.category)] += row.amount;
      }
      return values;
    }

    final daily = List<int>.filled(fullDays, 0);
    for (final row in selected) {
      daily[calendarDays(start, row.date)] += row.amount;
    }
    return SpendingSummary._(
      period: period,
      start: start,
      end: end,
      previousStart: previousStart,
      observedDays: observed,
      comparisonDays: comparison,
      entries: List.unmodifiable(selected),
      previousEntries: List.unmodifiable(previous),
      totals: List.unmodifiable(group(selected)),
      previousTotals: List.unmodifiable(group(previous)),
      daily: List.unmodifiable(daily),
      budget: period == SummaryPeriod.month && budget != null && budget > 0
          ? budget
          : null,
    );
  }
  int get total => totals.fold(0, (a, b) => a + b);
  int get previousTotal => previousTotals.fold(0, (a, b) => a + b);
  int get average => observedDays == 0 ? 0 : (total / observedDays).round();
  double? get changePercent =>
      previousTotal == 0 ? null : (total - previousTotal) / previousTotal * 100;
  int? get topIndex =>
      total == 0 ? null : totals.indexOf(totals.reduce(math.max));
  String get comparisonLabel =>
      '$observedDays ngày kỳ này / $comparisonDays ngày kỳ trước';
  String get coverage => observedDays == 0
      ? 'Kỳ trong tương lai, chưa có chi tiêu thực tế.'
      : observedDays < daily.length
      ? 'Đã tính $observedDays/${daily.length} ngày; chưa tính khoản có ngày tương lai.'
      : 'Đã tính toàn bộ kỳ đã chọn.';
  Map<String, Object?> toAiPayload() => {
    'period': period.name,
    'totals': totals,
    'previousTotals': previousTotals,
    'count': entries.length,
    'previousCount': previousEntries.length,
    'observedDays': observedDays,
    'comparisonDays': comparisonDays,
    'budget': budget,
  };
  String get signature =>
      '${start.toIso8601String()}/${jsonEncode(toAiPayload())}';
}
