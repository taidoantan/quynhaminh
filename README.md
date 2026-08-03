# Quỹ Nhà Mình

Bộ mã nguồn MVP quản lý thu chi gia đình, dùng nhiều điện thoại, gồm:

- `backend/QuyNhaMinh.Api`: ASP.NET Core Web API + SQLite + JWT + OpenAI quét hóa đơn.
- `mobile`: Flutter Android app.

## Chạy backend

```bash
cd backend/QuyNhaMinh.Api
cp .env.example .env
# đặt OPENAI_API_KEY trong biến môi trường hoặc .env theo công cụ bạn dùng
dotnet restore
dotnet run
```

API mặc định: `http://localhost:5180`.

## Chạy Flutter

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5180
```

Với điện thoại thật, thay `10.0.2.2` bằng IP LAN của máy chạy API.

## Tài khoản thử

Đăng ký tài khoản mới trong ứng dụng. Người đầu tiên tạo quỹ, người khác nhập mã mời để tham gia.

## Bảo mật

Không đưa `OPENAI_API_KEY` vào Flutter hoặc commit lên Git. Khóa chỉ nằm ở backend.

## Khởi tạo thư mục Android lần đầu

Mã nguồn Flutter được giữ gọn, vì vậy chạy một trong hai lệnh sau trong thư mục `mobile`:

Windows:

```powershell
.\bootstrap_windows.ps1
```

Linux/macOS:

```bash
./bootstrap_linux.sh
```

Sau khi `flutter create` hoàn tất, thay icon launcher bằng `assets/app_logo.png` hoặc dùng package `flutter_launcher_icons`.

## Build APK

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://ten-mien-api-cua-ban
```

APK nằm tại `build/app/outputs/flutter-apk/app-release.apk`.
