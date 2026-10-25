import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/expense.dart';
import '../services/ocr_service.dart';
import '../models/receipt_details.dart';
import '../state/expense_store.dart';
import '../widgets/expense_charts.dart';
import '../widgets/design.dart';
import '../widgets/budget_dialog.dart';
import '../widgets/insights_card.dart';
import '../services/spending_summary.dart';
import '../services/spending_summary_format.dart';
import '../services/receipt_parser.dart';
import '../services/csv_export_service.dart';

import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'review_screen.dart';
import 'ai_settings_screen.dart';
import 'backup_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool dark;
  final ValueChanged<bool> onThemeChanged;
  const HomeScreen({
    super.key,
    required this.dark,
    required this.onThemeChanged,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  bool scanning = false;
  String query = '';
  String? filter;
  DateTime anchor = DateTime.now();
  SummaryPeriod period = SummaryPeriod.week;
  DateTimeRange? historyRange;
  String historyPreset = 'all';
  bool largestFirst = false;
  bool exporting = false;
  int monthlyBudget = 0;

  @override
  void initState() {
    super.initState();
    loadBudget();
    WidgetsBinding.instance.addPostFrameCallback((_) => recoverPhoto());
  }

  Future<void> recoverPhoto() async {
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (!mounted || lost.isEmpty) return;
      final files = lost.files;
      if (files != null && files.isNotEmpty) {
        await processPhoto(files.first);
      } else if (lost.exception != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không khôi phục được ảnh trước đó. Hãy chọn lại ảnh.',
            ),
          ),
        );
      }
    } catch (_) {
      /* No lost image to recover, normal app launch remains usable. */
    }
  }

  Future<void> processPhoto(XFile image) async {
    if (!mounted) return;
    setState(() => scanning = true);
    String raw = '';
    ReceiptDetails details = const ReceiptDetails();
    bool failed = false;
    try {
      final document = await OcrService().recognizeDocument(image.path);
      raw = document.text;
      details = document.details;
      failed = raw.trim().isEmpty;
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => scanning = false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          imagePath: image.path,
          initialDetails: details,
          rawText: raw,
          ocrFailed: failed,
        ),
      ),
    );
  }

  Future<void> add() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Thêm khoản chi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp hóa đơn'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh hóa đơn'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Nhập thủ công'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'manual') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReviewScreen()),
      );
      return;
    }
    setState(() => scanning = true);
    try {
      final image = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      await processPhoto(image);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không mở được ảnh/camera. Kiểm tra quyền hoặc thử chọn ảnh khác.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> remove(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa khoản chi?'),
        content: Text('${expense.merchant}\n${money(expense.amount)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ExpenseStore>().delete(expense);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa xóa được. Vui lòng thử lại.')),
        );
    }
  }

  Widget expenseTile(Expense expense) {
    final i = categoryIndex(expense.category);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: categoryColors[i].withAlpha(35),
          child: Icon(categoryIcons[i], color: categoryColors[i]),
        ),
        title: Text(
          expense.merchant,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${expense.category} · ${dayLabel(expense.date)}'),
            Text(
              money(expense.amount),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (_) => remove(expense),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'delete', child: Text('Xóa khoản chi')),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReviewScreen(existing: expense)),
        ),
      ),
    );
  }

  Future<void> loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(() => monthlyBudget = prefs.getInt('monthly_budget') ?? 0);
  }

  Future<void> editBudget() async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => BudgetDialog(current: monthlyBudget),
    );
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('monthly_budget', value);
    if (mounted) setState(() => monthlyBudget = value);
  }

  Future<void> selectRange() async {
    final value = await showDateRangePicker(
      context: context,
      initialDateRange: historyRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Chọn khoảng ngày chi tiêu',
    );
    if (value != null && mounted)
      setState(() {
        historyRange = value;
        historyPreset = 'custom';
      });
  }

  void preset(String value) {
    final now = dayOnly(DateTime.now());
    setState(() {
      historyPreset = value;
      historyRange = value == 'all'
          ? null
          : DateTimeRange(
              start: value == 'month'
                  ? DateTime(now.year, now.month)
                  : now.subtract(const Duration(days: 6)),
              end: now,
            );
    });
  }

  List<Expense> filtered(List<Expense> rows) {
    final term = ReceiptParser.normalize(query.trim());
    final visible = rows.where((e) {
      final d = dayOnly(e.date);
      return (filter == null || e.category == filter) &&
          ReceiptParser.normalize(
            '${e.merchant} ${e.note} ${e.category} ${e.amount}',
          ).contains(term) &&
          (historyRange == null ||
              (!d.isBefore(dayOnly(historyRange!.start)) &&
                  !d.isAfter(dayOnly(historyRange!.end))));
    }).toList();
    visible.sort(
      (a, b) => largestFirst
          ? b.amount.compareTo(a.amount)
          : b.date.compareTo(a.date),
    );
    return visible;
  }

  Future<void> exportRows(List<Expense> rows) async {
    if (rows.isEmpty || exporting) return;
    setState(() => exporting = true);
    try {
      final file = await CsvExportService.export(rows);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Danh sách chi tiêu ExpenseMate đã lọc. File có thông tin cá nhân, hãy lưu/chia sẻ ở nơi phù hợp.',
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa xuất được CSV. Hãy thử lại.')),
        );
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget hero(SpendingSummary month) {
    final progress = monthlyBudget > 0
        ? (month.total / monthlyBudget).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF234E70), Color(0xFF167D8D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF234E70).withAlpha(35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CHI TIÊU THÁNG ${month.start.month}/${month.start.year}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(Icons.auto_graph, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              money(month.total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${month.entries.length} khoản chi • ${month.observedDays} ngày đã tính',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          if (monthlyBudget > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                color: const Color(0xFFFBBF24),
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              month.fact('budget'),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ] else
            const Text(
              'Đặt mục tiêu tháng để chủ động hơn với chi tiêu.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: editBudget,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(
                monthlyBudget > 0 ? 'Chỉnh mục tiêu' : 'Đặt mục tiêu tháng',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget dashboard(ExpenseStore store) {
    final now = DateTime.now();
    final month = SpendingSummary.build(
      store.items,
      period: SummaryPeriod.month,
      anchor: now,
      now: now,
      budget: monthlyBudget,
    );
    final week = SpendingSummary.build(
      store.items,
      period: SummaryPeriod.week,
      anchor: now,
      now: now,
    );
    final today = store.items
        .where((e) => dayOnly(e.date) == dayOnly(now))
        .fold<int>(0, (s, e) => s + e.amount);
    return RefreshIndicator(
      onRefresh: store.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
        children: [
          const SectionTitle(
            'Ghi lại hôm nay,',
            subtitle: 'để hiểu rõ chi tiêu của mình.',
          ),
          hero(month),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Hôm nay',
                  value: money(today),
                  icon: Icons.today_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'Tuần này',
                  value: money(week.total),
                  icon: Icons.date_range_outlined,
                  color: const Color(0xFF0D9488),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: scanning ? null : add,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Quét hóa đơn / thêm khoản chi'),
          ),
          const SizedBox(height: 22),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Nhìn lại chi tiêu cùng AI'),
              subtitle: const Text('Số liệu chính xác, gợi ý để bạn cân nhắc.'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => setState(() => tab = 2),
            ),
          ),
          const SizedBox(height: 20),
          SectionTitle(
            'Gần đây',
            action: TextButton(
              onPressed: () => setState(() => tab = 1),
              child: const Text('Xem tất cả'),
            ),
          ),
          if (store.items.isEmpty)
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Bắt đầu từ hóa đơn đầu tiên',
              message: 'Chụp hóa đơn hoặc nhập tay. Bạn luôn được kiểm tra trước khi lưu.',
              action: OutlinedButton(
                onPressed: add,
                child: const Text('Thêm khoản chi'),
              ),
            )
          else
            ...store.items.take(5).map(expenseTile),
        ],
      ),
    );
  }

  Widget history(ExpenseStore store) {
    final rows = filtered(store.items);
    final grouped = <Object>[];
    DateTime? lastDay;
    for (final e in rows) {
      final day = dayOnly(e.date);
      if (!largestFirst && day != lastDay) {
        grouped.add(day);
        lastDay = day;
      }
      grouped.add(e);
    }
    final total = rows.fold<int>(0, (s, e) => s + e.amount);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Tìm cửa hàng, ghi chú hoặc số tiền',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final choice in const [
                ('all', 'Tất cả ngày'),
                ('month', 'Tháng này'),
                ('week', '7 ngày qua'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(choice.$2),
                    selected: historyPreset == choice.$1,
                    onSelected: (_) => preset(choice.$1),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(
                  historyPreset == 'custom'
                      ? '${dayLabel(historyRange!.start)} – ${dayLabel(historyRange!.end)}'
                      : 'Chọn khoảng',
                ),
                onPressed: selectRange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Mọi danh mục'),
                  selected: filter == null,
                  onSelected: (_) => setState(() => filter = null),
                ),
              ),
              ...categories.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: filter == c,
                    onSelected: (_) => setState(() => filter = c),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${rows.length} khoản • ${money(total)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                tooltip: largestFirst
                    ? 'Đang xếp số tiền cao nhất'
                    : 'Đang xếp ngày mới nhất',
                onPressed: () => setState(() => largestFirst = !largestFirst),
                icon: Icon(largestFirst ? Icons.sort : Icons.schedule),
              ),
              IconButton(
                tooltip: 'Xuất CSV danh sách đã lọc',
                onPressed: rows.isEmpty || exporting
                    ? null
                    : () => exportRows(rows),
                icon: exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'Chưa có khoản chi phù hợp',
                      message: 'Thử đổi từ khóa, khoảng ngày hoặc danh mục.',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: grouped.length,
                  itemBuilder: (_, i) {
                    final row = grouped[i];
                    if (row is DateTime)
                      return Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 6),
                        child: Text(
                          dayLabel(row),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    final e = row as Expense;
                    return KeyedSubtree(
                      key: ValueKey(e.id),
                      child: expenseTile(e),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void shiftPeriod(int direction) {
    setState(
      () => anchor = period == SummaryPeriod.week
          ? anchor.add(Duration(days: 7 * direction))
          : DateTime(anchor.year, anchor.month + direction, 1),
    );
  }

  Widget statistics(ExpenseStore store) {
    final summary = SpendingSummary.build(
      store.items,
      period: period,
      anchor: anchor,
      now: DateTime.now(),
      budget: monthlyBudget,
    );
    final labels = period == SummaryPeriod.week
        ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
        : List.generate(
            summary.daily.length,
            (i) => i == 0 || (i + 1) % 5 == 0 || i == summary.daily.length - 1
                ? '${i + 1}'
                : '',
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<SummaryPeriod>(
                segments: const [
                  ButtonSegment(
                    value: SummaryPeriod.week,
                    label: Text('Tuần'),
                    icon: Icon(Icons.view_week_outlined),
                  ),
                  ButtonSegment(
                    value: SummaryPeriod.month,
                    label: Text('Tháng'),
                    icon: Icon(Icons.calendar_month_outlined),
                  ),
                ],
                selected: {period},
                onSelectionChanged: (s) => setState(() => period = s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Row(
            children: [
              IconButton(
                tooltip: 'Kỳ trước',
                onPressed: () => shiftPeriod(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  summary.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Kỳ sau',
                onPressed: () => shiftPeriod(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() => anchor = DateTime.now()),
            child: const Text('Về kỳ hiện tại'),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Tổng chi trong kỳ',
                value: money(summary.total),
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Trung bình / ngày',
                value: money(summary.average),
                icon: Icons.auto_graph,
                color: const Color(0xFF0D9488),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        NoticeBox('${summary.coverage}\n${summary.fact('comparison')}'),
        const SizedBox(height: 14),
        InsightsCard(summary: summary),
        const SizedBox(height: 18),
        const SectionTitle(
          'Chi tiêu theo danh mục',
          subtitle: 'Biểu đồ tự vẽ từ dữ liệu đã lưu trên thiết bị.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ExpenseCharts(
              totals: summary.totals,
              daily: summary.daily,
              labels: labels,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(
          'Các khoản trong kỳ',
          subtitle: '${summary.entries.length} khoản đã tính vào thống kê',
        ),
        ...summary.entries.map(expenseTile),
      ],
    );
  }

  Widget settings() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 70),
    children: [
      const SectionTitle(
        'Không gian của bạn',
        subtitle: 'Giao diện, mục tiêu và dữ liệu trên thiết bị.',
      ),
      Card(
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Giao diện tối'),
              subtitle: const Text('Giữ lựa chọn khi mở lại ứng dụng'),
              value: widget.dark,
              onChanged: widget.onThemeChanged,
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Mục tiêu chi mỗi tháng'),
              subtitle: Text(
                monthlyBudget > 0 ? money(monthlyBudget) : 'Chưa đặt mục tiêu',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: editBudget,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Kết nối Gemini'),
              subtitle: const Text(
                'Danh mục, hóa đơn khó và nhận xét chi tiêu',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Sao lưu & chuyển dữ liệu'),
              subtitle: const Text('Khoản chi cùng ảnh hóa đơn'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const NoticeBox(
        'OCR và lưu dữ liệu chạy trên thiết bị. Gemini chỉ được gọi khi bạn đồng ý gửi nội dung. Gỡ ứng dụng có thể làm mất dữ liệu chưa sao lưu.',
      ),
      const SizedBox(height: 24),
      const Center(
        child: Text(
          'ExpenseMate 1.2.1',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 5),
      const Center(
        child: Text(
          'Ghi chép rõ ràng • Chủ động mỗi ngày',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    Widget content;
    if (store.loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (store.error != null) {
      content = Center(
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Chưa đọc được dữ liệu',
          message: store.error!,
          action: FilledButton(
            onPressed: store.load,
            child: const Text('Thử lại'),
          ),
        ),
      );
    } else {
      content = switch (tab) {
        0 => dashboard(store),
        1 => history(store),
        2 => statistics(store),
        _ => settings(),
      };
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.receipt_long,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(['ExpenseMate', 'Lịch sử', 'Thống kê', 'Cài đặt'][tab]),
          ],
        ),
        actions: [
          IconButton(
            tooltip: widget.dark ? 'Giao diện sáng' : 'Giao diện tối',
            onPressed: () => widget.onThemeChanged(!widget.dark),
            icon: Icon(
              widget.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: content,
              ),
            ),
            if (scanning)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            CircularProgressIndicator(),
                            SizedBox(height: 20),
                            Text('Đang đọc hóa đơn trên thiết bị…'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: tab == 1
          ? FloatingActionButton.extended(
              onPressed: scanning ? null : add,
              icon: const Icon(Icons.add),
              label: const Text('Thêm khoản chi'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: scanning ? null : (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Lịch sử',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_large),
            label: 'Thống kê',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Cài đặt'),
        ],
      ),
    );
  }
}
