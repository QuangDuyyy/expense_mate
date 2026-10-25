import 'package:flutter/material.dart';

import '../models/receipt_details.dart';
import '../services/receipt_parser.dart';
import '../core/format.dart';
import 'design.dart';

class ReceiptItemsEditor extends StatelessWidget {
  final ReceiptDetails value;
  final ValueChanged<ReceiptDetails> onChanged;
  final bool enabled;
  const ReceiptItemsEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  void change(List<ReceiptItem> rows) => onChanged(
    ReceiptDetails(
      invoiceNumber: value.invoiceNumber,
      discount: value.discount,
      surcharge: value.surcharge,
      items: List.unmodifiable(rows),
    ),
  );
  Future<void> edit(BuildContext context, int? index) async {
    final result = await showDialog<ReceiptItem>(
      context: context,
      builder: (_) =>
          ReceiptItemDialog(item: index == null ? null : value.items[index]),
    );
    if (result == null) return;
    final rows = [...value.items];
    if (index == null) {
      rows.add(result);
    } else {
      rows[index] = result;
    }
    change(rows);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle(
        'Chi tiết sản phẩm',
        subtitle:
            '${value.items.length} dòng • VND. Kiểm tra chữ mờ trước khi lưu.',
      ),
      if (value.items.isEmpty)
        const NoticeBox(
          'Chưa có sản phẩm. Bạn có thể thêm tay hoặc nhờ AI phân tích ảnh. Hóa đơn cũ không bắt buộc phải bổ sung sản phẩm.',
        ),
      if (value.items.any(
        (i) => i.complete && !i.arithmeticMismatch && i.needsReview,
      ))
        OutlinedButton.icon(
          onPressed: !enabled
              ? null
              : () async {
                  final count = value.items
                      .where(
                        (i) =>
                            i.complete &&
                            !i.arithmeticMismatch &&
                            i.needsReview,
                      )
                      .length;
                  final approved = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Xác nhận các dòng đã đối chiếu?'),
                      content: Text(
                        'Đánh dấu $count dòng có đủ thông tin và phép tính khớp là đã được bạn kiểm tra với hóa đơn. Không sửa số tiền và không xác nhận dòng còn thiếu/sai phép tính.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Xem lại'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Tôi đã đối chiếu'),
                        ),
                      ],
                    ),
                  );
                  if (approved == true)
                    change(
                      value.items
                          .map(
                            (i) => i.complete && !i.arithmeticMismatch
                                ? i.reviewed()
                                : i,
                          )
                          .toList(),
                    );
                },
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Xác nhận các dòng đã đủ và khớp'),
        ),
      for (var i = 0; i < value.items.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        value.items[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sửa sản phẩm ${i + 1}',
                      onPressed: enabled ? () => edit(context, i) : null,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                  ],
                ),
                Text(
                  '${value.items[i].quantity ?? '?'} × ${value.items[i].unitPrice == null ? 'Chưa rõ' : money(value.items[i].unitPrice!)}',
                ),
                const SizedBox(height: 8),
                Text(
                  value.items[i].lineTotal == null
                      ? 'Chưa rõ thành tiền'
                      : money(value.items[i].lineTotal!),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (!value.items[i].complete)
                  const NoticeBox(
                    'Còn thiếu số lượng, đơn giá hoặc thành tiền.',
                  ),
                if (value.items[i].arithmeticMismatch)
                  const NoticeBox(
                    'Số lượng × đơn giá chưa khớp thành tiền. Kiểm tra giá sau giảm hoặc sửa số liệu.',
                  ),
                if (value.items[i].needsReview)
                  TextButton.icon(
                    onPressed: enabled && value.items[i].complete
                        ? () {
                            final rows = [...value.items];
                            rows[i] = rows[i].reviewed();
                            change(rows);
                          }
                        : null,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Tôi đã đối chiếu dòng này'),
                  ),
                if (!value.items[i].needsReview && value.items[i].complete)
                  const Text('Đã đối chiếu', style: TextStyle(fontSize: 12)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: enabled
                        ? () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Xóa dòng sản phẩm?'),
                                content: Text(value.items[i].name),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Giữ lại'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Xóa'),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true) {
                              final rows = [...value.items]..removeAt(i);
                              change(rows);
                            }
                          }
                        : null,
                    child: const Text('Xóa dòng'),
                  ),
                ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: enabled && value.items.length < 200
            ? () => edit(context, null)
            : null,
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm'),
      ),
    ],
  );
}

class ReceiptItemDialog extends StatefulWidget {
  final ReceiptItem? item;
  const ReceiptItemDialog({super.key, this.item});
  @override
  State<ReceiptItemDialog> createState() => _ReceiptItemDialogState();
}

class _ReceiptItemDialogState extends State<ReceiptItemDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.item?.name ?? '');
  late final qty = TextEditingController(
    text: widget.item?.quantity?.toString() ?? '1',
  );
  late final unit = TextEditingController(
    text: widget.item?.unitPrice?.toString() ?? '',
  );
  late final total = TextEditingController(
    text: widget.item?.lineTotal?.toString() ?? '',
  );
  @override
  void dispose() {
    name.dispose();
    qty.dispose();
    unit.dispose();
    total.dispose();
    super.dispose();
  }

  String? moneyError(String? text) {
    final n = ReceiptParser.parseAmount(text ?? '');
    return n == null || n > 999999999999 ? 'Nhập VND nguyên không âm.' : null;
  }

  double? get quantity => double.tryParse(qty.text.replaceAll(',', '.'));
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.item == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm'),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Tên sản phẩm'),
            validator: (s) => s == null || s.trim().isEmpty || s.length > 200
                ? 'Nhập tên tối đa 200 ký tự.'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Số lượng (có thể là kg/lít)',
            ),
            validator: (_) =>
                quantity == null ||
                    !quantity!.isFinite ||
                    quantity! <= 0 ||
                    quantity! > 1000000
                ? 'Nhập số lượng dương hợp lệ.'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: unit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Đơn giá VND'),
            validator: moneyError,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: total,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Thành tiền trên hóa đơn',
            ),
            validator: moneyError,
          ),
          TextButton(
            onPressed: () {
              final u = ReceiptParser.parseAmount(unit.text), q = quantity;
              if (u != null &&
                  q != null &&
                  q.isFinite &&
                  q > 0 &&
                  u * q <= 999999999999)
                total.text = (u * q).round().toString();
            },
            child: const Text('Điền từ số lượng × đơn giá'),
          ),
          const Text(
            'Số tính toán cần được bạn đối chiếu với hóa đơn.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate())
            Navigator.pop(
              context,
              ReceiptItem(
                name: name.text.trim(),
                quantity: quantity,
                unitPrice: ReceiptParser.parseAmount(unit.text),
                lineTotal: ReceiptParser.parseAmount(total.text),
                needsReview: false,
              ),
            );
        },
        child: const Text('Xác nhận dòng'),
      ),
    ],
  );
}
