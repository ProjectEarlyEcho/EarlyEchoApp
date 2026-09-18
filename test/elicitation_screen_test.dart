import 'package:earlyecho/core/constants.dart';
import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/elicitation/elicitation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('elicitation screen renders its placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EarlyEchoTheme.lightTheme,
        home: const ElicitationScreen(),
      ),
    );

    expect(find.text('ध्वनि प्रेरण'), findsOneWidget);
    expect(find.text('तीन क्रमिक गतिविधियाँ'), findsOneWidget);
    expect(find.text('रैटल'), findsOneWidget);
    expect(find.text('खिलौना छुपाना'), findsOneWidget);
    expect(find.text('अनुकरण'), findsOneWidget);
    expect(
      find.textContaining(
        EarlyEchoConstants.elicitationTotalSeconds.toString(),
      ),
      findsWidgets,
    );
    expect(
      find.text('${EarlyEchoConstants.toyHideProtocolSeconds} सेकंड'),
      findsOneWidget,
    );
    expect(find.text('रिकॉर्डिंग शुरू करें'), findsOneWidget);
  });
}
