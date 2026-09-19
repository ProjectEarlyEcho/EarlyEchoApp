import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/data/models/biomarker_result.dart';
import 'package:earlyecho/data/models/session_features.dart';
import 'package:earlyecho/domain/milestone_engine.dart';
import 'package:earlyecho/presentation/providers/session_provider.dart';
import 'package:earlyecho/presentation/screens/result/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter testRouter() => GoRouter(
    initialLocation: '/result',
    routes: [GoRoute(path: '/result', builder: (_, _) => const ResultScreen())],
  );

  ProviderContainer containerWith(
    BiomarkerResult result, {
    MilestoneSummary? questionnaire,
  }) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    if (questionnaire != null) {
      container
          .read(sessionProvider.notifier)
          .setQuestionnaire(const {}, questionnaire);
    }
    const features = SessionFeatures(
      vttlMs: 1450,
      pfvStd: 20.0,
      cvrRatio: 0.05,
      childAgeMonths: 30,
    );
    container
        .read(sessionProvider.notifier)
        .recordAnalysisResult(
          features: features,
          result: result,
          rawResponse: const {'audio_source_used': 'UNPROCESSED'},
        );
    return container;
  }

  testWidgets('empty state when no analysis has run', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: EarlyEchoTheme.lightTheme,
          routerConfig: testRouter(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('कोई परिणाम उपलब्ध नहीं'), findsOneWidget);
  });

  testWidgets('RED result shows banner, flagged chips and referral CTA', (
    tester,
  ) async {
    const result = BiomarkerResult(
      riskLevel: RiskLevel.red,
      vttlFlagged: true,
      pfvFlagged: false,
      cvrFlagged: true,
      hindiExplanation:
          'इस बच्चे के लिए शीघ्र DEIC मूल्यांकन की सलाह दी जाती है।',
    );
    final container = containerWith(result);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: EarlyEchoTheme.lightTheme,
          routerConfig: testRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('लाल — DEIC रेफरल की सलाह'), findsOneWidget);
    expect(find.text('1450 ms'), findsOneWidget);
    expect(find.text('0.050'), findsOneWidget);
    expect(find.text('20.0 ST'), findsOneWidget);
    expect(find.text('संयुक्त स्क्रीनिंग सारांश'), findsOneWidget);
    expect(
      find.bySemanticsLabel('वीडियो गुणवत्ता: वीडियो गुणवत्ता उपलब्ध नहीं'),
      findsOneWidget,
    );
    expect(find.text('रेफरल बनाएँ'), findsOneWidget);
  });

  testWidgets(
    'questionnaire concerns elevate GREEN audio to clinician review',
    (tester) async {
      const audioResult = BiomarkerResult(
        riskLevel: RiskLevel.green,
        vttlFlagged: false,
        pfvFlagged: false,
        cvrFlagged: false,
        hindiExplanation: '',
      );
      const questionnaire = MilestoneSummary(
        totalApplicable: 4,
        answeredYes: 2,
        answeredNo: 2,
        status: MilestoneStatus.warning,
      );
      final container = containerWith(
        audioResult,
        questionnaire: questionnaire,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: EarlyEchoTheme.lightTheme,
            routerConfig: testRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('पीला — एक चिंता का संकेत'), findsOneWidget);
      expect(
        find.bySemanticsLabel('प्रश्नावली: 2 विकास संबंधी चिंताएँ दर्ज'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('अगला कदम: चिकित्सकीय समीक्षा की सलाह'),
        findsOneWidget,
      );
      expect(find.text('रेफरल बनाएँ'), findsNothing);
    },
  );

  testWidgets('incomplete analysis shows retry, never a verdict', (
    tester,
  ) async {
    const result = BiomarkerResult(
      riskLevel: RiskLevel.yellow,
      vttlFlagged: false,
      pfvFlagged: false,
      cvrFlagged: false,
      hindiExplanation: 'ऑडियो विश्लेषण अधूरा रहा।',
      qualityReasons: [
        'Audio analysis could not be completed; please repeat the recording.',
      ],
      incomplete: true,
    );
    final container = containerWith(result);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: EarlyEchoTheme.lightTheme,
          routerConfig: testRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('विश्लेषण अधूरा रहा'), findsOneWidget);
    expect(find.text('दोबारा स्क्रीनिंग करें'), findsOneWidget);
    expect(find.text('रेफरल बनाएँ'), findsNothing);
  });
}
