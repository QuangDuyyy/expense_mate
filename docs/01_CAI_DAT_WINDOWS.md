# Bước đầu: cài công cụ và mở ứng dụng

Mục tiêu đầu tiên: máy nhận lệnh Flutter, nhận điện thoại Android rồi mở được ExpenseMate.
Bạn chỉ cần làm lần lượt, chưa cần hiểu toàn bộ mã nguồn.

## 1. Cài Git và VS Code

- Git cho Windows: https://git-scm.com/downloads/win
- VS Code: https://code.visualstudio.com/
- Nếu đã có thì giữ nguyên, không cần gỡ cài lại.

## 2. Cài Flutter SDK qua VS Code

1. Mở VS Code, nhấn Ctrl+Shift+X để mở Extensions.
2. Tìm **Flutter**, cài extension do **Dart Code** phát hành.
3. Nhấn Ctrl+Shift+P, tìm **Flutter: New Project**.
4. Nếu được hỏi SDK, chọn **Download SDK**.
5. Chọn thư mục cha `C:\src` để đặt SDK tại `C:\src\flutter`.
   Tránh Program Files, OneDrive và đường dẫn có dấu.
6. Chọn **Clone Flutter**, chờ tải xong, chọn **Add SDK to PATH**.
7. Đóng và mở lại VS Code cùng PowerShell. Chưa cần tạo app mẫu.
8. Trong terminal mới, chạy:

```powershell
flutter --version
flutter doctor -v
```

Nếu `flutter` không được nhận diện, kiểm tra PATH có `C:\src\flutter\bin`.
Hướng dẫn chính thức: https://docs.flutter.dev/install/with-vs-code

## 3. Cài Android Studio để có Android SDK

1. Tải từ https://developer.android.com/studio và cài đặt theo trình hướng dẫn.
2. Mở Android Studio → More Actions → SDK Manager.
3. SDK Platforms: cài Android SDK Platform được hướng dẫn Flutter hiện hành khuyến nghị
   (trang hướng dẫn đang dùng API 36 khi chuẩn bị bộ nguồn).
4. SDK Tools: kiểm tra Android SDK Build-Tools, Command-line Tools (latest), Platform-Tools.
   Cài Android Emulator nếu cần máy ảo; NDK/CMake nếu Flutter yêu cầu.
5. Apply, chờ cài xong.
6. Trong PowerShell chạy:

```powershell
flutter doctor --android-licenses
flutter doctor -v
```

Đọc và chấp nhận các điều khoản bạn đồng ý. Mục Android toolchain cần hết lỗi.
Cảnh báo Visual Studio cho Windows desktop không phải điều kiện để chạy Android.
Bạn vẫn viết code bằng VS Code; Android Studio cung cấp công cụ Android.

## 4. Kết nối điện thoại Android

1. Điện thoại → Thông tin điện thoại → nhấn Số bản dựng nhiều lần để bật Tùy chọn nhà phát triển.
   Tên menu có thể khác giữa các hãng.
2. Trong Tùy chọn nhà phát triển, bật Gỡ lỗi USB (USB debugging).
3. Cắm cáp USB có truyền dữ liệu, mở khóa điện thoại và xác nhận cho phép máy tính gỡ lỗi.
4. Windows có thể cần USB driver của hãng.
5. Chạy `flutter devices`. Kết quả phải có điện thoại Android, không chỉ Chrome/Windows.

Nếu chỉ có iPhone, báo lại để điều chỉnh môi trường; bộ nguồn hiện tại chuẩn bị cho Android.
Chưa có điện thoại thì có thể chạy Android Emulator và thử ảnh hóa đơn từ thư viện,
nhưng sản phẩm cuối vẫn cần thử camera thật như đề bài yêu cầu.

## 5. Chuẩn bị bộ nguồn

1. Giải nén ZIP, đặt thư mục `expense_mate` ở `C:\Projects\expense_mate`.
2. Chưa chạy trực tiếp bên trong ZIP.
3. Mở thư mục này bằng File → Open Folder trong VS Code.
4. Chạy `01_Setup.cmd` một lần. Script tạo wrapper Android và tải thư viện.
5. Chạy `04_Validate.cmd`: phân tích mã và kiểm thử parser.
6. Chạy `03_Run.cmd`. Nếu có nhiều thiết bị, chọn Android.

Hoặc dùng terminal trong thư mục dự án:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
flutter analyze
flutter test
flutter devices
flutter run -d MA_THIET_BI_ANDROID
```

Thay `MA_THIET_BI_ANDROID` bằng mã thật từ `flutter devices`; không gõ nguyên chữ đó.
Lần build đầu có thể mất lâu vì tải Gradle và Android dependencies. Cần mạng lúc cài.
`ExecutionPolicy Bypass` ở đây chỉ áp dụng tiến trình chạy script, không đổi cấu hình toàn máy.

## 6. Thử phiên bản đầu

- Thêm thủ công một khoản chi 65000, chọn ngày và danh mục, xác nhận lưu.
- Tắt và mở lại app: khoản chi vẫn còn.
- Mở lịch sử, sửa số tiền; thống kê tuần tương ứng phải thay đổi.
- Quét hóa đơn, đối chiếu ảnh và thông tin trước khi xác nhận.
- Thử hóa đơn không có ngày: app yêu cầu bạn chọn ngày.
- Đổi sáng/tối, đóng mở lại kiểm tra lựa chọn.
- Xóa khoản chi và kiểm tra thống kê cập nhật.

## 7. Khi có lỗi

Dừng ở lỗi đầu tiên. Gửi nguyên phần thông báo lỗi trong terminal và lệnh vừa chạy.
Chưa dùng `flutter clean`, chưa xóa SDK hoặc cài lại toàn bộ khi chưa xác định nguyên nhân.
Có thể gửi ảnh chụp nếu khó sao chép chữ; đừng chụp mật khẩu hoặc khóa API.
