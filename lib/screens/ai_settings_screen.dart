import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_service.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});
  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final url = TextEditingController(text: 'http://127.0.0.1:8787');
  final token = TextEditingController();
  bool busy = false;
  bool ready = false;
  String? status;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    url.text = prefs.getString('ai_url') ?? 'http://127.0.0.1:8787';
    token.text = prefs.getString('ai_token') ?? '';
    setState(() => ready = true);
  }

  @override
  void dispose() {
    url.dispose();
    token.dispose();
    super.dispose();
  }

  Future<void> save() async {
    try {
      AiService.endpoint(url.text, '/health');
      if (token.text.trim().length < 24)
        throw const AiFailure('Mã ghép nối cần ít nhất 24 ký tự.');
      setState(() {
        busy = true;
        status = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_url', url.text.trim());
      await prefs.setString('ai_token', token.text.trim());
      if (mounted)
        setState(
          () => status =
              'Đã lưu. Mã này là mã ghép nối, không phải Gemini API key.',
        );
    } catch (e) {
      if (mounted) setState(() => status = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> check() async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await const AiService().health(url.text);
      if (mounted)
        setState(
          () => status = 'Đã kết nối dịch vụ. Khóa Gemini được kiểm tra khi bạn yêu cầu gợi ý.',
        );
    } catch (e) {
      if (mounted) setState(() => status = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> checkUpstream() async {
    setState(() {
      busy = true;
      status = 'Đang gửi yêu cầu kiểm tra nhỏ, không gửi hóa đơn…';
    });
    try {
      final model = await const AiService().checkGemini(
        baseUrl: url.text,
        token: token.text,
      );
      if (mounted)
        setState(
          () => status =
              'Gemini đã trả lời thành công ($model). Kết nối, mã ghép nối và key hoạt động ở lần kiểm tra này. Chức năng đọc ảnh cần thử riêng.',
        );
    } catch (e) {
      if (mounted) setState(() => status = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kết nối AI')),
    body: !ready
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Gợi ý đúng lúc, bạn quyết định.',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'ML Kit đọc chữ ngay trên điện thoại. Gemini là tùy chọn giúp gợi ý danh mục, tìm thông tin hóa đơn còn thiếu và nhận xét chi tiêu. '
                'Chỉ gửi nội dung sau khi bạn đồng ý tại màn hình kiểm tra hóa đơn.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: url,
                enabled: !busy,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ dịch vụ AI',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: token,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Mã ghép nối từ Start-AI.cmd',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: const Text('Lưu cấu hình'),
              ),
              OutlinedButton(
                onPressed: busy ? null : check,
                child: const Text('Kiểm tra kết nối'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : checkUpstream,
                icon: const Icon(Icons.cloud_done_outlined),
                label: const Text('Kiểm tra Gemini thật'),
              ),
              const Text(
                'Kiểm tra Gemini thật gửi một yêu cầu văn bản nhỏ và dùng hạn mức API. Không gửi ảnh, ghi chú hoặc giao dịch của bạn.',
                style: TextStyle(fontSize: 12),
              ),
              if (busy) const LinearProgressIndicator(),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(status!),
                ),
              const Divider(height: 32),
              const Text(
                'Cách dùng qua cáp USB',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Trên laptop, chạy Start-AI.cmd và nhập khóa Gemini.\n'
                '2. Script kết nối dịch vụ với điện thoại qua USB.\n'
                '3. Nhập mã ghép nối hiển thị trên laptop rồi lưu.\n'
                '4. Bấm Kiểm tra Gemini thật, sau đó thử gợi ý danh mục hoặc đọc ảnh.\n\n'
                'Khi rút USB hoặc tắt laptop, AI cục bộ dừng; OCR, lưu chi tiêu và biểu đồ vẫn hoạt động. '
                'Muốn AI dùng độc lập cần triển khai dịch vụ HTTPS và đổi địa chỉ ở trên.',
              ),
            ],
          ),
  );
}
