# Cập nhật theo cách làm AIStudyMate

1. Ở terminal đang chạy app, nhấn Ctrl+C và chờ kết thúc. Dừng cửa sổ AI cũ nếu có.
2. Tải ZIP 1.0.0, giải nén vào thư mục riêng, không chép tay đè lên Android wrapper.
3. Chạy `Update-ExpenseMate.cmd` trong thư mục bản mới. Script ưu tiên tìm bản cũ ở:
   `C:\Users\ASUS\Projects\ExpenseMate_Starter_v0.1.0\expense_mate`.
   Nếu không có, chọn thư mục chứa pubspec.yaml của bản đang chạy.
4. Chờ setup, analyze và test. Nếu thất bại, script khôi phục các tệp source đã thay
   và cấu hình Android bị sửa; lưu đường dẫn backup để tra cứu.
5. Sau thành công, luôn chạy từ thư mục cũ:

```powershell
cd "C:\Users\ASUS\Projects\ExpenseMate_Starter_v0.1.0\expense_mate"
.\Start-App.cmd
```

6. Kiểm tra dữ liệu cũ còn đủ; Cài đặt hiển thị ExpenseMate 1.0.0.
7. AI: cài Node.js LTS 22+; terminal thứ hai trong cùng thư mục chạy `Start-AI.cmd`.
   Khóa Gemini nhập ẩn, không ghi file. Nếu dán khóa thấy ít ký tự che, không suy ra khóa bị cắt;
   không gửi khóa để hỏi. Mã ghép nối được lưu riêng trong `.local`, bỏ qua Git và source ZIP.
8. Trong điện thoại: Cài đặt → Kết nối Gemini, URL http://127.0.0.1:8787,
   mã ghép nối ở laptop → Lưu → Kiểm tra kết nối.
9. Thêm khoản chi/quét hóa đơn, bấm Gợi ý, xem nội dung, đồng ý gửi rồi áp dụng nếu hợp lý.

Qua USB: script dùng adb reverse, không mở dịch vụ ra Wi-Fi và không yêu cầu mở firewall.
Rút/cắm lại điện thoại: chạy lại Start-AI.cmd để thiết lập lại reverse.
Model mặc định `gemini-3.8-flash`, đổi bằng GEMINI_MODEL nếu tài khoản không có quyền dùng model đó.
Quota và quyền model phụ thuộc tài khoản Google, không giả lập thành gợi ý thành công.

## Các lần cập nhật sau

Từ bản 1.0: tải ZIP ExpenseMate mới vào Downloads hoặc thư mục expense_mate-updates cạnh dự án,
dừng app/AI rồi chạy lại Start-App.cmd trong cùng thư mục. Script đọc VERSION trong ZIP,
chọn bản cao nhất (không dựa tên có hậu tố (1)/(2)), kiểm tra đường dẫn/kích thước/hash,
sao lưu, cập nhật và chạy kiểm tra trước khi mở app. ZIP thành công được cất vào processed;
ZIP cùng hoặc thấp phiên bản đang chạy được bỏ qua. Không thể ngăn trình duyệt tạo hậu tố
khi tải, nhưng chúng không tạo thêm bản cài dự án và không quyết định bản đang chạy.

## Những gì được giữ

- Toàn bộ DB/ảnh đang ở app debug trên điện thoại (không adb uninstall/clear).
- Application ID debug, đường dẫn SDK/Flutter, Gradle wrapper tạo bởi máy người dùng.
- Khóa ký `.local/*.jks`, android/key.properties, .local/pairing-token.txt.
- Các tệp source cũ bị thay đều có bản sao trong expense_mate-backups bên cạnh dự án.

Updater kiểm tra từng tệp bằng SHA-256 để phát hiện thiếu/hỏng nội dung; đây không phải chữ ký nhà phát hành.
Các chỉnh sửa riêng trong tệp nguồn được sao lưu nhưng không tự gộp; khôi phục từ backup nếu cần.
Backup source không phải backup dữ liệu điện thoại: xuất backup trong app trước khi đổi máy/gỡ app.

## Khi cần quay lại source cũ

Dừng build/AI, chạy Restore-Source.cmd và nhập đường dẫn backup mà updater đã in.
Lệnh phục hồi source không xóa dữ liệu/ảnh trên điện thoại hoặc khóa ký.
Dùng lại `flutter pub get` để đồng bộ dependencies sau phục hồi.

## JAVA_HOME và ổ đĩa

Script ưu tiên JBR hợp lệ ở Android Studio1/Android Studio, bỏ qua JAVA_HOME cũ trỏ jdk-22 không tồn tại.
Không tự đổi biến môi trường toàn máy, không dọn SDK/Gradle cache hoặc dữ liệu cá nhân.
Nếu vẫn hết ổ C, dừng ở lỗi, xem dung lượng rồi chuyển SDK có kiểm tra; không tạo thêm các bản sao SDK tùy tiện.
