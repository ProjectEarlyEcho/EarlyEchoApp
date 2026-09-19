import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/providers/auth_provider.dart';
import 'package:earlyecho/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ConfiguredSignedOutAuthNotifier extends AppAuthNotifier {
  _ConfiguredSignedOutAuthNotifier() : super(null) {
    state = const AppAuthState(configured: true);
  }
}

void main() {
  testWidgets('settings screen renders its placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appAuthProvider.overrideWith(
            (ref) => _ConfiguredSignedOutAuthNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: EarlyEchoTheme.lightTheme,
          home: const SettingsScreen(),
        ),
      ),
    );

    expect(find.text('सेटिंग्स'), findsOneWidget);
    expect(find.text('कार्यकर्ता व डिवाइस सेटिंग्स'), findsOneWidget);
    expect(find.textContaining('डिफ़ॉल्ट आंगनबाड़ी आईडी'), findsOneWidget);
    expect(find.text('खाता'), findsOneWidget);
    expect(find.text('साइन इन नहीं है'), findsOneWidget);
    expect(find.text('साइन इन करें'), findsOneWidget);
  });
}
