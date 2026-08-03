$ErrorActionPreference = "Stop"
flutter create --platforms=android .
flutter pub get
Write-Host "Hoàn tất. Chạy máy ảo Android:"
Write-Host "flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5180"
