import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen renders its placeholder content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: EarlyEchoTheme.lightTheme,
          home: const HomeScreen(),
        ),
      ),
    );

    expect(find.text('EarlyEcho'), findsOneWidget);
    expect(find.text('नमस्ते!'), findsOneWidget);
    expect(find.text('ध्वनि-आधारित विकास जाँच'), findsOneWidget);
    expect(find.text('निजता पहले'), findsOneWidget);
    expect(find.text('नई स्क्रीनिंग शुरू करें'), findsOneWidget);
    expect(find.text('पुरानी जाँचें देखें'), findsOneWidget);
    expect(find.text('Start Gemini Live (ESP32 speaker)'), findsOneWidget);
  });
}
