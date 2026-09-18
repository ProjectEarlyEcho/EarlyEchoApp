import 'package:earlyecho/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders the EarlyEcho home screen', (tester) async {
    await tester.pumpWidget(const EarlyEchoApp());

    expect(find.text('EarlyEcho'), findsWidgets);
    expect(find.text('Acoustic biomarker screening'), findsOneWidget);
  });
}
