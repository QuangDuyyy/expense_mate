import '../models/receipt_details.dart';
import 'receipt_parser.dart';

class ReceiptLine {
  final String text;
  final double left, top, right, bottom;
  const ReceiptLine(this.text, this.left, this.top, this.right, this.bottom);
}

class ReceiptDocument {
  final String text;
  final ReceiptDetails details;
  const ReceiptDocument(this.text, this.details);
  factory ReceiptDocument.fromLines(List<ReceiptLine> input) {
    final lines = [...input]..sort((a, b) => a.top.compareTo(b.top));
    final rows = <List<ReceiptLine>>[];
    for (final line in lines) {
      if (rows.isNotEmpty) {
        final first = rows.last.first;
        final overlap =
            (first.bottom < line.bottom ? first.bottom : line.bottom) -
            (first.top > line.top ? first.top : line.top);
        final minHeight = (first.bottom - first.top) < (line.bottom - line.top)
            ? first.bottom - first.top
            : line.bottom - line.top;
        if (minHeight > 0 && overlap / minHeight >= 0.45) {
          rows.last.add(line);
          continue;
        }
      }
      rows.add([line]);
    }
    final text = rows
        .map((r) {
          r.sort((a, b) => a.left.compareTo(b.left));
          return r.map((l) => l.text).join(' ');
        })
        .join('\n');
    return ReceiptDocument(text, ReceiptDocument.parseItems(text));
  }
  static ReceiptDetails parseItems(String text) {
    final items = <ReceiptItem>[];
    bool table = false;
    String pending = '';
    for (final raw in text.split('\n')) {
      final line = raw.trim(), n = ReceiptParser.normalize(line);
      if (RegExp(r'(tong cong|tong tien|tong thanh toan|grand total|\btotal\b)')
          .hasMatch(n))
        break;
      if (RegExp(r'(don gia|thanh tien|\bqty\b|\bquantity\b)').hasMatch(n)) {
        table = true;
        continue;
      }
      if (!table ||
          line.isEmpty ||
          RegExp(r'^(tien|sl|so luong|price|amount)$').hasMatch(n))
        continue;
      if (RegExp(r'^[-_.\s]+$').hasMatch(line)) continue;
      final tokens = RegExp(r'\d{1,3}(?:[.,]\d{3})+|\d+(?:[.,]\d+)?')
          .allMatches(line)
          .toList();
      // Only numeric rows under an explicit table heading are interpreted.
      if (pending.isNotEmpty &&
          tokens.length >= 2 &&
          !RegExp(r'[a-z]')
              .hasMatch(n.replaceAll(RegExp(r'vnd|d(?=\s|$)'), '').trim())) {
        final unit = ReceiptParser.parseAmount(tokens[0][0]!);
        final qty = double.tryParse(tokens[1][0]!.replaceAll(',', '.'));
        final total = tokens.length >= 3
            ? ReceiptParser.parseAmount(tokens[2][0]!)
            : null;
        if (unit != null &&
            unit <= 999999999999 &&
            (total == null || total <= 999999999999) &&
            qty != null &&
            qty > 0 &&
            qty <= 1000000 &&
            items.length < 200) {
          items.add(
            ReceiptItem(
              name: pending,
              quantity: qty,
              unitPrice: unit,
              lineTotal: total,
            ),
          );
          pending = '';
        }
      } else if (RegExp(r'[a-z]').hasMatch(n) &&
          !RegExp(r'(hotline|cam on|doi tra|hoa don|don gia|^sl$)')
              .hasMatch(n)) {
        pending = pending.isEmpty ? line : '$pending $line';
        if (pending.length > 200)
          pending = line.length <= 200 ? line : line.substring(0, 200);
      }
    }
    return ReceiptDetails(items: items);
  }
}
