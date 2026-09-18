import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/result/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('result screen renders its placeholder content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: EarlyEchoTheme.lightTheme, home: const ResultScreen()),
    );

    expect(find.text('परिणाम'), findsOneWidget);
    expect(find.text('जोखिम वर्गीकरण'), findsOneWidget);
    expect(find.text('हरा — सामान्य विकास'), findsOneWidget);
    expect(find.text('पीला — एक संकेत'), findsOneWidget);
    expect(find.text('लाल — DEIC रेफरल'), findsOneWidget);
    expect(find.text('रेफरल देखें'), findsOneWidget);
  });
}
