import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings screen renders its placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EarlyEchoTheme.lightTheme,
        home: const SettingsScreen(),
      ),
    );

    expect(find.text('सेटिंग्स'), findsOneWidget);
    expect(find.text('कार्यकर्ता व डिवाइस सेटिंग्स'), findsOneWidget);
    expect(find.textContaining('डिफ़ॉल्ट आंगनबाड़ी आईडी'), findsOneWidget);
  });
}
