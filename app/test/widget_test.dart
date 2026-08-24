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

  testWidgets('Family dashboard matches the shared-account mobile contract', (
    tester,
  ) async {
    await pumpAt(tester, const Size(393, 852));

    expect(find.text('Góc người thân'), findsOneWidget);
    expect(find.text('Theo dõi sức khỏe'), findsOneWidget);
    expect(find.text('Quản lý thuốc'), findsOneWidget);
    expect(find.text('Tin nhắn'), findsOneWidget);
    expect(find.text('Danh bạ'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets('The caregiver dashboard remains usable on a small phone', (
    tester,
  ) async {
    await pumpAt(tester, const Size(320, 640));

    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets(
    'Settings, role selection and messages are reachable from the nav',
    (tester) async {
      await pumpAt(tester, const Size(393, 852));

      await tester.tap(find.byIcon(Icons.tune_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Tài khoản, trợ lý AI và thiết bị'), findsOneWidget);

      await tester.tap(find.text('Vai trò của thiết bị'));
      await tester.pumpAndSettle();
      expect(find.text('Người thân'), findsWidgets);
      expect(find.text('Người cao tuổi'), findsOneWidget);

      await tester.tap(find.text('Người thân').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chat_bubble_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Chưa kết nối tin nhắn'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    },
  );
}
