import 'package:earlyecho/main.dart';
import 'package:earlyecho/presentation/screens/home/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots into the routed home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EarlyEchoApp()));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('EarlyEcho'), findsOneWidget);
    expect(find.text('नमस्ते!'), findsOneWidget);
    expect(find.text('नई स्क्रीनिंग शुरू करें'), findsOneWidget);
  });
}
