import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/processing/processing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('processing screen renders its placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EarlyEchoTheme.lightTheme,
        home: const ProcessingScreen(),
      ),
    );

    expect(find.text('विश्लेषण'), findsOneWidget);
    expect(find.text('ऑडियो विश्लेषण'), findsOneWidget);
    expect(find.textContaining('फ़ोन से बाहर'), findsOneWidget);
    expect(find.text('VTTL'), findsOneWidget);
    expect(find.text('CVR'), findsOneWidget);
    expect(find.text('PFV'), findsOneWidget);
    expect(find.text('परिणाम देखें'), findsOneWidget);
  });
}
