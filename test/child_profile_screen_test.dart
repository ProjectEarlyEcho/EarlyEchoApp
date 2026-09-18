import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/child_profile/child_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('child profile screen renders its placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EarlyEchoTheme.lightTheme,
        home: const ChildProfileScreen(),
      ),
    );

    expect(find.text('बच्चे की जानकारी'), findsOneWidget);
    expect(find.text('बच्चे का विवरण'), findsOneWidget);
    expect(find.textContaining('उम्र महीनों में (12–60)'), findsOneWidget);
    expect(find.text('प्रश्नावली की ओर बढ़ें'), findsOneWidget);
  });
}
