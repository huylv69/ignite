# Ignite — Codemagic CI/CD Admin 🚀

**Ignite** là ứng dụng quản trị các pipeline CI/CD trên **Codemagic**: xem app, theo dõi build, đọc log từng bước, kích hoạt build, dọn cache và quản lý biến môi trường — không phải mở web console.

---

## ✨ Tính năng

### 🔐 Đăng nhập & nhiều tài khoản
- Đăng nhập bằng **Codemagic API Token**, lưu cục bộ trong SharedPreferences.
- **Nhiều tài khoản**: thêm, đổi qua lại, đổi tên, gỡ — ngay trên thanh tiêu đề.
- Khoá app bằng **sinh trắc học** khi mở lại (bỏ qua trên web).

### 📱 Danh sách ứng dụng
- Liệt kê toàn bộ app trong tài khoản; **thêm app** từ URL repo public, **gỡ app** (giữ nhấn, phải gõ tên để xác nhận).
- **Tìm kiếm** theo tên app hoặc URL repository.
- Mỗi thẻ hiện **trạng thái build gần nhất** kèm thời gian, lấy bằng một request duy nhất cho cả danh sách.

### 📊 Build & thống kê
- **Toàn bộ lịch sử build** theo từng app (API v3, phân trang cursor) — không còn cụt ở vài build gần nhất.
- **Lọc** theo trạng thái (đang chạy / passed / failed / canceled) và branch, xử lý phía server.
- Hiện tác giả commit, **labels**, số PR, release notes; bấm mở commit trên GitHub.
- Tự động poll mỗi 12 giây khi có build đang chạy.
- Biểu đồ phân bố kết quả và tỉ lệ thành công (`fl_chart`).
- **Huỷ build** đang chạy.

### 🔔 Thông báo build xong
- Khi một build đang chạy chuyển sang passed / failed / canceled, app bắn **thông báo local** (Android/iOS) và banner trong app.
- Không cần server: Codemagic không có webhook chiều ra, nên app poll 20 giây một lần khi đang mở.

### 📜 Log từng bước
- Xem danh sách các bước của một build kèm trạng thái và thời lượng.
- Mở **log thô** của từng bước, chọn được chữ, copy toàn bộ.

### 📦 Artifact
- Tải artifact về máy kèm thanh tiến độ, rồi chia sẻ qua share sheet.
- Tạo **link công khai có hạn 24 giờ** để gửi cho người không có quyền truy cập Codemagic.

### ⚡ Kích hoạt build
- Chọn workflow từ `codemagic.yaml` hoặc từ workflow editor.
- Chạy theo **branch hoặc tag**, gắn **labels** để lọc lại sau.
- Chọn **loại máy** (`mac_mini_m1`, `mac_mini_m2`, `linux_x2`, `windows_x2`) hoặc để workflow tự quyết.
- Truyền biến môi trường ngay lúc kích hoạt.

### 🧹 Cache & biến môi trường
- Xem cache theo workflow kèm dung lượng và lần dùng cuối; xoá từng cái hoặc xoá sạch.
- CRUD biến môi trường theo nhóm; giá trị `secure` luôn ở dạng che.

### 🎨 Giao diện
- Dark theme Material 3, tông cam.
- **Shimmer skeleton** khi tải, chuyển cảnh bằng `flutter_animate`.

---

## 🛠 Tech stack

- **State**: [Riverpod](https://riverpod.dev/)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **Networking**: [http](https://pub.dev/packages/http) — gọi thẳng Codemagic REST API
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Animation**: [flutter_animate](https://pub.dev/packages/flutter_animate), [shimmer](https://pub.dev/packages/shimmer)
- **Lưu trữ**: [shared_preferences](https://pub.dev/packages/shared_preferences)
- **Bảo mật**: [local_auth](https://pub.dev/packages/local_auth)

---

## 🚀 Bắt đầu

Cần Flutter SDK `^3.7.0` và một Codemagic API token
(*User settings → Integrations → Codemagic API*).

```bash
flutter pub get
flutter run
```

Nền tảng đã build được: Android, iOS, Linux, Web.

### Kiểm tra

```bash
flutter analyze   # phải ra "No issues found!"
flutter test
```

---

## 📄 Giấy phép

[MIT](LICENSE)
