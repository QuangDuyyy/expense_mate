import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../models/receipt_details.dart';
import 'database_service.dart';

class BackupService {
  static const maxBytes = 64 * 1024 * 1024;
  final DatabaseService database;
  const BackupService(this.database);
  Future<String> _origin() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('backup_origin');
    if (existing != null) return existing;
    final random = Random.secure();
    final id = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await prefs.setString('backup_origin', id);
    return id;
  }

  Future<File> export() async {
    final records = <Map<String, Object?>>[];
    var photoBytes = 0;
    for (final item in await database.all()) {
      String? encoded;
      if (item.imagePath != null) {
        final file = File(item.imagePath!);
        if (!await file.exists())
          throw const FormatException(
            'Có ảnh hóa đơn bị thiếu. Kiểm tra trước khi sao lưu.',
          );
        photoBytes += await file.length();
        if (photoBytes > 40 * 1024 * 1024)
          throw const FormatException(
            'Ảnh vượt 40 MB. Bộ sao lưu hiện dành cho dữ liệu đồ án nhỏ.',
          );
        encoded = base64Encode(await file.readAsBytes());
      }
      records.add({
        ...item.toMap(),
        'image_path': null,
        'image_base64': encoded,
      });
    }
    final payload = jsonEncode({
      'format': 'expense_mate_backup',
      'version': 1,
      'origin': await _origin(),
      'created_at': DateTime.now().toIso8601String(),
      'expenses': records,
    });
    if (utf8.encode(payload).length > maxBytes)
      throw const FormatException('Bản sao lưu vượt giới hạn 64 MB.');
    final folder = await getTemporaryDirectory();
    return File(
      p.join(
        folder.path,
        'ExpenseMate_Backup_${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    ).writeAsString(payload);
  }

  Future<int> restore(File file) async {
    if (await file.length() > maxBytes)
      throw const FormatException('File vượt 64 MB.');
    final payload = jsonDecode(await file.readAsString());
    if (payload is! Map ||
        payload['format'] != 'expense_mate_backup' ||
        payload['version'] != 1 ||
        payload['origin'] is! String ||
        !RegExp(r'^[a-f0-9]{48}$').hasMatch(payload['origin'] as String) ||
        payload['expenses'] is! List ||
        (payload['expenses'] as List).length > 5000) {
      throw const FormatException(
        'Không phải bản sao lưu ExpenseMate được hỗ trợ.',
      );
    }
    final origin = payload['origin'] as String;
    final current = await _origin();
    final root = await getApplicationDocumentsDirectory();
    final photos = await Directory(p.join(root.path, 'receipts'))
        .create(recursive: true);
    final written = <String>[];
    final records = <Map<String, Object?>>[];
    final ids = <int>{};
    try {
      for (final value in payload['expenses'] as List) {
        if (value is! Map)
          throw const FormatException('Bản ghi sai định dạng.');
        final r = Map<String, Object?>.from(value);
        final date = r['date'] is String
            ? DateTime.tryParse(r['date'] as String)
            : null;
        if (r['id'] is! int ||
            (r['id'] as int) <= 0 ||
            !ids.add(r['id'] as int) ||
            r['merchant'] is! String ||
            (r['merchant'] as String).trim().isEmpty ||
            (r['merchant'] as String).length > 500 ||
            r['amount'] is! int ||
            (r['amount'] as int) <= 0 ||
            (r['amount'] as int) > 999999999999 ||
            date == null ||
            date.year < 2000 ||
            date.year > 2100 ||
            date.isUtc ||
            !categories.contains(r['category']) ||
            r['note'] is! String ||
            r['raw_text'] is! String ||
            (r['image_base64'] != null && r['image_base64'] is! String)) {
          throw const FormatException(
            'Thông tin khoản chi trong file không hợp lệ.',
          );
        }
        final details = ReceiptDetails.decode(r['receipt_details'] as String?);
        final encoded = r['image_base64'] as String?;
        if (await database.wasRestored(origin, current, r['id'] as int))
          continue;
        String? photo;
        if (encoded != null) {
          final bytes = base64Decode(encoded);
          if (bytes.length > 12 * 1024 * 1024 || bytes.length < 4)
            throw const FormatException('Ảnh không hợp lệ hoặc vượt 12 MB.');
          final jpeg = bytes[0] == 0xff && bytes[1] == 0xd8;
          final png =
              bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4e &&
              bytes[3] == 0x47;
          if (!jpeg && !png)
            throw const FormatException('Ảnh sao lưu phải là JPEG hoặc PNG.');
          photo = p.join(
            photos.path,
            'restore_${DateTime.now().microsecondsSinceEpoch}_${r['id']}.${png ? 'png' : 'jpg'}',
          );
          await File(photo).writeAsBytes(bytes, flush: true);
          written.add(photo);
        }
        records.add({
          'id': r['id'],
          'merchant': r['merchant'],
          'amount': r['amount'],
          'date': date.toIso8601String(),
          'category': r['category'],
          'note': r['note'],
          'raw_text': r['raw_text'],
          'image_path': photo,
          'receipt_details': details.encode(),
        });
      }
      return await database.restore(origin, current, records);
    } catch (_) {
      for (final path in written) {
        try {
          await File(path).delete();
        } catch (_) {
          /* best effort cleanup */
        }
      }
      rethrow;
    }
  }
}
