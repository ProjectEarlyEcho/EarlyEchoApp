import 'package:earlyecho/core/routes.dart';
import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/result/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'pipeline_test_helpers.dart';

void main() {
  testWidgets('processing screen runs analysis and lands on result', (
    tester,
  ) async {
    installMockPipelineChannel(runPipelineResponse: incompletePipelineResponse);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: EarlyEchoTheme.lightTheme,
          routerConfig: GoRouter(
            initialLocation: '/processing',
            routes: appRoutes,
          ),
        ),
      ),
    );
    await tester.pump();

    // Mid-analysis UI: spinner plus the biomarker pills.
    expect(find.text('विश्लेषण'), findsOneWidget);
    expect(find.text('ऑडियो विश्लेषण'), findsOneWidget);
    expect(find.textContaining('फ़ोन से बाहर'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The mocked INCOMPLETE response routes to the retry prompt.
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('विश्लेषण अधूरा रहा'), findsOneWidget);
    expect(find.text('दोबारा स्क्रीनिंग करें'), findsOneWidget);
  });
}
