import 'package:earlyecho/presentation/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('parent and care-worker access choices are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Care worker'), findsOneWidget);
    expect(find.text('Create a parent account'), findsOneWidget);

    await tester.tap(find.text('Care worker'));
    await tester.pumpAndSettle();

    expect(
      find.text('Care-worker accounts are provisioned by your organisation.'),
      findsOneWidget,
    );
    expect(find.text('Create a parent account'), findsNothing);
  });
}
