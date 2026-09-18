import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/consent/consent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('consent screen renders its placeholder content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EarlyEchoTheme.lightTheme,
        home: const ConsentScreen(),
      ),
    );

    expect(find.text('सहमति'), findsOneWidget);
    expect(find.text('अभिभावक की सहमति'), findsOneWidget);
    expect(find.textContaining('हिंदी में सहमति का वाक्य'), findsOneWidget);
    expect(find.text('अभिभावक ने सहमति दी'), findsOneWidget);
  });
}
