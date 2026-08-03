#!/usr/bin/env bash
set -e
flutter create --platforms=android .
flutter pub get
echo 'Hoàn tất. Chạy: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5180'
