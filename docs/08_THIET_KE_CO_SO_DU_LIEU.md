# Cơ sở dữ liệu và thiết kế

| Bảng expenses | Kiểu | Ý nghĩa |
|---|---|---|
| id | INTEGER PRIMARY KEY AUTOINCREMENT | Định danh khoản chi |
| merchant | TEXT NOT NULL | Cửa hàng hoặc tên khoản chi |
| amount | INTEGER CHECK > 0 | Số tiền VND nguyên |
| date | TEXT ISO-8601 | Ngày chi tiêu theo lịch địa phương |
| category | TEXT NOT NULL | Một trong sáu danh mục |
| note | TEXT | Ghi chú |
| image_path | TEXT nullable | Đường dẫn ảnh trong vùng documents riêng của app |
| raw_text | TEXT | Văn bản OCR để đối chiếu |

`restored_items(origin TEXT, original_id INTEGER)` có khóa chính ghép để chống nhập lại cùng mục backup.
Khi import, tạo ảnh mới trong documents, ghi khoản chi và dấu import trong transaction;
rollback lỗi sẽ dọn ảnh mới đã tạo. Không dùng đường dẫn trong JSON để truy cập file tùy ý.

Danh mục cố định: Ăn uống, Di chuyển, Mua sắm, Học tập, Sinh hoạt, Khác.
SQL dùng tham số whereArgs thay vì nối trực tiếp input vào truy vấn.
Không có backend tài khoản và không dùng PostgreSQL ở đề tài này.
Sơ đồ draw.io: architecture.drawio; luồng chi tiết nằm README và tài liệu bảo vệ.
