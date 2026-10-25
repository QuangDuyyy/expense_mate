# 1.2.1

- Giữ Gemini; cấu hình thinking low cho Gemini 3/4, thinkingBudget 0 cho Gemini 2.5 Flash; không gửi MINIMAL không được 3.8 hỗ trợ. Giảm thời gian suy luận cho tác vụ trích dữ liệu.
- Chờ upstream tối đa 60 giây cho văn bản, 90 giây cho ảnh; client 110 giây. Không tự retry gây tiêu hao hạn mức.
- Chỉ lấy phần trả lời, bỏ thought parts; phân biệt kết quả rỗng, bị chặn, cắt MAX_TOKENS, JSON sai và dữ liệu không đạt schema.
- Phân biệt mạng laptop, quota, quyền/key, model, HTTP 400, quá tải và timeout. Log chỉ mã lỗi/model/route/thời gian/ID, không log key, ảnh hoặc văn bản hóa đơn.
- Thêm Kiểm tra Gemini thật trong Cài đặt bằng một yêu cầu văn bản tổng hợp không chứa giao dịch cá nhân.
- Lỗi lưu liệt kê dòng cụ thể thiếu trường gì, chưa xác nhận, sai phép nhân hoặc lệch tổng; nút chuyển đúng mục cần sửa.
- Xác nhận hàng loạt có hộp đồng ý, chỉ áp dụng cho các dòng đủ và phép tính khớp; không bỏ kiểm tra hoặc sửa số tiền.
- Giữ dữ liệu, cấu trúc DB và workflow ZIP Projects/hai PowerShell. 34 test Node giả lập đạt; Dart model/parser/nghiệp vụ đạt, models analyzer sạch. Có 44 test Flutter; chưa chạy toàn bộ Flutter/build/UI/Gemini thật tại môi trường đóng gói.

# 1.2.0

- Tích hợp ba mục Hóa đơn / Sản phẩm / Đối chiếu theo bản mô phỏng đã duyệt.
- OCR giữ tọa độ để ghép hàng/cột; đọc thử bảng đơn giá–số lượng–thành tiền và tên nhiều dòng. Chưa rõ thì để trống; cần người dùng kiểm tra.
- Parser tổng tiền không trích riêng chữ số đầu từ chuỗi nhiễu; hỗ trợ dấu chấm sau nhãn “Tổng cộng.”.
- Thêm/sửa/xóa sản phẩm, số lượng thập phân, đơn giá và thành tiền; tính đối chiếu giảm giá/phụ phí và tổng hóa đơn.
- AI phân tích ảnh JPEG/PNG sau đồng ý rõ ràng, giữ key trên laptop; giới hạn ảnh 2 MB, xác thực token và kiểm tra JSON. Màn hình đề xuất cho chọn áp dụng, giữ trường đã có theo mặc định, không tự lưu.
- Chi tiết JSON lưu cùng khoản chi, additive SQLite column; đọc dữ liệu cũ và sao lưu/khôi phục chi tiết mới.
- Ảnh/hóa đơn có sản phẩm cần xác nhận đối chiếu trước lưu. Không cộng trùng sản phẩm vào thống kê.
- Projects là vị trí ZIP cập nhật chính thức; vẫn hỗ trợ Downloads. Giữ quy trình một ZIP và hai PowerShell.
- 26 test Node giả lập đạt, Dart nghiệp vụ độc lập đạt. Có 39 test Flutter để updater chạy; chưa xác nhận Flutter full suite/build Android/UI hoặc Gemini thật cho bản này tại môi trường đóng gói.

# 1.1.1

- Sửa widget test bị bấm trượt nút AI khi nút nằm sát thanh lưu cố định: tìm toàn bộ nút, cuộn vào giữa vùng nhìn thấy và xác nhận hit test trước khi bấm.
- Chạy cùng tình huống ở hai kích thước 800×600 và 430×932; giữ nguyên kiểm tra tên người dùng không bị ghi đè và không lưu tự động.
- Không tắt cảnh báo bấm trượt, không bỏ bài test hoặc hạ điều kiện kiểm tra.
- Giữ đầy đủ chức năng của 1.1.0; giữ cơ chế kiểm tra/rollback và dữ liệu cũ.
- Log người dùng xác nhận analyzer 1.1.0 sạch, 28 test đạt, một widget test lỗi thao tác cuộn/bấm và source đã khôi phục về 1.0.3. Chưa chạy Flutter tests 1.1.1 tại môi trường đóng gói; updater sẽ chạy đủ 30 test trên laptop.

# 1.1.0

- AI hỗ trợ tên/ngày/tổng tiền hóa đơn khó, có đoạn trích; xác thực căn cứ và cho phép chọn từng trường trước khi áp dụng, không tự lưu.
- AI nhận xét tuần/tháng từ số liệu tổng hợp. Phép tính do Dart/Node thực hiện; phản hồi chỉ chọn fact ID và lời gợi ý.
- Thiết kế lại tổng quan, lịch sử, thống kê và cài đặt theo Material 3; bảng tổng tháng màu chuyển sắc, thẻ số liệu, trạng thái trống/lỗi và sáng/tối.
- Thống kê tháng, điều hướng kỳ, số ngày so sánh rõ ràng, không tính khoản tương lai vào chi tiêu thực tế.
- Mục tiêu chi tháng, tìm kiếm không dấu, lọc khoảng ngày/danh mục, sắp xếp tiền/ngày, xuất CSV danh sách đã lọc.
- Phóng to ảnh, chỉnh OCR/điền trường thiếu, chỉ báo dữ liệu thiếu, cảnh báo khoản chi tương tự.
- Parser không đổi tổng tiền âm thành chi tiêu dương.
- Giữ DB version/application ID, dữ liệu điện thoại và quy trình cập nhật ZIP + hai PowerShell.
- 22 test Node giả lập đạt; kiểm tra Dart nghiệp vụ độc lập đạt; 29 test Flutter được cung cấp để updater chạy trên máy người dùng. Chưa xác nhận Flutter analyze/test/build/giao diện thật cho bản mới trong môi trường đóng gói.

# 1.0.3

- Quy trình cập nhật bằng một lệnh PowerShell, tự tìm ZIP mới nhất trong Downloads theo phiên bản.
- Thay toàn bộ tệp mã nguồn thuộc gói; sao lưu và gỡ tệp cũ đã bị loại khỏi manifest phiên bản mới.
- Giữ tệp riêng không do gói quản lý, khóa ký, cấu hình, tiện ích Manager đã cài và dữ liệu điện thoại.
- Chặn cập nhật khi app build hoặc Node AI đang dùng dự án.
- Bỏ các dòng giá trị XML không cần thiết khỏi log cấu hình Android.
- Không thêm chức năng Flutter mới; tiếp tục bao gồm các bản sửa import và UTF-8.

# 1.0.2

- Phản hồi JSON giả lập của test AI dùng bytes UTF-8 và Content-Type có charset=utf-8.
- Kiểm tra cả danh mục và giải thích tiếng Việt, không bỏ kiểm thử hoặc giảm điều kiện nghiệm thu.
- Không thay cấu trúc dữ liệu, khóa ký hoặc application ID.

# 1.0.1

- Bỏ import cross_file dư trong màn hình sao lưu; dùng XFile được share_plus xuất sẵn.
- Giữ kiểm tra analyzer nghiêm ngặt và cơ chế sao lưu/khôi phục source.
- Không thay cấu trúc dữ liệu, application ID hoặc khóa ký.

# 1.0.0

- Thêm gợi ý danh mục Gemini, hộp đồng ý gửi nội dung và bước áp dụng chủ động.
- AI server giữ key trên laptop; USB loopback, mã ghép nối, giới hạn yêu cầu, thời gian chờ và kiểm tra JSON.
- Thêm backup/restore khoản chi cùng ảnh; giữ dữ liệu debug khi chuyển release ký riêng.
- Khôi phục ảnh chọn khi Activity Android bị hủy; giảm tràn bố cục khoản tiền dài.
- Sửa DropdownButtonFormField initialValue theo Flutter mới.
- Start-App tự chọn ZIP mới nhất trong Downloads/thư mục updates theo nội dung VERSION, cất ZIP đã xử lý.
- Cập nhật có VERSION + SHA-256 + sao lưu source + rollback khi kiểm tra thất bại.
- Thêm script chạy, build release, chụp bằng chứng, đóng gói source, CI và bộ hồ sơ.

# 0.1.0

- Luồng ML Kit → Regex → Review → Provider/SQLite → CustomPainter.
- Bản đầu đã được người dùng build/chạy và xác nhận chức năng cơ bản.
