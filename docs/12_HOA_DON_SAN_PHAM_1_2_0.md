# ExpenseMate 1.2.0 — hóa đơn và sản phẩm

## Cập nhật

1. Trong app đang dùng, xuất backup JSON và lưu ở nơi bạn kiểm soát. Không gỡ app hoặc xóa dữ liệu.
2. Đặt ExpenseMate_Update_v1.2.0.zip trực tiếp trong C:\Users\ASUS\Projects, giữ nguyên ZIP.
3. Ctrl+C ở cả hai cửa sổ app và AI.
4. Chạy lệnh cố định:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Projects\ExpenseMate_Starter_v0.1.0\expense_mate\scripts\find-update.ps1"
```

5. Chờ analyzer sạch, 39 test Flutter đạt, 26 test Node đạt, `Updated 1.1.1 -> 1.2.0`. Bản cũ có thể khác. Nếu lỗi thì source được khôi phục; gửi log, không gửi key hoặc mã ghép nối.
6. PowerShell thứ nhất:

```powershell
& "$env:USERPROFILE\Projects\ExpenseMate_Starter_v0.1.0\expense_mate\Start-App.cmd"
```

7. PowerShell thứ hai:

```powershell
& "$env:USERPROFILE\Projects\ExpenseMate_Starter_v0.1.0\expense_mate\Start-AI.cmd"
```

Phải khởi động lại AI để có endpoint đọc ảnh. Giữ USB, nhập key ẩn trên laptop. Kiểm tra app trong Cài đặt là 1.2.0 và dữ liệu cũ vẫn còn.

## Thử hóa đơn WinMart của bạn

1. Chọn/chụp lại ảnh, để hóa đơn phẳng, đủ ánh sáng và chữ lớn trong khung. OCR dùng tọa độ ghép hàng/cột nhưng vẫn có thể thiếu hoặc ghép sai khi ảnh nghiêng/mờ.
2. Hóa đơn: đối chiếu tên WINMART, tổng 80.000đ. Chọn ngày thực tế vì ảnh mẫu không in ngày. Không tự dùng mã hóa đơn làm ngày/số tiền.
3. Sản phẩm: xem các dòng OCR tìm được. Kiểm tra sữa chua 1 × 34.000 = 34.000; xúc xích sườn hầm 3 × 10.000 = 30.000. Dòng cuối 1 × 16.000 cần đối chiếu phần thành tiền bị mờ. Không coi số suy ra là chữ đã nhận diện chắc chắn.
4. Bấm Sửa để chỉnh tên/số lượng/giá/thành tiền; có thể tính từ số lượng × đơn giá nhưng phải đối chiếu với giấy. Mỗi dòng OCR/AI có nút “Tôi đã đối chiếu dòng này”. Hủy sửa không thay đổi dòng; xóa cần xác nhận.
5. Nếu OCR thiếu: AI phân tích ảnh hóa đơn → xem ảnh và hộp đồng ý → Đồng ý gửi ảnh. Ảnh đầy đủ được gửi tới Gemini qua dịch vụ laptop, không tự che thông tin cá nhân. Không đồng ý thì không gửi.
6. Khi AI trả kết quả, xem từng dòng/cảnh báo. Mặc định không ghi đè trường đã có. Muốn thay tổng sai như 9đ phải chủ động chọn đề xuất tổng đúng. Chọn danh sách sản phẩm sẽ thay cả danh sách và mã/giảm giá/phụ phí đề xuất; hãy xem trước.
7. Áp dụng mục đã chọn không tự lưu. Sản phẩm AI vẫn phải đối chiếu; không rõ thì nhập tay, không coi AI là nguồn tuyệt đối chính xác.
8. Đối chiếu: tổng ba dòng phải 80.000đ nếu bạn đã xác nhận dòng cuối 16.000đ. Giảm giá/phụ phí để 0 khi thực tế không có. Chỉ nhập thuế cộng thêm chưa nằm trong giá sản phẩm, tránh cộng hai lần.
9. Xác nhận đã đối chiếu toàn bộ rồi lưu. Lịch sử chỉ thêm MỘT khoản chi 80.000đ; mở lại sẽ có các sản phẩm kèm theo. Biểu đồ không cộng thêm từng sản phẩm lần nữa.

## Ca thử bắt buộc

- Ảnh mờ hoặc tổng OCR nhiễu: để trống/nhắc kiểm tra, không tự lưu một con số sai. Số nhỏ hợp lệ không bị cấm theo ngưỡng tùy tiện.
- Thiếu ngày: phải chọn ngày thực tế. Không lấy ngày hôm nay do AI suy đoán.
- Bấm Hủy gửi ảnh: dữ liệu giữ nguyên, không gọi AI.
- Sửa tổng/tên trước khi AI trả: không thay nếu không chọn mục đó. Danh sách đã có mặc định không chọn thay.
- Dòng thiếu đơn giá/thành tiền: không tự suy ra; nhập/sửa rồi kiểm tra.
- Sai phép nhân: nút xác nhận đã đối chiếu không che mâu thuẫn; sửa giá/thành tiền phù hợp trước khi lưu.
- Tổng dòng lệch tổng hóa đơn: xem giảm giá/phụ phí, bổ sung dòng thiếu. Bản này yêu cầu khớp khi đã nhập chi tiết; có thể xóa chi tiết không tin cậy và lưu theo tổng đã đối chiếu, thay vì tạo sản phẩm giả.
- Sản phẩm cân ký: số lượng 0,5 và đơn giá 20.000 cho thành tiền 10.000. Sản phẩm tặng đơn giá/thành tiền 0 được phép.
- Tắt server, sai token hoặc hết quota: báo lỗi, vẫn nhập và sửa tay được.
- Ảnh vượt 2 MB hoặc không JPEG/PNG: báo lỗi trước gửi. Chụp/chọn lại để app thu nhỏ; không chạy thao tác nén đè ảnh gốc.
- Lưu rồi khởi động lại: chi tiết còn. Xóa một hóa đơn xóa khoản chi và ảnh như trước.
- Backup: xuất mới, chuyển sang app 1.2.0, nhập và kiểm tra sản phẩm/ảnh; nhập lại cùng backup không nhân đôi. Backup cũ không có sản phẩm vẫn dùng được.

## Trạng thái và giới hạn

26 test Node giả lập đã đạt, có kiểm tra endpoint ảnh không gọi upstream khi thiếu xác thực và giữ null cho dữ liệu không đọc được. Kiểm tra trực tiếp Dart parser/model/round-trip cũ–mới đạt; analyzer models sạch. Formatter/cú pháp/import và ZIP được kiểm tra. Có 39 test Flutter để updater chạy.

Chưa chạy Flutter analyzer/tests trọn bộ, build Android, thử UI trên điện thoại hoặc gọi Gemini thật cho 1.2.0 trong môi trường đóng gói. Không dùng test giả lập làm bằng chứng ảnh hóa đơn thật đã đọc chính xác.

OCR cục bộ là heuristic cho bảng có tiêu đề đơn giá/số lượng/thành tiền; chưa hỗ trợ mọi bố cục, mã hàng lẫn tên cùng dòng hoặc mọi điều chỉnh theo từng sản phẩm. AI có thể hiểu bố cục tốt hơn nhưng vẫn có thể sai. Báo cáo PDF/HTML cũ vẫn là bản nháp, cần cập nhật ảnh và chức năng trước khi nộp.
