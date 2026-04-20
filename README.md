# Ignite — Codemagic CI/CD Admin 🚀

**Ignite** là một ứng dụng quản trị (Admin Dashboard) mạnh mẽ và hiện đại được thiết kế dành riêng cho việc quản lý các quy trình CI/CD trên nền tảng **Codemagic**. Với giao diện tối giản, hiệu ứng Glassmorphism sang trọng và khả năng tương tác thời gian thực, Ignite giúp các nhà phát triển theo dõi và điều hành hệ thống build một cách mượt mà nhất.

---

## ✨ Các tính năng nổi bật (Key Features)

### 🔐 Quản lý Đăng nhập Bảo mật
- Hỗ trợ đăng nhập nhanh chóng và bảo mật thông qua **Codemagic API Token**.
- Lưu trữ token an toàn và quản lý phiên làm việc thông minh.

### 📱 Danh sách Ứng dụng Trực quan
- Hiển thị toàn bộ danh sách các project được cấu hình trên Codemagic.
- Phân loại và tìm kiếm ứng dụng dễ dàng.
- Theo dõi trạng thái build mới nhất ngay tại màn hình chính.

### 📊 Dashboard Chi tiết & Số liệu
- Xem lịch sử build chi tiết cho từng ứng dụng.
- Biểu đồ thống kê hiệu suất build, thời gian build trung bình (sử dụng `fl_chart`).
- Trạng thái build được cập nhật theo thời gian thực (Success, Failed, Building...).

### ⚡ Kích hoạt Build Linh hoạt (YAML Triggering)
- Hỗ trợ kích hoạt build thủ công với các cấu hình workflow tùy chỉnh.
- Giao diện trực quan để chọn branch và workflow từ file `codemagic.yaml`.

### 🎨 Trải nghiệm Người dùng Đẳng cấp
- **Giao diện Modern UI**: Thiết kế theo phong cách Glassmorphism với các thành phần trong suốt và đổ bóng mềm mại.
- **Hiệu ứng mượt mà**: Tích hợp `flutter_animate` cho các hiệu ứng chuyển cảnh và loading vô cùng chuyên nghiệp.
- **Chế độ tối ưu**: Hỗ trợ font chữ hiện đại (Google Fonts) và loading shimmer cho trải nghiệm không bị gián đoạn.

---

## 🛠 Công nghệ sử dụng (Tech Stack)

Dự án được xây dựng trên nền tảng **Flutter** với các thư viện hàng đầu:

- **State Management**: [Riverpod](https://riverpod.dev/) — Đảm bảo quản lý trạng thái ứng dụng một cách nhất quán và dễ mở rộng.
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router) — Điều hướng mạnh mẽ và hỗ trợ deep linking.
- **Networking**: [http](https://pub.dev/packages/http) — Tương tác trực tiếp với Codemagic REST API.
- **Data Visualization**: [fl_chart](https://pub.dev/packages/fl_chart) — Tạo các biểu đồ thống kê sinh động.
- **Animations**: [flutter_animate](https://pub.dev/packages/flutter_animate) — Mang lại sự sống động cho giao diện.
- **Persistence**: [shared_preferences](https://pub.dev/packages/shared_preferences) — Lưu trữ cài đặt và token người dùng cục bộ.

---

## 🚀 Bắt đầu

### Điều kiện tiên quyết
- Flutter SDK (^3.7.0)
- Một tài khoản Codemagic và API Token hợp lệ.

### Cài đặt
1. Clone repository:
   ```bash
   git clone <your-repo-url>
   ```
2. Cài đặt dependencies:
   ```bash
   flutter pub get
   ```
3. Chạy ứng dụng:
   ```bash
   flutter run
   ```

---

## 📸 Ảnh chụp màn hình (Screenshots)
*(Vui lòng thêm ảnh chụp màn hình thực tế của bạn tại đây)*

---

## 📄 Giấy phép
Dự án được phát hành dưới giấy phép [MIT](LICENSE).

---
*Phát triển bởi đội ngũ đam mê CI/CD.*
