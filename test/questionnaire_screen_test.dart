import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/questionnaire/questionnaire_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('questionnaire screen renders its placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EarlyEchoTheme.lightTheme,
        home: const QuestionnaireScreen(),
      ),
    );

    expect(find.text('प्रश्नावली'), findsOneWidget);
    expect(find.text('वैकल्पिक सवाल'), findsOneWidget);
    expect(find.textContaining('CDC विकास मील के पत्थरों'), findsOneWidget);
    expect(find.text('सहमति की ओर बढ़ें'), findsOneWidget);
  });
}
