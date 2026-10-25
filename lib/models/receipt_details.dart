import 'dart:convert';

class ReceiptItem {
  final String name;
  final double? quantity;
  final int? unitPrice;
  final int? lineTotal;
  final bool needsReview;
  const ReceiptItem({
    required this.name,
    this.quantity,
    this.unitPrice,
    this.lineTotal,
    this.needsReview = true,
  });
  bool get complete =>
      name.trim().isNotEmpty &&
      quantity != null &&
      quantity! > 0 &&
      unitPrice != null &&
      lineTotal != null;
  bool get arithmeticMismatch =>
      complete && (quantity! * unitPrice! - lineTotal!).abs() > 1;
  ReceiptItem reviewed() => ReceiptItem(
    name: name,
    quantity: quantity,
    unitPrice: unitPrice,
    lineTotal: lineTotal,
    needsReview: false,
  );
  Map<String, Object?> toJson() => {
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'lineTotal': lineTotal,
    'needsReview': needsReview,
  };
  factory ReceiptItem.fromJson(Map<String, dynamic> m) {
    final q = m['quantity'];
    bool money(Object? v) =>
        v == null || (v is int && v >= 0 && v <= 999999999999);
    if (m['name'] is! String ||
        (m['name'] as String).trim().isEmpty ||
        (m['name'] as String).length > 200 ||
        (q != null && (q is! num || !q.isFinite || q <= 0 || q > 1000000)) ||
        !money(m['unitPrice']) ||
        !money(m['lineTotal']) ||
        (m['needsReview'] != null && m['needsReview'] is! bool))
      throw const FormatException('Chi tiết sản phẩm không hợp lệ.');
    return ReceiptItem(
      name: m['name'] as String,
      quantity: (q as num?)?.toDouble(),
      unitPrice: m['unitPrice'] as int?,
      lineTotal: m['lineTotal'] as int?,
      needsReview: m['needsReview'] as bool? ?? true,
    );
  }
}

class ReceiptDetails {
  final String invoiceNumber;
  final int discount;
  final int surcharge;
  final List<ReceiptItem> items;
  const ReceiptDetails({
    this.invoiceNumber = '',
    this.discount = 0,
    this.surcharge = 0,
    this.items = const [],
  });
  int get itemSum => items.fold(0, (s, i) => s + (i.lineTotal ?? 0));
  int get calculatedTotal => itemSum - discount + surcharge;
  bool get incomplete => items.any((i) => !i.complete);
  bool get needsReview =>
      items.any((i) => i.needsReview || i.arithmeticMismatch);
  List<String> validationProblems(int? invoiceTotal) {
    final result = <String>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index], missing = <String>[];
      if (item.name.trim().isEmpty) missing.add('tên sản phẩm');
      if (item.quantity == null || item.quantity! <= 0) missing.add('số lượng');
      if (item.unitPrice == null) missing.add('đơn giá');
      if (item.lineTotal == null) missing.add('thành tiền');
      final prefix = 'Dòng ${index + 1} “${item.name}”';
      if (missing.isNotEmpty)
        result.add('$prefix còn thiếu: ${missing.join(', ')}.');
      else if (item.arithmeticMismatch)
        result.add(
          '$prefix: số lượng × đơn giá = ${(item.quantity! * item.unitPrice!).round()} VND, nhưng thành tiền là ${item.lineTotal} VND.',
        );
      else if (item.needsReview)
        result.add('$prefix đã có đủ số liệu nhưng chưa xác nhận đối chiếu.');
    }
    if (items.isNotEmpty &&
        !incomplete &&
        invoiceTotal != null &&
        calculatedTotal != invoiceTotal) {
      result.add(
        'Tổng dòng sau giảm giá/phụ phí là $calculatedTotal VND; tổng hóa đơn là $invoiceTotal VND. Chênh ${invoiceTotal - calculatedTotal} VND. Có thể còn thiếu sản phẩm.',
      );
    }
    return result;
  }

  Map<String, Object?> toJson() => {
    'invoiceNumber': invoiceNumber,
    'discount': discount,
    'surcharge': surcharge,
    'items': items.map((i) => i.toJson()).toList(),
  };
  String encode() => jsonEncode(toJson());
  factory ReceiptDetails.decode(String? value) => value == null || value.isEmpty
      ? const ReceiptDetails()
      : ReceiptDetails.fromJson(jsonDecode(value) as Map<String, dynamic>);
  factory ReceiptDetails.fromJson(Map<String, dynamic> m) {
    final n = m['invoiceNumber'] ?? '',
        d = m['discount'] ?? 0,
        s = m['surcharge'] ?? 0,
        rows = m['items'] ?? [];
    if (n is! String ||
        n.length > 100 ||
        d is! int ||
        d < 0 ||
        d > 999999999999 ||
        s is! int ||
        s < 0 ||
        s > 999999999999 ||
        rows is! List ||
        rows.length > 200)
      throw const FormatException('Thông tin hóa đơn không hợp lệ.');
    return ReceiptDetails(
      invoiceNumber: n,
      discount: d,
      surcharge: s,
      items: List.unmodifiable(
        rows.map(
          (v) => ReceiptItem.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      ),
    );
  }
}
