import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../state/expense_store.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool busy = false;
  String? status;
  late final backup = BackupService(DatabaseService());
  Future<void> export() async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final file = await backup.export();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Bản sao lưu ExpenseMate chứa dữ liệu và ảnh hóa đơn. Hãy lưu ở nơi riêng tư.',
        ),
      );
      if (mounted)
        setState(
          () => status = 'Đã mở bảng chia sẻ. Hãy lưu file vào thư mục hoặc tài khoản của bạn; đóng bảng chia sẻ không có nghĩa là đã lưu.',
        );
    } catch (e) {
      if (mounted) setState(() => status = 'Chưa xuất được: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập bản sao lưu?'),
        content: const Text(
          'Khoản chi được thêm vào dữ liệu hiện tại. Nhập lại cùng file không thêm trùng. '
          'Không ghi đè các khoản chi đã có. Chỉ chọn file do ExpenseMate xuất.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Chọn file'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null) return;
      final path = picked.files.single.path;
      if (path == null)
        throw const FormatException('Không mở được file đã chọn.');
      final added = await backup.restore(File(path));
      if (!mounted) return;
      await context.read<ExpenseStore>().load();
      if (mounted)
        setState(
          () => status =
              'Đã thêm $added khoản chi. Các mục đã nhập trước đó được bỏ qua.',
        );
    } catch (e) {
      if (mounted) setState(() => status = 'Chưa nhập được: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Sao lưu & chuyển dữ liệu')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Giữ lại những khoản chi của bạn.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'File JSON bao gồm khoản chi và ảnh hóa đơn. Không chứa khóa Gemini hay mã ghép nối AI. '
            'Giới hạn bản sao lưu 64 MB, tổng ảnh khi xuất tối đa 40 MB; JPEG/PNG khi nhập. '
            'File không được mã hóa: hãy giữ riêng tư.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : export,
            icon: const Icon(Icons.upload_file),
            label: const Text('Xuất bản sao lưu'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : restore,
            icon: const Icon(Icons.download),
            label: const Text('Nhập bản sao lưu'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(status!),
            ),
          const Divider(height: 32),
          const Text(
            'Chuyển sang APK release',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Xuất và lưu file từ bản debug đang có dữ liệu.\n'
            '2. Cài bản ExpenseMate Release (biểu tượng và tên riêng).\n'
            '3. Mở bản release, nhập file và đối chiếu khoản chi cùng ảnh.\n'
            '4. Giữ bản debug cho đến khi bạn đã kiểm tra dữ liệu đầy đủ.\n\n'
            'Sao lưu là thao tác chủ động; chỉ mở bảng chia sẻ chưa tạo ra bản lưu bên ngoài ứng dụng.',
          ),
        ],
      ),
    ),
  );
}
