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

  testWidgets('Caregiver dashboard matches the mobile content contract', (
    tester,
  ) async {
    await pumpAt(tester, const Size(393, 852));

    expect(find.textContaining('Kết nối người thân'), findsWidgets);
    expect(find.text('Theo dõi sức khỏe'), findsOneWidget);
    expect(find.text('Quản lý thuốc'), findsOneWidget);
    expect(find.text('Tin nhắn'), findsOneWidget);
    expect(find.text('Người được chăm sóc'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets('The caregiver dashboard remains usable on a small phone', (
    tester,
  ) async {
    await pumpAt(tester, const Size(320, 640));

    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Người được chăm sóc'), findsOneWidget);
  });

  testWidgets(
    'Settings, care connections and messages are reachable from the nav',
    (tester) async {
      await pumpAt(tester, const Size(393, 852));

      await tester.tap(find.byIcon(Icons.tune_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Tài khoản, trợ lý AI và thiết bị'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.groups_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Người được chăm sóc'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chat_bubble_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Chưa kết nối tin nhắn'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    },
  );
}
