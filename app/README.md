# divie_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# DiVie Flutter app

Ứng dụng Flutter dùng Supabase Auth và dữ liệu production của DiVie.

## Chạy bản development có dữ liệu thật

```powershell
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat run `
  --dart-define=SUPABASE_URL="<supabase-url>" `
  --dart-define=SUPABASE_ANON_KEY="<supabase-publishable-key>"
```

Không lưu URL/key vào source code hoặc Git. Bản phát hành phải truyền cấu hình qua `--dart-define`.

Khi không truyền hai biến Supabase, app vẫn mở được Home và các tính năng cục bộ, nhưng Chat và Danh bạ sẽ hiển thị trạng thái chưa kết nối; app không còn hiển thị dữ liệu giả.

Luồng đã kết nối:

- Đăng nhập thật bằng Supabase Auth.
- Danh bạ đọc từ `profiles` sau khi đăng nhập.
- Tin nhắn đọc/ghi qua `chat_rooms`, `chat_participants`, `chat_messages`.
- Tạo cuộc trò chuyện trực tiếp qua RPC `create_or_get_direct_chat`.

Migration quyền chat nằm tại `../backend-source/admin-api/db/migrations/002_chat_rls.sql`; các migration `003_enable_chat_participants_realtime.sql` và `004_allow_authenticated_profile_discovery_for_chat.sql` bổ sung realtime cho thành viên phòng và cho phép người dùng đã đăng nhập tìm nhau để bắt đầu chat. Cả ba migration đã được áp dụng cho project Supabase production đang liên kết với app.

Danh sách và hội thoại tự làm mới định kỳ; tin nhắn mới được tải lại trong vòng vài giây. Realtime hiện đã bật cho `profiles`, `chat_rooms`, `chat_participants` và `chat_messages`; polling vẫn được giữ làm phương án dự phòng khi thiết bị mất kết nối tạm thời.

Nếu tài khoản chưa có quyền RLS ở các bảng trên, ứng dụng sẽ hiện trạng thái lỗi và nút thử lại; không dùng dữ liệu giả khi đã bật production config.
