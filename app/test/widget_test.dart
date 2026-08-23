import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:divie_app/main.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(const DivieApp());
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byIcon(Icons.family_restroom_rounded).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.family_restroom_rounded));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  tearDown(() async {
    // Keep each test isolated from the previous viewport.
  });

  testWidgets('Home matches the mobile content contract', (tester) async {
    await pumpAt(tester, const Size(393, 852));

    expect(find.text('Tin nhắn'), findsOneWidget);
    expect(find.text('Danh bạ'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.textContaining('Sức khỏe'), findsWidgets);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets('The shared shell remains usable on a small phone', (
    tester,
  ) async {
    await pumpAt(tester, const Size(320, 640));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Khẩn cấp'), findsOneWidget);
  });

  testWidgets('Settings, contacts and messages are reachable from the nav', (
    tester,
  ) async {
    await pumpAt(tester, const Size(393, 852));

    await tester.tap(find.byIcon(Icons.settings_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản, trợ lý AI và thiết bị'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.contacts_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Chưa kết nối danh bạ'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat_bubble_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Chưa kết nối tin nhắn'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
