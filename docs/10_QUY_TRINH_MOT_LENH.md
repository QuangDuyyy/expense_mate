# Quy trình làm việc chính thức từ 1.0.3

Trợ lý gửi một ZIP mới → chủ dự án tải vào Downloads → dừng app/AI → chạy một lệnh PowerShell
→ tự chọn phiên bản, sao lưu, thay source, gỡ tệp cũ đã bỏ khỏi manifest, kiểm tra và khôi phục nếu lỗi.

Lệnh cố định, không phụ thuộc tên hoặc hậu tố của ZIP:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Projects\ExpenseMate_Starter_v0.1.0\expense_mate\scripts\find-update.ps1"
```

ZIP phải ở Downloads hoặc expense_mate-updates cạnh dự án. Không cần giải nén.
Kết quả thành công có Updated ... -> VERSION_MOI và Source backup: ...
Không tạo thư mục dự án chạy theo từng phiên bản. Source backup và ZIP processed được cất riêng,
không tự xóa vì đây là đường quay lại khi cần. Không xóa tệp cấu hình riêng hoặc dữ liệu điện thoại.

Cơ chế chỉ xóa source lỗi thời có tên trong manifest phiên bản cũ và vắng trong manifest mới.
Đường dẫn phải thuộc danh sách source được phép; không cho xóa .local, key.properties, keystore,
.env, node_modules hoặc đường dẫn đi ra ngoài dự án. Source cũ bị thay/xóa được sao lưu trước;
phục hồi thất bại được báo để xử lý, không che lỗi.

Sau cập nhật, mở/cài bản app mới bằng Start-App.cmd, rồi mở Start-AI.cmd ở PowerShell thứ hai và kiểm tra version trên điện thoại.
Nếu chỉ cập nhật file source mà chưa build/cài, app đã cài trên điện thoại vẫn có thể là bản trước.
