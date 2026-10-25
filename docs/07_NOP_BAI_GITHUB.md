# Chuẩn bị bộ nộp

## 1. APK thật

- Chạy Build-Release.cmd. Nhập thông tin khóa/mật khẩu tại máy bạn, không gửi lên chat.
- File: release/app-release.apk, kèm SHA-256. Không đổi tên bản debug thành release.
- Cài trên Samsung, bản này có tên ExpenseMate Release. Giữ debug để đối chiếu/chuyển backup.
- Ghi kết quả R01/R02 trong 05_NGHIEM_THU.md.
- Khóa nằm .local/expense-mate-release.jks; android/key.properties chứa mật khẩu.
  Giữ riêng tư, sao lưu cá nhân; các lần release sau dùng cùng khóa.

## 2. Ảnh và báo cáo

- Chạy Capture-Evidence.cmd, làm theo hướng dẫn từng màn hình.
- Mở docs/report.html trong Chrome hoặc Edge. Điền họ tên/MSSV/lớp, repository và các kết quả mới.
- Ảnh thật nằm docs/evidence/light.png, dark.png, review.png, charts.png, ai.png.
- In Ctrl+P → Save as PDF → A4, scale 100%, bật Background graphics, tắt browser headers/footers.
- Kiểm tra bản PDF 4 trang, có ảnh sáng/tối và sơ đồ/bảng Regex/hạn chế.
- Bản PDF tạo sẵn là dự thảo chuẩn bị nghiệm thu, không dùng thay bản cập nhật ảnh/kết quả cuối.
- Nội dung bám mục yêu cầu slide. Chưa xác minh được file mẫu riêng từ portal; nếu thầy có mẫu khác, cần áp vào trước nộp.

## 3. GitHub công khai

- Chạy Package-Submission.cmd để tạo ZIP source đã lọc các tệp riêng tư.
- Giải nén source ZIP sang thư mục dành cho GitHub, mở bằng VS Code.
- Source Control → Initialize Repository → kiểm tra các tệp chuẩn bị commit.
- Không đưa .local, key.properties, *.jks, *.keystore, .env, log riêng tư hoặc dữ liệu/backup người dùng lên repo.
- Commit với nội dung rõ ràng, chọn Publish to GitHub và chọn Public bằng tài khoản của bạn.
- Không bịa commit hoặc tạo lịch sử phát triển giả. README, pubspec.lock, lib/test/server/scripts/docs/.github đều cần có.
- Mở link bằng cửa sổ chưa đăng nhập để kiểm tra public.
- Tạo GitHub Release v1.0.0, đính kèm APK, SHA-256 và báo cáo PDF cuối.
- Quay video 2–3 phút theo 06_KICH_BAN_VIDEO_VA_BAO_VE.md; tải lên nơi truy cập được, kiểm tra quyền xem.

## 4. Điền biểu mẫu

- Chọn Project 3: Flutter - Quản Lý Chi Tiêu OCR Hóa đơn - Flutter (ML Kit).
- Link GitHub Repository: repo public thật.
- Link Live demo: có thể chuẩn bị trang GitHub Release chứa APK và hướng dẫn cài điện thoại;
  cần đối chiếu cách thầy yêu cầu cho trường chung của các mini-project. Không coi APK là bản web OCR.
- Báo cáo: PDF 2–4 trang, hoặc .md nếu thầy chấp nhận theo biểu mẫu.
- Hạn nộp theo lịch lớp: slide ghi cuối tuần học 8, Chủ nhật 23:59; chưa có ngày cụ thể.

Chủ dự án tự đăng nhập/tạo repository, nhập khóa ký/API key và ghi hình điện thoại.
Trong gói hiện tại chưa có các URL công khai hay APK/video thật.
