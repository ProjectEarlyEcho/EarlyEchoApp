import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/history/result_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('result history screen renders its placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EarlyEchoTheme.lightTheme,
        home: const ResultHistoryScreen(),
      ),
    );

    expect(find.text('पुरानी जाँचें'), findsOneWidget);
    expect(find.text('सहेजी गई जाँचें'), findsOneWidget);
    expect(find.textContaining('जोखिम श्रेणी'), findsOneWidget);
    expect(find.textContaining('ऑडियो नहीं'), findsOneWidget);
  });
}
