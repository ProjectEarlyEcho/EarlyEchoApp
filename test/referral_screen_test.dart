import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/referral/referral_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('referral screen renders its placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: EarlyEchoTheme.lightTheme,
          home: const ReferralScreen(),
        ),
      ),
    );

    expect(find.text('रेफरल'), findsOneWidget);
    expect(find.text('DEIC रेफरल पत्र'), findsOneWidget);
    expect(find.textContaining('WhatsApp'), findsOneWidget);
    expect(find.text('होम पर लौटें'), findsOneWidget);
  });
}
