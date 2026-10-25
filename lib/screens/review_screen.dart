import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../models/expense.dart';
import '../models/receipt_details.dart';
import '../services/receipt_layout.dart';
import '../widgets/receipt_items_editor.dart';
import '../services/receipt_parser.dart';
import '../services/photo_storage.dart';
import '../services/ai_service.dart';
import '../state/expense_store.dart';
import '../widgets/design.dart';
import 'ai_settings_screen.dart';

class ReviewScreen extends StatefulWidget {
  final Expense? existing;
  final String? imagePath;
  final String rawText;
  final bool ocrFailed;
  final AiService aiService;
  final ReceiptDetails? initialDetails;
  const ReviewScreen({
    super.key,
    this.existing,
    this.initialDetails,
    this.imagePath,
    this.rawText = '',
    this.ocrFailed = false,
    this.aiService = const AiService(),
  });
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController merchant;
  late final TextEditingController amount;
  late final TextEditingController note;
  late final TextEditingController raw;
  late final String? photo;
  late String category;
  DateTime? date;
  final invoiceNumber = TextEditingController();
  final discount = TextEditingController(text: '0');
  final surcharge = TextEditingController(text: '0');
  List<ReceiptItem> items = [];
  int reviewTab = 0;
  bool verified = false;
  ReceiptDetails get details => ReceiptDetails(
    invoiceNumber: invoiceNumber.text.trim(),
    discount: ReceiptParser.parseAmount(discount.text) ?? 0,
    surcharge: ReceiptParser.parseAmount(surcharge.text) ?? 0,
    items: List.unmodifiable(items),
  );
  bool saving = false;
  String? aiTask;
  String? aiError;
  CategorySuggestion? categoryResult;
  ReceiptSuggestion? receiptResult;
  bool useMerchant = false, useAmount = false, useDate = false;
  bool get busy => saving || aiTask != null;
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    raw = TextEditingController(text: e?.rawText ?? widget.rawText);
    photo = e?.imagePath ?? widget.imagePath;
    final initial =
        e?.details ??
        widget.initialDetails ??
        ReceiptDocument.parseItems(raw.text);
    items = [...initial.items];
    invoiceNumber.text = initial.invoiceNumber;
    discount.text = initial.discount.toString();
    surcharge.text = initial.surcharge.toString();
    reviewTab = items.isEmpty ? 0 : 1;
    final parsed = ReceiptParser.parse(raw.text);
    merchant = TextEditingController(
      text: e?.merchant ?? parsed.merchant ?? '',
    );
    amount = TextEditingController(
      text: (e?.amount ?? parsed.amount)?.toString() ?? '',
    );
    note = TextEditingController(text: e?.note ?? '');
    category = e?.category ?? 'Khác';
    date = e?.date ?? parsed.date;
  }

  @override
  void dispose() {
    invoiceNumber.dispose();
    discount.dispose();
    surcharge.dispose();
    merchant.dispose();
    amount.dispose();
    note.dispose();
    raw.dispose();
    super.dispose();
  }

  Future<SharedPreferences?> configuration() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return null;
    if ((prefs.getString('ai_token') ?? '').isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
      );
      return null;
    }
    return prefs;
  }

  Future<bool> consent(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gửi nội dung cho Gemini?'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chỉ gửi phần văn bản dưới đây qua dịch vụ trên laptop đến Google Gemini. Không gửi ảnh hoặc ghi chú. '
                  'Email và số điện thoại được che theo quy tắc nhưng có thể còn thông tin cá nhân khác; hãy xem trước khi đồng ý.',
                ),
                const SizedBox(height: 12),
                SelectableText(text),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đồng ý gửi'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> askAi({required bool receipt}) async {
    if (busy) return;
    final cleanRaw = AiService.limit(AiService.redact(raw.text.trim()), 6000);
    final cleanMerchant = AiService.limit(
      AiService.redact(merchant.text.trim()),
      200,
    );
    if (receipt && cleanRaw.length < 3) {
      setState(
        () => aiError = 'Chưa có văn bản OCR để phân tích. Chọn ảnh rõ hơn hoặc nhập thông tin thủ công.',
      );
      return;
    }
    if (!receipt && cleanRaw.isEmpty && cleanMerchant.isEmpty) {
      setState(() => aiError = 'Nhập tên khoản chi hoặc quét hóa đơn trước.');
      return;
    }
    final prefs = await configuration();
    if (prefs == null || !mounted) return;
    if (!await consent(receipt ? cleanRaw : '$cleanMerchant\n$cleanRaw') ||
        !mounted)
      return;
    setState(() {
      aiTask = receipt ? 'receipt' : 'category';
      aiError = null;
      if (receipt) {
        receiptResult = null;
      } else {
        categoryResult = null;
      }
    });
    try {
      final base = prefs.getString('ai_url') ?? 'http://127.0.0.1:8787',
          token = prefs.getString('ai_token')!;
      if (receipt) {
        final result = await widget.aiService.parseReceipt(
          baseUrl: base,
          token: token,
          receiptText: cleanRaw,
        );
        if (mounted)
          setState(() {
            receiptResult = result;
            useMerchant =
                merchant.text.trim().isEmpty && result.merchant.value != null;
            useAmount =
                ReceiptParser.parseAmount(amount.text) == null &&
                result.amount.value != null;
            useDate = date == null && result.date.value != null;
          });
      } else {
        final result = await widget.aiService.suggest(
          baseUrl: base,
          token: token,
          merchant: cleanMerchant,
          receiptText: cleanRaw,
        );
        if (mounted) setState(() => categoryResult = result);
      }
    } catch (e) {
      if (mounted) setState(() => aiError = e.toString());
    } finally {
      if (mounted) setState(() => aiTask = null);
    }
  }

  void applyReceipt() {
    final r = receiptResult;
    if (r == null || busy) return;
    setState(() {
      verified = false;
      if (useMerchant && r.merchant.value != null)
        merchant.text = r.merchant.value!;
      if (useAmount && r.amount.value != null)
        amount.text = r.amount.value.toString();
      if (useDate && r.date.value != null) date = r.date.value;
      useMerchant = false;
      useAmount = false;
      useDate = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã điền các mục bạn chọn. Hãy đối chiếu hóa đơn rồi xác nhận lưu.',
        ),
      ),
    );
  }

  void parseMissing() {
    final parsed = ReceiptParser.parse(raw.text);
    setState(() {
      verified = false;
      if (items.isEmpty)
        items = [...ReceiptDocument.parseItems(raw.text).items];
      if (merchant.text.trim().isEmpty && parsed.merchant != null)
        merchant.text = parsed.merchant!;
      if (ReceiptParser.parseAmount(amount.text) == null &&
          parsed.amount != null)
        amount.text = parsed.amount.toString();
      date ??= parsed.date;
    });
  }

  Future<void> save() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    final parsedMoney = ReceiptParser.parseAmount(amount.text);
    final problems = <String>[];
    int targetTab = 2;
    if (merchant.text.trim().isEmpty ||
        merchant.text.trim().length > 200 ||
        parsedMoney == null ||
        parsedMoney <= 0 ||
        parsedMoney > 999999999999) {
      problems.add(
        'Kiểm tra tên cửa hàng và tổng tiền dương trong mục Hóa đơn.',
      );
      targetTab = 0;
    }
    if (invoiceNumber.text.length > 100 ||
        [discount.text, surcharge.text].any((v) {
          final n = ReceiptParser.parseAmount(v);
          return n == null || n > 999999999999;
        })) {
      problems.add(
        'Mã hóa đơn tối đa 100 ký tự; giảm giá/phụ phí cần VND không âm.',
      );
      targetTab = 0;
    }
    final lineProblems = details.validationProblems(parsedMoney);
    problems.addAll(lineProblems);
    if (lineProblems.isNotEmpty) targetTab = 1;
    final selected = date;
    if (selected == null) {
      problems.add('Chưa có ngày mua. Chọn ngày thực tế trong mục Hóa đơn.');
      if (lineProblems.isEmpty) targetTab = 0;
    }
    if ((photo != null || items.isNotEmpty) && !verified)
      problems.add('Chưa tích xác nhận toàn hóa đơn tại mục Đối chiếu.');
    if (problems.isNotEmpty) {
      final destination = targetTab == 1
          ? 'Sản phẩm'
          : targetTab == 0
          ? 'Hóa đơn'
          : 'Đối chiếu';
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: const Text('Chưa thể lưu — cần kiểm tra'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: problems
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('• $p'),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Đến $destination'),
            ),
          ],
        ),
      );
      if (go == true && mounted) setState(() => reviewTab = targetTab);
      return;
    }
    if (selected == null) return;
    final value = ReceiptParser.parseAmount(amount.text)!;
    final name = merchant.text.trim();
    final duplicates = context.read<ExpenseStore>().items.where(
      (e) =>
          e.id != widget.existing?.id &&
          e.amount == value &&
          dayOnly(e.date) == dayOnly(selected) &&
          ReceiptParser.normalize(e.merchant) == ReceiptParser.normalize(name),
    );
    if (duplicates.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Có khoản chi tương tự'),
          content: Text(
            'Đã có khoản "$name", ${money(value)}, ngày ${dayLabel(selected)}. Bạn vẫn muốn lưu khoản này?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Xem lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Vẫn lưu'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    setState(() => saving = true);
    String? stored = photo;
    bool copied = false;
    try {
      if (widget.existing == null && photo != null) {
        stored = await PhotoStorage().keep(photo!);
        copied = true;
      }
      if (!mounted) {
        if (copied) await PhotoStorage().remove(stored);
        return;
      }
      await context.read<ExpenseStore>().save(
        Expense(
          id: widget.existing?.id,
          merchant: name,
          amount: value,
          date: selected,
          category: category,
          note: note.text.trim(),
          imagePath: stored,
          rawText: raw.text,
          details: details,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (copied) {
        try {
          await PhotoStorage().remove(stored);
        } catch (_) {
          /* keep original error */
        }
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được khoản chi. Hãy thử lại.'),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget reconciliation() {
    final total = ReceiptParser.parseAmount(amount.text);
    final d = details;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'Đối chiếu số tiền',
          subtitle: 'Một hóa đơn tính là một khoản chi; không cộng trùng các sản phẩm.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Tổng các dòng đã đọc'),
                  trailing: Text(money(d.itemSum)),
                ),
                ListTile(
                  title: const Text('Giảm giá toàn hóa đơn'),
                  trailing: Text(money(d.discount)),
                ),
                ListTile(
                  title: const Text('Thuế / phụ phí cộng thêm'),
                  trailing: Text(money(d.surcharge)),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Tổng thanh toán'),
                  subtitle: Text(
                    total == null ? 'Chưa rõ' : money(total),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        NoticeBox(
          items.isEmpty
              ? 'Chưa có chi tiết sản phẩm để đối chiếu. Bạn vẫn có thể lưu khoản chi theo tổng đã kiểm tra.'
              : d.incomplete
              ? 'Còn dòng thiếu thông tin, chưa thể kết luận tổng đúng.'
              : total != d.calculatedTotal
              ? 'Chênh ${money((total ?? 0) - d.calculatedTotal)}. Kiểm tra từng dòng, giảm giá và phụ phí; không tự thay tổng hóa đơn.'
              : 'Tổng sản phẩm và điều chỉnh khớp tổng hóa đơn.',
        ),
        if (d.needsReview)
          const NoticeBox(
            'Còn dòng sản phẩm chưa đối chiếu hoặc phép tính chưa khớp.',
          ),
        if (date == null)
          const NoticeBox(
            'Chưa có ngày mua. Chọn ngày thực tế trong mục Hóa đơn.',
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: verified,
          onChanged: busy ? null : (v) => setState(() => verified = v ?? false),
          title: const Text(
            'Tôi đã đối chiếu thông tin và tổng thanh toán với hóa đơn.',
          ),
        ),
      ],
    );
  }

  Future<void> askImageAi() async {
    if (busy || photo == null) return;
    final prefs = await configuration();
    if (prefs == null || !mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: const Text('Gửi ảnh hóa đơn cho Gemini?'),
        content: Column(
          children: [
            Image.file(
              File(photo!),
              height: 180,
              errorBuilder: (_, __, ___) => const Text('Không mở được ảnh.'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ảnh đầy đủ sẽ được gửi qua dịch vụ trên laptop đến Google Gemini. Ảnh có thể chứa tên, số điện thoại và thông tin cá nhân; chức năng này không tự che nội dung ảnh. Chỉ gửi khi bạn đồng ý. Kết quả có thể sai và cần kiểm tra trước khi lưu.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Đồng ý gửi ảnh'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      aiTask = 'image';
      aiError = null;
    });
    try {
      final result = await widget.aiService.analyzeImage(
        baseUrl: prefs.getString('ai_url') ?? 'http://127.0.0.1:8787',
        token: prefs.getString('ai_token')!,
        path: photo!,
      );
      if (!mounted) return;
      final proposed = ReceiptDetails.fromJson(
        Map<String, dynamic>.from(result['details'] as Map),
      );
      bool pickMerchant =
              merchant.text.trim().isEmpty && result['merchant'] != null,
          pickAmount =
              ReceiptParser.parseAmount(amount.text) == null &&
              result['amount'] != null,
          pickDate = date == null && result['date'] != null,
          pickItems = items.isEmpty && proposed.items.isNotEmpty;
      final accept = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, update) => AlertDialog(
            scrollable: true,
            title: const Text('Đề xuất từ ảnh • cần đối chiếu'),
            content: SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chỉ áp dụng các mục bạn chọn. Mặc định giữ nguyên thông tin đã có; chọn sản phẩm sẽ thay danh sách và thông tin mã/giảm giá/phụ phí đề xuất.',
                  ),
                  if (result['merchant'] != null)
                    CheckboxListTile(
                      value: pickMerchant,
                      onChanged: (v) => update(() => pickMerchant = v ?? false),
                      title: Text('Cửa hàng: ${result['merchant']}'),
                    ),
                  if (result['amount'] != null)
                    CheckboxListTile(
                      value: pickAmount,
                      onChanged: (v) => update(() => pickAmount = v ?? false),
                      title: Text('Tổng: ${money(result['amount'] as int)}'),
                    ),
                  if (result['date'] != null)
                    CheckboxListTile(
                      value: pickDate,
                      onChanged: (v) => update(() => pickDate = v ?? false),
                      title: Text('Ngày: ${result['date']}'),
                    ),
                  if (proposed.items.isNotEmpty) ...[
                    CheckboxListTile(
                      value: pickItems,
                      onChanged: (v) => update(() => pickItems = v ?? false),
                      title: Text(
                        'Áp dụng ${proposed.items.length} sản phẩm và điều chỉnh hóa đơn',
                      ),
                    ),
                    Text(
                      'Mã: ${proposed.invoiceNumber.isEmpty ? 'Chưa rõ' : proposed.invoiceNumber} • Giảm: ${money(proposed.discount)} • Phụ phí: ${money(proposed.surcharge)}',
                    ),
                    ...proposed.items.map(
                      (i) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(i.name),
                        subtitle: Text(
                          '${i.quantity ?? '?'} × ${i.unitPrice == null ? '?' : money(i.unitPrice!)} → ${i.lineTotal == null ? 'Chưa rõ' : money(i.lineTotal!)}',
                        ),
                      ),
                    ),
                  ],
                  if (result['warnings'] is List)
                    ...(result['warnings'] as List).whereType<String>().map(
                      (v) => NoticeBox(v),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Giữ nguyên'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Áp dụng mục đã chọn'),
              ),
            ],
          ),
        ),
      );
      if (accept == true && mounted)
        setState(() {
          if (pickMerchant) merchant.text = result['merchant'] as String;
          if (pickAmount) amount.text = result['amount'].toString();
          if (pickDate) date = DateTime.parse(result['date'] as String);
          if (pickItems) {
            items = [...proposed.items];
            invoiceNumber.text = proposed.invoiceNumber;
            discount.text = proposed.discount.toString();
            surcharge.text = proposed.surcharge.toString();
          }
          verified = false;
        });
    } catch (e) {
      if (mounted) setState(() => aiError = e.toString());
    } finally {
      if (mounted) setState(() => aiTask = null);
    }
  }

  Widget fieldProposal(
    String label,
    String value,
    String evidence,
    bool selected,
    ValueChanged<bool> changed,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('$label: $value'),
        value: selected,
        onChanged: busy ? null : (v) => changed(v ?? false),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 8),
        child: Text(
          'Căn cứ: "$evidence"',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
  Widget receiptCard() {
    final r = receiptResult!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đề xuất thông tin từ Gemini',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mặc định chỉ chọn trường còn thiếu. Nếu muốn thay dữ liệu đã có, hãy chủ động tích trường đó và kiểm tra căn cứ.',
            ),
            if (r.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: NoticeBox(
                  'Chưa tìm được thông tin có căn cứ. Hãy nhập thủ công hoặc dùng ảnh rõ hơn.',
                ),
              ),
            if (r.merchant.value != null)
              fieldProposal(
                'Cửa hàng',
                r.merchant.value!,
                r.merchant.evidence,
                useMerchant,
                (v) => setState(() => useMerchant = v),
              ),
            if (r.amount.value != null)
              fieldProposal(
                'Tổng tiền',
                money(r.amount.value!),
                r.amount.evidence,
                useAmount,
                (v) => setState(() => useAmount = v),
              ),
            if (r.date.value != null)
              fieldProposal(
                'Ngày',
                dayLabel(r.date.value!),
                r.date.evidence,
                useDate,
                (v) => setState(() => useDate = v),
              ),
            ...r.warnings.map(
              (s) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: NoticeBox(s),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: busy || !(useMerchant || useAmount || useDate)
                  ? null
                  : applyReceipt,
              child: const Text('Áp dụng mục đã chọn'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountValue = ReceiptParser.parseAmount(amount.text);
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null
                ? 'Kiểm tra khoản chi'
                : 'Chi tiết khoản chi',
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SectionTitle(
                      'Bạn kiểm tra, app ghi nhớ.',
                      subtitle:
                          'Đối chiếu ảnh và thông tin trước khi xác nhận.',
                    ),
                    if (photo != null) ...[
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (context) => Dialog(
                              child: InteractiveViewer(
                                child: Image.file(
                                  File(photo!),
                                  errorBuilder: (_, __, ___) => const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('Không tìm thấy ảnh.'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Image.file(
                                File(photo!),
                                height: 230,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox(
                                  height: 80,
                                  child: Center(
                                    child: Text('Không tìm thấy ảnh hóa đơn.'),
                                  ),
                                ),
                              ),
                              const Positioned(
                                bottom: 8,
                                right: 10,
                                child: Chip(
                                  avatar: Icon(Icons.zoom_in, size: 16),
                                  label: Text('Chạm để phóng to'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.ocrFailed)
                      const NoticeBox(
                        'OCR chưa đọc rõ ảnh. Bạn có thể chọn ảnh khác hoặc nhập tay; AI phân tích văn bản không thể khôi phục chữ không đọc được.',
                        icon: Icons.document_scanner_outlined,
                      ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Hóa đơn')),
                        ButtonSegment(value: 1, label: Text('Sản phẩm')),
                        ButtonSegment(value: 2, label: Text('Đối chiếu')),
                      ],
                      selected: {reviewTab},
                      onSelectionChanged: busy
                          ? null
                          : (v) => setState(() => reviewTab = v.first),
                    ),
                    const SizedBox(height: 16),
                    if (reviewTab == 0) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            avatar: Icon(
                              merchant.text.trim().isEmpty
                                  ? Icons.info_outline
                                  : Icons.check_circle_outline,
                              size: 16,
                            ),
                            label: Text(
                              merchant.text.trim().isEmpty
                                  ? 'Thiếu tên'
                                  : 'Có tên',
                            ),
                          ),
                          Chip(
                            avatar: Icon(
                              date == null
                                  ? Icons.info_outline
                                  : Icons.check_circle_outline,
                              size: 16,
                            ),
                            label: Text(
                              date == null ? 'Thiếu ngày' : 'Có ngày',
                            ),
                          ),
                          Chip(
                            avatar: Icon(
                              amountValue == null || amountValue <= 0
                                  ? Icons.info_outline
                                  : photo != null && !verified
                                  ? Icons.info_outline
                                  : Icons.check_circle_outline,
                              size: 16,
                            ),
                            label: Text(
                              amountValue == null || amountValue <= 0
                                  ? 'Thiếu tổng'
                                  : photo != null && !verified
                                  ? 'Tổng cần kiểm tra'
                                  : 'Có tổng',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const SectionTitle('Thông tin khoản chi'),
                      TextFormField(
                        controller: merchant,
                        enabled: !busy,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {
                          verified = false;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Cửa hàng / tên khoản chi',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Vui lòng nhập tên.'
                            : v.trim().length > 200
                            ? 'Tên tối đa 200 ký tự.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amount,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9., \-]'),
                          ),
                        ],
                        onChanged: (_) => setState(() {
                          verified = false;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Số tiền (VND)',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (v) {
                          final n = ReceiptParser.parseAmount(v ?? '');
                          return n == null || n <= 0 || n > 999999999999
                              ? 'Nhập VND nguyên dương, ví dụ 65000 hoặc 65.000.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: date ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100, 12, 31),
                                );
                                if (picked != null && mounted)
                                  setState(() {
                                    date = picked;
                                    verified = false;
                                  });
                              },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          date == null
                              ? 'Chọn ngày chi tiêu (bắt buộc)'
                              : dayLabel(date!),
                        ),
                      ),
                      if (date != null &&
                          dayOnly(date!).isAfter(dayOnly(DateTime.now())))
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: NoticeBox(
                            'Ngày này ở tương lai. Khoản chi chỉ được tính vào thống kê thực tế khi đến ngày đó.',
                          ),
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey(category),
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Danh mục',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (v) => setState(() => category = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: note,
                        enabled: !busy,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú (không bắt buộc)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: invoiceNumber,
                        enabled: !busy,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Mã hóa đơn (nếu có)',
                        ),
                        onChanged: (_) => setState(() => verified = false),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: discount,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Giảm giá toàn hóa đơn (VND)',
                        ),
                        onChanged: (_) => setState(() => verified = false),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: surcharge,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Thuế / phụ phí cộng thêm (VND)',
                        ),
                        onChanged: (_) => setState(() => verified = false),
                      ),
                      const NoticeBox(
                        'Chỉ nhập điều chỉnh chưa nằm trong thành tiền sản phẩm. Không cộng thuế đã bao gồm trong giá lần nữa.',
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle(
                        'Trợ lý hóa đơn',
                        subtitle: 'Các gợi ý đều cần bạn kiểm tra và áp dụng.',
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Thiếu tên, ngày hoặc tổng tiền?',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Gemini hỗ trợ tìm thông tin trong văn bản OCR, kèm đoạn trích làm căn cứ.',
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => askAi(receipt: true),
                                icon: const Icon(Icons.find_in_page_outlined),
                                label: Text(
                                  aiTask == 'receipt'
                                      ? 'Đang phân tích…'
                                      : 'AI hỗ trợ hóa đơn khó',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => askAi(receipt: false),
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: Text(
                                  aiTask == 'category'
                                      ? 'Đang gợi ý…'
                                      : 'AI gợi ý danh mục',
                                ),
                              ),
                              if (aiTask != null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: LinearProgressIndicator(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (aiError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: NoticeBox(
                            aiError!,
                            icon: Icons.cloud_off_outlined,
                          ),
                        ),
                      if (receiptResult != null) receiptCard(),
                      if (categoryResult != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gemini gợi ý: ${categoryResult!.category}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(categoryResult!.reason),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(
                                          () => category =
                                              categoryResult!.category,
                                        ),
                                  child: const Text('Áp dụng danh mục này'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Văn bản OCR để đối chiếu'),
                        subtitle: const Text(
                          'Có thể sửa lỗi chữ rồi phân tích lại.',
                        ),
                        children: [
                          TextField(
                            controller: raw,
                            enabled: !busy,
                            minLines: 4,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              hintText: 'Văn bản nhận diện từ hóa đơn',
                            ),
                            onChanged: (_) => setState(() {
                              verified = false;
                              receiptResult = null;
                              categoryResult = null;
                            }),
                          ),
                          TextButton(
                            onPressed: busy ? null : parseMissing,
                            child: const Text('Điền trường thiếu bằng Regex'),
                          ),
                        ],
                      ),
                    ],
                    if (reviewTab == 1) ...[
                      ReceiptItemsEditor(
                        value: details,
                        enabled: !busy,
                        onChanged: (v) => setState(() {
                          items = [...v.items];
                          verified = false;
                        }),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SectionTitle(
                                'Đọc phần chưa rõ cùng AI',
                                subtitle: 'Ảnh chỉ được gửi đến Gemini khi bạn đồng ý.',
                              ),
                              OutlinedButton.icon(
                                onPressed: busy || photo == null
                                    ? null
                                    : askImageAi,
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: Text(
                                  aiTask == 'image'
                                      ? 'Đang phân tích ảnh…'
                                      : 'AI phân tích ảnh hóa đơn',
                                ),
                              ),
                              if (photo == null)
                                const Text(
                                  'Chụp hoặc chọn ảnh để dùng AI đọc ảnh.',
                                ),
                              if (aiTask == 'image')
                                const LinearProgressIndicator(),
                              if (aiError != null)
                                NoticeBox(
                                  aiError!,
                                  icon: Icons.cloud_off_outlined,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (reviewTab == 2) reconciliation(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Tổng thanh toán')),
                    Flexible(
                      child: Text(
                        amountValue == null ? 'Chưa rõ' : money(amountValue),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: busy ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    saving
                        ? 'Đang lưu…'
                        : widget.existing == null
                        ? 'Xác nhận & lưu khoản chi'
                        : 'Lưu thay đổi',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
