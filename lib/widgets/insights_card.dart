import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_service.dart';
import '../services/spending_summary.dart';
import '../services/spending_summary_format.dart';
import '../screens/ai_settings_screen.dart';
import 'design.dart';

class InsightsCard extends StatefulWidget {
  final SpendingSummary summary;
  const InsightsCard({super.key, required this.summary});
  @override
  State<InsightsCard> createState() => _InsightsCardState();
}

class _InsightsCardState extends State<InsightsCard> {
  SpendingInsights? result;
  String? error;
  bool busy = false;
  int generation = 0;
  @override
  void didUpdateWidget(covariant InsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.signature != widget.summary.signature) {
      generation++;
      result = null;
      error = null;
      busy = false;
    }
  }

  Future<void> ask() async {
    final summary = widget.summary;
    if (summary.entries.isEmpty || busy) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final token = prefs.getString('ai_token') ?? '';
    if (token.isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
      );
      return;
    }
    final signature = summary.signature;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhờ Gemini xem số liệu?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary.label),
              const SizedBox(height: 12),
              const Text(
                'Chỉ gửi số liệu tổng hợp theo danh mục, số khoản chi, số ngày và mục tiêu tháng nếu có. Không gửi tên cửa hàng, ghi chú, ảnh hoặc từng giao dịch.',
              ),
              const SizedBox(height: 12),
              Text(summary.fact('total')),
              Text(summary.fact('count')),
              Text(summary.comparisonLabel),
              const SizedBox(height: 8),
              const Text(
                'Số liệu do ứng dụng tính; lời gợi ý của AI cần được bạn cân nhắc.',
              ),
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
    );
    if (approved != true || !mounted || signature != widget.summary.signature)
      return;
    final request = ++generation;
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final value = await const AiService().insights(
        baseUrl: prefs.getString('ai_url') ?? 'http://127.0.0.1:8787',
        token: token,
        summary: summary.toAiPayload(),
      );
      if (mounted && request == generation) setState(() => result = value);
    } catch (e) {
      if (mounted && request == generation)
        setState(() => error = e.toString());
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Góc nhìn từ AI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Gemini chọn điểm cần chú ý và gợi ý cách theo dõi. Các con số bên dưới luôn lấy từ ứng dụng.',
          ),
          const SizedBox(height: 14),
          if (widget.summary.entries.isEmpty)
            const NoticeBox(
              'Chưa có chi tiêu trong kỳ này. Thêm khoản chi để có dữ liệu nhận xét.',
            )
          else
            OutlinedButton.icon(
              onPressed: busy ? null : ask,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                busy
                    ? 'Đang xem số liệu…'
                    : result == null
                    ? 'Nhận xét kỳ này'
                    : 'Nhận xét lại',
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: NoticeBox(error!, icon: Icons.cloud_off_outlined),
            ),
          if (result != null) ...[
            const Divider(height: 28),
            Text(
              result!.headline,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            ...result!.focus.map(
              (id) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.summary.fact(id))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gợi ý từ Gemini',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...result!.tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('• $tip'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nhận xét cho ${widget.summary.label}; sẽ xóa khi số liệu hoặc kỳ thay đổi.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );
}
