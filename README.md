# Quỹ Nhà Mình 2.0

Ứng dụng quản lý quỹ gia đình gồm backend ASP.NET Core 10 và Flutter Material 3. Hỗ trợ nhiều quỹ, tài khoản tiền, phân quyền, ngân sách, nhắc việc, Gemini OCR, báo cáo Excel/PDF, sao lưu, thùng rác và đồng bộ nhiều thiết bị.

## Chạy thử trên Windows

Mở hai cửa sổ Terminal trong VS Code.

Backend:

```powershell
cd D:\quynhaminh\backend\QuyNhaMinh.Api
$env:GEMINI_API_KEY="khóa-Gemini-của-bạn"
$env:JWT_KEY="chuỗi-ngẫu-nhiên-tối-thiểu-32-ký-tự"
dotnet run
```

Swagger: `http://127.0.0.1:5180/swagger`. Đăng ký/đăng nhập, sao chép token rồi bấm **Authorize** và nhập `Bearer TOKEN`.

Flutter Web:

```powershell
cd D:\quynhaminh\mobile
D:\flutter\bin\flutter pub get
D:\flutter\bin\flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5180
```

Android Emulator dùng `http://10.0.2.2:5180`; điện thoại thật dùng IP LAN của máy tính. Không chạy `flutter run` ở `C:\Users\Admin`, vì Flutter cần thư mục chứa `pubspec.yaml`.

## Supabase

1. Tạo project tại Supabase, vào **Project Settings → Database** và sao chép connection string PostgreSQL.
2. Tạo bucket Storage tên `receipts`, đặt private. Backend dùng service-role để tải ảnh; tuyệt đối không đưa service-role vào Flutter.
3. Đặt biến môi trường backend:

```text
DATABASE_URL=postgresql://postgres.[project-ref]:PASSWORD@[host]:6543/postgres?sslmode=require
SUPABASE_URL=https://PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...
SUPABASE_STORAGE_BUCKET=receipts
JWT_KEY=chuỗi-ngẫu-nhiên-dài
GEMINI_API_KEY=...
```

Backend tự tạo schema lần đầu. Với môi trường sản xuất, chỉ cấp `SUPABASE_SERVICE_ROLE_KEY` cho Render.

## Render

1. Đẩy mã nguồn lên GitHub riêng tư.
2. Render → New → Blueprint và chọn repository; `render.yaml` sẽ tạo Web Service.
3. Khai báo các biến bí mật ở trên trong Render. `DATABASE_URL` lấy từ Supabase.
4. Sau khi deploy, kiểm tra `https://TEN-DICH-VU.onrender.com/health` và `/swagger`.
5. Build APK lại với URL thật:

```powershell
cd D:\quynhaminh\mobile
D:\flutter\bin\flutter build apk --release --dart-define=API_BASE_URL=https://TEN-DICH-VU.onrender.com
```

## Kiểm thử

```powershell
cd D:\quynhaminh\backend\QuyNhaMinh.Api
dotnet build

cd D:\quynhaminh\mobile
D:\flutter\bin\flutter analyze --no-fatal-infos --no-fatal-warnings
D:\flutter\bin\flutter test
D:\flutter\bin\flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:5180
```

## Bảo mật và sao lưu

- Gemini key, JWT key và Supabase service-role chỉ ở backend.
- Mật khẩu băm PBKDF2; API dùng JWT và kiểm tra quyền trên từng quỹ.
- Giao dịch xóa được đưa vào thùng rác trước khi xóa vĩnh viễn.
- Sao lưu JSON, Excel và PDF được bảo vệ bằng JWT.
- Bản APK hiện tạo bằng khóa debug mặc định của Flutter nếu chưa cấu hình signing riêng. Trước khi phát hành Google Play, tạo keystore riêng và cấu hình `key.properties`.
