import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/receipt_parser.dart';

class BudgetDialog extends StatefulWidget {
  final int current;
  const BudgetDialog({super.key, required this.current});
  @override
  State<BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<BudgetDialog> {
  final form = GlobalKey<FormState>();
  late final controller = TextEditingController(
    text: widget.current > 0 ? widget.current.toString() : '',
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Mục tiêu chi mỗi tháng'),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mục tiêu chỉ để theo dõi, không ngăn bạn lưu khoản chi. Được giữ cho các tháng tiếp theo đến khi bạn đổi.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9., \-]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Mục tiêu (VND)',
              hintText: 'Ví dụ: 3000000',
            ),
            validator: (s) {
              final v = ReceiptParser.parseAmount(s ?? '');
              return v == null || v <= 0 || v > 999999999999
                  ? 'Nhập số tiền nguyên dương hợp lệ.'
                  : null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      if (widget.current > 0)
        TextButton(
          onPressed: () => Navigator.pop(context, 0),
          child: const Text('Bỏ mục tiêu'),
        ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate())
            Navigator.pop(context, ReceiptParser.parseAmount(controller.text));
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
