import 'receipt_details.dart';

class Expense {
  final int? id;
  final String merchant;
  final int amount;
  final DateTime date;
  final String category;
  final String note;
  final String? imagePath;
  final String rawText;
  final ReceiptDetails details;

  const Expense({
    this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.note = '',
    this.imagePath,
    this.rawText = '',
    this.details = const ReceiptDetails(),
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'merchant': merchant,
    'amount': amount,
    'date': date.toIso8601String(),
    'category': category,
    'note': note,
    'image_path': imagePath,
    'raw_text': rawText,
    'receipt_details': details.encode(),
  };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
    id: m['id'] as int,
    merchant: m['merchant'] as String,
    amount: m['amount'] as int,
    date: DateTime.parse(m['date'] as String),
    category: m['category'] as String,
    note: m['note'] as String,
    imagePath: m['image_path'] as String?,
    rawText: m['raw_text'] as String,
    details: ReceiptDetails.decode(m['receipt_details'] as String?),
  );
}
