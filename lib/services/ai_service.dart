import 'dart:io';

import '../models/receipt_details.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/format.dart';

class AiFailure implements Exception {
  final String message;
  const AiFailure(this.message);
  @override
  String toString() => message;
}

class CategorySuggestion {
  final String category;
  final String reason;
  const CategorySuggestion(this.category, this.reason);
}

class ReceiptField<T> {
  final T? value;
  final String evidence;
  const ReceiptField(this.value, this.evidence);
}

class ReceiptSuggestion {
  final ReceiptField<String> merchant;
  final ReceiptField<DateTime> date;
  final ReceiptField<int> amount;
  final List<String> warnings;
  const ReceiptSuggestion(this.merchant, this.date, this.amount, this.warnings);
  bool get isEmpty =>
      merchant.value == null && date.value == null && amount.value == null;
}

class SpendingInsights {
  final String headline;
  final List<String> focus;
  final List<String> tips;
  const SpendingInsights(this.headline, this.focus, this.tips);
}

class AiService {
  final http.Client? client;
  const AiService({this.client});
  static const factIds = [
    'total',
    'comparison',
    'top_category',
    'daily_average',
    'count',
    'budget',
  ];
  static Uri endpoint(String base, String path) {
    final uri = Uri.tryParse(base.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                ['localhost', '127.0.0.1'].contains(uri.host)))) {
      throw const AiFailure(
        'Dùng địa chỉ HTTPS hoặc http://127.0.0.1:8787 qua USB.',
      );
    }
    return uri.replace(path: path);
  }

  static String redact(String value) => value
      .replaceAll(
        RegExp(r'\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b', caseSensitive: false),
        '[email]',
      )
      .replaceAll(RegExp(r'(?:\+84|0)[\d .-]{8,13}\d'), '[phone]')
      .replaceAll(RegExp(r'\b\d{12,19}\b'), '[number]');
  static String limit(String value, int length) =>
      value.length <= length ? value : value.substring(0, length);
  Future<Map<String, dynamic>> _post(
    String path, {
    required String baseUrl,
    required String token,
    required Object body,
  }) async {
    if (token.trim().length < 24)
      throw const AiFailure(
        'Nhập mã ghép nối từ cửa sổ Start-AI.cmd trong Cài đặt AI.',
      );
    final uri = endpoint(baseUrl, path);
    final c = client ?? http.Client();
    try {
      final response = await c
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer ${token.trim()}',
            },
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(const Duration(seconds: 110));
      Map<String, dynamic> data;
      try {
        data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        throw const AiFailure(
          'Dịch vụ AI trả dữ liệu không hợp lệ. Bạn vẫn có thể thao tác thủ công.',
        );
      }
      if (response.statusCode != 200) {
        const messages = {
          'UNAUTHORISED': 'Mã ghép nối chưa đúng. Nhập mã từ cửa sổ Start-AI.',
          'AI_QUOTA': 'Gemini báo hết hạn mức hoặc vượt tốc độ. Kiểm tra quota trong Google AI Studio; gửi lại liên tục sẽ không khắc phục.',
          'RATE_LIMIT': 'Đã gửi nhiều yêu cầu. Hãy chờ một phút rồi thử lại.',
          'AI_KEY_DENIED': 'Google từ chối quyền truy cập. Kiểm tra key, project và quyền dùng Gemini.',
          'AI_KEY_INVALID': 'Google báo API key không hợp lệ hoặc đã hết hiệu lực. Nhập lại key trên laptop.',
          'AI_MODEL_UNAVAILABLE': 'Model chưa khả dụng với key/project này. Kiểm tra GEMINI_MODEL trên laptop.',
          'AI_TIMEOUT': 'Gemini chưa trả lời trong thời gian chờ. Thử Kiểm tra Gemini thật trong Cài đặt; với ảnh, chụp cận và rõ hơn.',
          'AI_NETWORK': 'Laptop không gọi được Google Gemini. Kiểm tra Internet, VPN/proxy hoặc tường lửa trên laptop.',
          'AI_BUSY':
              'Máy chủ Gemini đang quá tải hoặc lỗi tạm thời. Chờ rồi thử lại.',
          'AI_REQUEST_REJECTED': 'Google từ chối cấu hình hoặc nội dung yêu cầu (HTTP 400). Gửi mã lỗi và tên model để kiểm tra ứng dụng.',
          'AI_INVALID_RESPONSE': 'Gemini trả dữ liệu không phải JSON hợp lệ. Hãy thử lại; chưa có kết quả nào được áp dụng.',
          'AI_INVALID_OUTPUT': 'JSON từ AI chưa đạt quy tắc dữ liệu của ứng dụng. Không áp dụng thông tin chưa hợp lệ.',
          'AI_EMPTY_RESPONSE': 'Gemini không trả phần câu trả lời. Hãy thử lại với ảnh/văn bản rõ hơn.',
          'AI_TRUNCATED': 'Kết quả Gemini bị cắt vì giới hạn độ dài. Thử hóa đơn ngắn hơn; không dùng kết quả bị thiếu.',
          'AI_BLOCKED': 'Gemini không hoàn thành yêu cầu hoặc đã chặn nội dung. Không có dữ liệu được áp dụng.',
          'AI_UNAVAILABLE': 'Gemini tạm không phục vụ được yêu cầu. Kiểm tra Gemini thật trong Cài đặt.',
          'INVALID_INPUT': 'Nội dung chưa đủ hoặc sai định dạng để phân tích.',
          'REQUEST_TOO_LARGE':
              'Yêu cầu vượt giới hạn dung lượng; chụp/chọn ảnh nhỏ hơn.',
        };
        if (response.statusCode == 404)
          throw const AiFailure(
            'Dịch vụ AI đang là bản cũ. Dừng AI rồi mở lại Start-AI.cmd sau cập nhật.',
          );
        final code = messages.containsKey(data['error'])
            ? data['error'] as String
            : 'AI_UNKNOWN';
        final requestId = data['requestId'];
        final upstream = data['upstreamStatus'];
        final upstreamLabel =
            upstream is int && upstream >= 400 && upstream <= 599
            ? ' • Google HTTP $upstream'
            : '';
        final trace =
            requestId is String && RegExp(r'^[a-f0-9-]{8}$').hasMatch(requestId)
            ? ' • mã $requestId'
            : '';
        throw AiFailure(
          '${messages[code] ?? 'Dịch vụ AI gặp lỗi chưa phân loại.'}\n[$code • HTTP ${response.statusCode}$upstreamLabel$trace]',
        );
      }
      if (data['source'] != 'gemini')
        throw const AiFailure('Không xác minh được nguồn phản hồi AI.');
      return data;
    } on TimeoutException {
      throw const AiFailure(
        'Hết thời gian chờ AI. Bạn vẫn có thể lưu thủ công.',
      );
    } on http.ClientException {
      throw const AiFailure(
        'Không kết nối được AI. Mở Start-AI.cmd và giữ cáp USB kết nối.',
      );
    } finally {
      if (client == null) c.close();
    }
  }

  Future<Map<String, dynamic>> analyzeImage({
    required String baseUrl,
    required String token,
    required String path,
  }) async {
    final file = File(path);
    if (!await file.exists())
      throw const AiFailure('Không còn ảnh hóa đơn để gửi. Hãy chọn/chụp lại.');
    if (await file.length() > 2 * 1024 * 1024)
      throw const AiFailure('Ảnh vượt 2 MB. Chọn/chụp lại ảnh để gửi AI.');
    final bytes = await file.readAsBytes();
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpeg)
      throw const AiFailure('Ảnh AI cần định dạng JPEG hoặc PNG.');
    final data = await _post(
      '/v1/receipt-image',
      baseUrl: baseUrl,
      token: token,
      body: {
        'mimeType': png ? 'image/png' : 'image/jpeg',
        'imageBase64': base64Encode(bytes),
      },
    );
    final details = ReceiptDetails.fromJson(
      Map<String, dynamic>.from(data['details'] as Map),
    );
    if (details.items.any((i) => !i.needsReview))
      throw const AiFailure('Dữ liệu ảnh cần được kiểm tra lại.');
    final m = data['merchant'], a = data['amount'], d = data['date'];
    if ((m != null && (m is! String || m.length > 200)) ||
        (a != null && (a is! int || a <= 0 || a > 999999999999)) ||
        (d != null &&
            (d is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d))))
      throw const AiFailure('Thông tin AI không hợp lệ.');
    if (d != null) {
      final parsed = DateTime.tryParse('$d');
      if (parsed == null ||
          parsed.year < 2000 ||
          parsed.year > 2100 ||
          parsed.toIso8601String().substring(0, 10) != d)
        throw const AiFailure('Ngày AI không hợp lệ.');
    }
    return data;
  }

  Future<String> checkGemini({
    required String baseUrl,
    required String token,
  }) async {
    final data = await _post(
      '/v1/category',
      baseUrl: baseUrl,
      token: token,
      body: {'merchant': 'Kiểm tra kết nối ExpenseMate', 'receiptText': ''},
    );
    if (!categories.contains(data['category']))
      throw const AiFailure('Gemini trả kết quả kiểm tra không hợp lệ.');
    final model = data['model'];
    return model is String && RegExp(r'^[a-zA-Z0-9._-]{1,80}$').hasMatch(model)
        ? model
        : 'Gemini';
  }

  Future<CategorySuggestion> suggest({
    required String baseUrl,
    required String token,
    required String merchant,
    required String receiptText,
  }) async {
    final data = await _post(
      '/v1/category',
      baseUrl: baseUrl,
      token: token,
      body: {
        'merchant': limit(redact(merchant), 200),
        'receiptText': limit(redact(receiptText), 6000),
      },
    );
    if (!categories.contains(data['category']) ||
        data['reason'] is! String ||
        (data['reason'] as String).trim().isEmpty ||
        (data['reason'] as String).length > 500) {
      throw const AiFailure('Gợi ý danh mục không hợp lệ. Hãy chọn thủ công.');
    }
    return CategorySuggestion(
      data['category'] as String,
      data['reason'] as String,
    );
  }

  Future<ReceiptSuggestion> parseReceipt({
    required String baseUrl,
    required String token,
    required String receiptText,
  }) async {
    final data = await _post(
      '/v1/receipt',
      baseUrl: baseUrl,
      token: token,
      body: {'receiptText': limit(redact(receiptText), 6000)},
    );
    Map<String, dynamic> field(String key) {
      final value = data[key];
      if (value is! Map<String, dynamic> ||
          value['evidence'] is! String ||
          (value['evidence'] as String).length > 500) {
        throw const AiFailure('Trường dữ liệu hóa đơn không hợp lệ.');
      }
      if (value['value'] != null &&
          (value['evidence'] as String).trim().isEmpty)
        throw const AiFailure('Gợi ý thiếu đoạn văn bản làm căn cứ.');
      return value;
    }

    final m = field('merchant'), a = field('amount'), d = field('date');
    if (m['value'] != null &&
        (m['value'] is! String || (m['value'] as String).length > 200))
      throw const AiFailure('Tên cửa hàng AI không hợp lệ.');
    if (a['value'] != null &&
        (a['value'] is! int ||
            (a['value'] as int) <= 0 ||
            (a['value'] as int) > 999999999999))
      throw const AiFailure('Số tiền AI không hợp lệ.');
    DateTime? date;
    if (d['value'] != null) {
      if (d['value'] is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d['value'] as String))
        throw const AiFailure('Ngày AI không hợp lệ.');
      final parts = (d['value'] as String).split('-').map(int.parse).toList();
      date = DateTime(parts[0], parts[1], parts[2]);
      if (date.year < 2000 ||
          date.year > 2100 ||
          date.year != parts[0] ||
          date.month != parts[1] ||
          date.day != parts[2])
        throw const AiFailure('Ngày AI không tồn tại.');
    }
    final warnings = data['warnings'];
    if (warnings is! List || warnings.any((v) => v is! String))
      throw const AiFailure('Cảnh báo AI sai định dạng.');
    return ReceiptSuggestion(
      ReceiptField(m['value'] as String?, m['evidence'] as String),
      ReceiptField(date, d['evidence'] as String),
      ReceiptField(a['value'] as int?, a['evidence'] as String),
      List<String>.from(warnings),
    );
  }

  Future<SpendingInsights> insights({
    required String baseUrl,
    required String token,
    required Map<String, Object?> summary,
  }) async {
    final data = await _post(
      '/v1/insights',
      baseUrl: baseUrl,
      token: token,
      body: summary,
    );
    final focus = data['focus'], tips = data['tips'];
    bool text(Object? v, int max) =>
        v is String &&
        v.trim().isNotEmpty &&
        v.length <= max &&
        !RegExp(r'\d').hasMatch(v);
    if (!text(data['headline'], 160) ||
        focus is! List ||
        focus.isEmpty ||
        focus.length > 3 ||
        focus.any((id) => !factIds.contains(id)) ||
        focus.toSet().length != focus.length ||
        tips is! List ||
        tips.isEmpty ||
        tips.length > 3 ||
        tips.any((v) => !text(v, 320)) ||
        (focus.contains('budget') && summary['budget'] == null))
      throw const AiFailure(
        'Nhận xét AI chưa hợp lệ. Số liệu của ứng dụng vẫn xem được bên dưới.',
      );
    return SpendingInsights(
      data['headline'] as String,
      List<String>.from(focus),
      List<String>.from(tips),
    );
  }

  Future<void> health(String baseUrl) async {
    final c = client ?? http.Client();
    try {
      final response = await c
          .get(endpoint(baseUrl, '/health'))
          .timeout(const Duration(seconds: 5));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 ||
          data is! Map ||
          data['service'] != 'ExpenseMate AI')
        throw const AiFailure('Địa chỉ này không phải dịch vụ ExpenseMate AI.');
    } on TimeoutException {
      throw const AiFailure('Không kết nối được dịch vụ trong năm giây.');
    } on http.ClientException {
      throw const AiFailure(
        'Chưa kết nối được. Mở Start-AI.cmd và kiểm tra USB.',
      );
    } on FormatException {
      throw const AiFailure('Dịch vụ trả phản hồi không hợp lệ.');
    } finally {
      if (client == null) c.close();
    }
  }
}
