// Pure Dart: no UI, database or ML Kit dependency. Regex is not AI.
class ParsedReceipt {
  final String? merchant;
  final int? amount;
  final DateTime? date;
  const ParsedReceipt({this.merchant, this.amount, this.date});
}

class ReceiptParser {
  static String normalize(String input) {
    var s = input.toLowerCase();
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    groups.forEach((base, chars) {
      for (final rune in chars.runes) {
        s = s.replaceAll(String.fromCharCode(rune), base);
      }
    });
    return s;
  }

  // VND integer amounts only: 65000, 65.000, 65,000, 65 000.
  // Decimal-form currency is left to manual verification, not guessed.
  static int? parseAmount(String input) {
    final s = input
        .trim()
        .replaceAll(RegExp(r'vn[dđ]|đ', caseSensitive: false), '')
        .trim();
    if (RegExp(r'^\d+$').hasMatch(s)) return int.tryParse(s);
    if (RegExp(r'^\d{1,3}([., ])\d{3}(?:\1\d{3})*$').hasMatch(s)) {
      return int.tryParse(s.replaceAll(RegExp(r'[., ]'), ''));
    }
    return null;
  }

  static ParsedReceipt parse(String raw) {
    final lines = raw
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    String? merchant;
    for (final line in lines.take(6)) {
      final n = normalize(line);
      if (RegExp(r'[a-z]').hasMatch(n) &&
          !RegExp(
            r'(hoa don|receipt|invoice|dia chi|address|mst|ma so|tel|hotline|ngay|date|tong|total|thanh toan)',
          ).hasMatch(n) &&
          !RegExp(r'^\d').hasMatch(n)) {
        merchant = line;
        break;
      }
    }
    DateTime? date;
    final pattern = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b');
    for (final m in pattern.allMatches(raw)) {
      final d = int.parse(m[1]!), mo = int.parse(m[2]!), y = int.parse(m[3]!);
      final candidate = DateTime(y, mo, d);
      if (candidate.day == d &&
          candidate.month == mo &&
          y >= 2000 &&
          y <= 2100) {
        date = candidate;
        break;
      }
    }
    int? amount;
    var bestScore = -1;
    for (var i = 0; i < lines.length; i++) {
      final n = normalize(lines[i]);
      if (RegExp(
        r'(khach dua|tien khach|tien thua|tien tra lai|change|cash|sub.?total|tam tinh|vat|thue|giam gia)',
      ).hasMatch(n))
        continue;
      var score = 0;
      if (RegExp(
        r'(tong thanh toan|tong cong|grand total|amount due|total due)',
      ).hasMatch(n)) {
        score = 3;
      } else if (RegExp(r'(tong tien|thanh toan|\btotal\b)').hasMatch(n)) {
        score = 2;
      }
      if (score == 0) continue;
      final keyword = RegExp(
        r'(tong thanh toan|tong cong|grand total|amount due|total due|tong tien|thanh toan|\btotal\b)',
      ).firstMatch(n)!;
      var tail = lines[i].substring(keyword.end);
      // Only accept standalone money on next line if the keyword line has no number.
      if (!RegExp(r'\d').hasMatch(tail) &&
          i + 1 < lines.length &&
          RegExp(r'^[\d.,\s]+(?:[vV][nN][dDĐđ]|[đĐ])?$')
              .hasMatch(lines[i + 1])) {
        tail = lines[i + 1];
      }
      // Never salvage the first digit from a noisy OCR fragment such as 9O.OOO.
      final cleaned = tail.trim().replaceFirst(
        RegExp(r'^(?:[:=：]\s*|\.\s+)'),
        '',
      );
      final value = parseAmount(cleaned);
      if (value != null && value > 0 && score >= bestScore) {
        amount = value;
        bestScore = score;
      }
    }
    return ParsedReceipt(merchant: merchant, amount: amount, date: date);
  }
}
