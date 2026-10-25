# ExpenseMate 1.2.1 — sửa lỗi Gemini và lưu sản phẩm

## Cập nhật như trước

1. Sao lưu dữ liệu trong app. Không gỡ app hoặc xóa dữ liệu.
2. Đặt ExpenseMate_Update_v1.2.1.zip trực tiếp trong C:\Users\ASUS\Projects, không giải nén.
3. Dừng cả app và AI bằng Ctrl+C.
4. Chạy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Projects\ExpenseMate_Starter_v0.1.0\expense_mate\scripts\find-update.ps1"
```

Chờ analyzer sạch, 44 test Flutter và 34 test Node đạt, Updated 1.2.0 -> 1.2.1. Lỗi sẽ rollback source.

5. Mở PowerShell chạy app:

```powershell
& "$env:USERPROFILE\Projects\ExpenseMate_Starter_v0.1.0\expense_mate\Start-App.cmd"
```

6. PowerShell thứ hai:

```powershell
& "$env:USERPROFILE\Projects\ExpenseMate_Starter_v0.1.0\expense_mate\Start-AI.cmd"
```

Nhập lại Gemini key ẩn. Giữ USB. Cửa sổ AI phải hiện ExpenseMate AI 1.2.1 ready. Model mặc định vẫn gemini-3.8-flash; không cần đổi key chỉ vì dùng chung AIStudyMate. Kiểm tra app Cài đặt là 1.2.1.

## Kiểm tra Gemini thật trước khi đọc ảnh

Cài đặt → Kết nối Gemini → Kiểm tra Gemini thật. Nút này dùng URL và mã ghép nối đang nhập, gửi đúng một yêu cầu văn bản nhỏ không chứa hóa đơn. Có sử dụng hạn mức API. Nếu vừa thay cấu hình, bấm Lưu cấu hình để các màn hình khác dùng cấu hình mới.

- Thành công: xác nhận Google đã trả lời qua laptop ở lần thử đó. Sau đó thử gợi ý danh mục và đọc ảnh riêng; thành công văn bản không bảo đảm ảnh không hết giờ.
- AI_NETWORK: laptop không gọi được Google; kiểm tra Internet, VPN/proxy, tường lửa.
- AI_QUOTA: Google báo quota/tốc độ; kiểm tra project/model trong Google AI Studio. Gửi liên tục không giúp hết hạn mức. Key trong cùng project chia sẻ quota.
- AI_KEY_INVALID / AI_KEY_DENIED: kiểm tra key, quyền/project. Không gửi key cho trợ lý.
- AI_MODEL_UNAVAILABLE: model chưa khả dụng với project/key; kiểm tra model được cấp quyền. Script đã hỗ trợ GEMINI_MODEL như trước.
- AI_REQUEST_REJECTED / Google HTTP 400: cấu hình/nội dung bị Google từ chối. Gửi mã lỗi, ID và model trên terminal để kiểm tra; không gửi bí mật.
- AI_TIMEOUT: Google chưa trả trước 60 giây văn bản / 90 giây ảnh. Client chờ 110 giây để nhận lỗi của server. Không tự retry hoặc giả vờ thành công. Thử lại sau; ảnh chụp cận, rõ hơn, tránh nền quá nhiều.
- AI_EMPTY_RESPONSE / AI_TRUNCATED / AI_BLOCKED: Google không trả câu trả lời đầy đủ hoặc không hoàn thành. Không áp dụng kết quả; thử nội dung/ảnh rõ hơn hoặc hóa đơn ngắn hơn.
- AI_INVALID_RESPONSE / AI_INVALID_OUTPUT: dữ liệu chưa hợp lệ; không tự lưu. Gửi mã lỗi/ID để kiểm tra.

Terminal chỉ ghi route, code, model, thời gian, HTTP status và mã yêu cầu. Không ghi nội dung ảnh/OCR/key hoặc chi tiết lỗi thô từ Google. Ảnh vẫn chỉ được gửi sau khi người dùng đồng ý, không tự gửi lại.

Lưu ý: chưa có API key thật trong môi trường tạo bản cập nhật, nên chưa biết lỗi trên laptop là quota/network/model hay phản hồi cụ thể. Bản sửa cải thiện độ trễ, xử lý JSON và cho chẩn đoán; không tuyên bố mọi lỗi upstream đã được khắc phục.

## Lưu sản phẩm không còn thông báo gộp chung

Bấm Lưu khi còn vấn đề sẽ có danh sách cụ thể, ví dụ:
- Dòng 1 “Xúc xích” đủ số liệu nhưng chưa xác nhận đối chiếu.
- Dòng 2 thiếu đơn giá/thành tiền.
- Dòng 3 số lượng × đơn giá khác thành tiền.
- Tổng dòng 30.000, tổng hóa đơn 80.000, chênh 50.000: có thể còn thiếu sản phẩm.

Nút Đến Sản phẩm/Hóa đơn/Đối chiếu đưa đến mục phù hợp; không tự sửa hoặc xóa dòng.

Nếu đã đối chiếu nhiều dòng: chọn Xác nhận các dòng đã đủ và khớp → xác nhận đã kiểm tra. Chỉ các dòng đầy đủ, phép nhân khớp mới được đánh dấu; dòng thiếu hoặc sai giữ nguyên. Vẫn phải kiểm tra tổng và tích xác nhận toàn hóa đơn tại Đối chiếu.

Với WinMart, cần đủ ba dòng đã xác nhận: 34.000 + 30.000 + 16.000 = 80.000 nếu bạn đã đối chiếu phần mờ cuối. Hình bạn gửi chỉ có dòng 30.000 nên chưa đủ. Không thêm dữ liệu suy đoán để vượt kiểm tra. Ngày không có trên ảnh phải chọn ngày mua thực tế.

## Bằng chứng kiểm tra

34 test Node giả lập đạt, gồm cấu hình thinking đúng model, không ghép thought text vào JSON, nhận dạng kết quả rỗng/cắt/chặn và các lỗi upstream, không lộ key/receipt trong diagnostics. Kiểm tra Dart thật cho model/parser/lỗi lưu cụ thể và dữ liệu cũ–mới đạt; analyzer models sạch. Có 44 test Flutter để updater chạy.

Chưa chạy trọn bộ Flutter analyzer/tests, build Android, UI điện thoại hoặc Gemini thật của 1.2.1 trong môi trường đóng gói. Bài thử trên laptop/điện thoại là bước nghiệm thu tiếp theo. DB và dữ liệu giữ cấu trúc 1.2.0.
