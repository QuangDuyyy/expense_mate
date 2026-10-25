# Nghiệm thu bản 1.0.0 trên máy chủ dự án

Ghi PASS/FAIL, ngày và ảnh/log thật cho từng mục. Người dùng đã xác nhận phần cơ bản ở 0.1;
đây là đợt kiểm tra bản cập nhật, không suy diễn kết quả từ phiên bản cũ.

| Mã | Thao tác | Kết quả mong đợi | Kết quả thực tế |
|---|---|---|---|
| U01 | Cập nhật lên 1.0, mở cùng debug app | Dữ liệu/ảnh cũ còn, version mới | Chờ chạy |
| C01 | Nhập 65000 ngày hiện tại, Ăn uống | Tổng +65000, danh sách/biểu đồ thay đổi | Chờ chạy |
| C02 | Sửa 65000 → 75000 | Bản ghi giữ ID; tổng tăng thêm 10000 | Chờ chạy |
| C03 | Đóng/mở app | Dữ liệu/ảnh và theme còn | Chờ chạy |
| O01 | Camera hóa đơn thật | Có text; tên/ngày/tổng được gợi ý | Chờ chạy |
| O02 | Ảnh mờ/trống hoặc thiếu ngày | Không crash, cho nhập/sửa tay | Chờ chạy |
| O03 | Hóa đơn có subtotal/cash/change | Đối chiếu total đúng, sai thì sửa | Chờ chạy |
| O04 | Hủy camera/không cấp quyền | Trở về, app vẫn dùng được | Chờ chạy |
| G01 | Chuyển tuần không có chi | Không chia 0, hiển thị trống hợp lý | Chờ chạy |
| G02 | Danh mục khác nhau | Donut đúng tổng, cột đúng ngày, có hoạt ảnh | Chờ chạy |
| A01 | Đồng ý gửi và AI thành công | Gợi ý + giải thích, cần bấm Áp dụng | Chờ API thật |
| A02 | Hủy hộp đồng ý | Không gửi request, danh mục không đổi | Chờ chạy |
| A03 | Tắt server/rút USB/sai token | Báo lỗi rõ, vẫn chọn/lưu thủ công | Chờ chạy |
| A04 | Khóa lỗi/hết quota | Không giả thành công, không lộ khóa | Chờ API thật hoặc mock |
| B01 | Xuất backup, nhập vào release riêng | Khoản chi/ảnh khớp bản gốc | Chờ chạy |
| B02 | Nhập lại đúng file backup | Không thêm trùng | Chờ chạy |
| B03 | Chọn JSON sai hoặc file quá lớn | Từ chối, dữ liệu hiện tại còn | Chờ chạy |
| R01 | Build-Release.cmd | APK ký riêng; cài song song debug | Chờ Windows SDK |
| R02 | Release không có server | OCR, CRUD, thống kê vẫn hoạt động | Chờ chạy |

## Hồ sơ cần có

- Log analyze/test bản 1.0, 9 test Node giả lập và ít nhất một gợi ý Gemini thật.
- `Capture-Evidence.cmd`: light.png, dark.png, review.png, charts.png, ai.png.
- APK ký riêng + SHA-256, GitHub public + README và pubspec.lock, video 2–3 phút.
- Báo cáo 2–4 trang cập nhật ảnh và kết quả thật; kiểm tra mẫu trường/lớp nếu được cung cấp thêm.

Chỉ đánh dấu hoàn tất khi đã kiểm tra. Không gỡ app debug trước khi xác nhận backup release đầy đủ.
