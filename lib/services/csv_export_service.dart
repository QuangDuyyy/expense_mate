import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/expense.dart';
import '../core/format.dart';

class CsvExportService {
  static String cell(String value) {
    // Spreadsheet formula injection: text starting with formula characters stays text.
    final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(value.trimLeft())
        ? "'$value"
        : value;
    return '"${safe.replaceAll('"', '""')}"';
  }

  static String encode(List<Expense> rows) {
    final lines = <String>['Ngày,Cửa hàng,Số tiền VND,Danh mục,Ghi chú'];
    for (final row in rows) {
      lines.add(
        [
          cell(dayLabel(row.date)),
          cell(row.merchant),
          row.amount.toString(),
          cell(row.category),
          cell(row.note),
        ].join(','),
      );
    }
    return '\ufeff${lines.join('\r\n')}\r\n';
  }

  static Future<File> export(List<Expense> rows) async {
    final dir = await getTemporaryDirectory();
    return File(
      p.join(
        dir.path,
        'ExpenseMate_${DateTime.now().millisecondsSinceEpoch}.csv',
      ),
    ).writeAsString(encode(rows));
  }
}
