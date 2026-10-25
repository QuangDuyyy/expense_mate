# Kịch bản video 2–3 phút

Chuẩn bị: Android thật, một hóa đơn rõ chữ không chứa thông tin cá nhân nhạy cảm,
ít nhất hai danh mục chi trong tuần, server AI đã chạy nếu trình diễn Gemini.
Không quay màn hình nhập API key, mật khẩu ký hay mã ghép nối.

| Thời gian | Thao tác | Lời dẫn gợi ý |
|---|---|---|
| 0:00–0:15 | Tổng quan | ExpenseMate giúp ghi chi tiêu từ hóa đơn, giảm nhập tay. |
| 0:15–0:50 | Camera quét hóa đơn thật | ML Kit nhận diện chữ trên thiết bị, sau đó Dart Regex tìm thông tin thanh toán. |
| 0:50–1:15 | Review, sửa một trường | OCR có thể sai nên người dùng kiểm tra tên, ngày và tổng tiền trước lưu. |
| 1:15–1:40 | Gợi ý Gemini rồi áp dụng | Khi được đồng ý, Gemini gợi ý danh mục; người dùng quyết định. Có thể bỏ qua để dùng offline. |
| 1:40–2:05 | Xác nhận lưu, mở biểu đồ | Provider cập nhật UI; SQLite giữ bản ghi; CustomPainter tự vẽ biểu đồ và hoạt ảnh. |
| 2:05–2:25 | Mở lịch sử, đóng/mở app | Thông tin và ảnh được lưu cục bộ, xem lại được. |
| 2:25–2:45 | Đổi dark mode; kết | App có sáng/tối, sao lưu và bản APK ký riêng. Hạn chế là OCR phụ thuộc chất lượng ảnh. |

Quay lại nếu có lỗi, nhưng không ghép phần OCR giả thành quét thật. Giữ video trong 2–3 phút.

# Trình tự thuyết trình

1. Nêu bài toán và người dùng: sinh viên hoặc người quản lý CLB có hóa đơn cần ghi lại.
2. Demo trọn một luồng, không giải thích code trước khi thầy thấy sản phẩm.
3. Mở sơ đồ kiến trúc, đi đúng đường camera → OCR → parser → review → SQLite → chart.
4. Show một hàm thực tế: home_screen.processPhoto → OcrService.recognize → ReceiptParser.parse.
5. Show save: ReviewScreen.save → ExpenseStore.save → DatabaseService.save.
6. Show chart: weekly/daily → ExpenseCharts → DonutPainter.paint / BarPainter.paint.
7. Show AI riêng: consent → AiService → server /v1/category → Gemini → validated suggestion → Apply.
8. Chốt kết quả thật, hạn chế và hướng phát triển.

# Hỏi đáp thường gặp

**Flutter và Dart khác nhau?** Flutter là bộ công cụ xây ứng dụng; Dart là ngôn ngữ viết code.

**OCR là gì? AI ở đâu?** OCR chuyển chữ trong ảnh thành văn bản. ML Kit dùng mô hình học máy trên thiết bị.
Gemini là phần AI tạo sinh bổ sung để gợi ý danh mục; Regex là quy tắc lập trình, không phải AI.

**Tại sao có Regex sau OCR?** OCR chỉ trả text. Parser tìm các mẫu tổng tiền/ngày và lọc dòng tiền thừa.

**OCR sai xử lý thế nào?** Không tự lưu. Review hiển thị ảnh/text gốc, cho sửa và nhập bổ sung.

**Provider làm gì?** Giữ danh sách khoản chi dùng chung; notifyListeners báo widget theo dõi để cập nhật.

**SQLite và Provider có giống nhau?** Provider giữ trạng thái khi chạy; SQLite giữ dữ liệu trên đĩa qua các lần mở app.

**Dữ liệu có ra mạng không?** OCR và lưu trữ cục bộ. Chỉ khi đồng ý gợi ý Gemini, một phần text được gửi qua dịch vụ tới Google.

**Khóa Gemini ở đâu?** Trong môi trường tiến trình Node trên laptop, nhập ẩn, không nhúng APK hoặc lưu vào Git.

**Không có mạng?** Không có gợi ý Gemini; vẫn có OCR với model đã sẵn sàng, chọn danh mục thủ công và lưu cục bộ.

**Tại sao tự vẽ biểu đồ?** Theo rubric, dùng Canvas drawArc/drawRRect trong CustomPainter, không dùng thư viện chart thay thế.

**Vì sao release cài riêng?** Khóa debug và khóa release khác nhau, Android không cho cập nhật chéo chữ ký. Suffix riêng giữ app cũ;
backup chuyển khoản chi và ảnh sang release mà không gỡ debug.

**Sao lưu có chống trùng?** File giữ origin của bản cài và ID gốc. restored_items ghi cặp origin/ID đã nhập.

**Có đảm bảo AI đúng?** Không. Chỉ danh mục hợp lệ được nhận, có giải thích và người dùng áp dụng. Sai thì sửa thủ công.
