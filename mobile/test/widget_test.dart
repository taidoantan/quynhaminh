import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quy_nha_minh/main.dart';

void main() {
  testWidgets('Ứng dụng khởi động với giao diện Material 3', (tester) async {
    await tester.pumpWidget(const QuyNhaMinhApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
