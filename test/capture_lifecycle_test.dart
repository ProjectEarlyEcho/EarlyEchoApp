import 'dart:io';

import 'package:earlyecho/core/l10n/app_strings.dart';
import 'package:earlyecho/core/routes.dart';
import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/data/local/database_helper.dart';
import 'package:earlyecho/data/repositories/session_repository.dart';
import 'package:earlyecho/domain/milestone_engine.dart';
import 'package:earlyecho/presentation/providers/locale_provider.dart';
import 'package:earlyecho/presentation/providers/session_provider.dart';
import 'package:earlyecho/presentation/providers/sync_provider.dart';
import 'package:earlyecho/presentation/screens/home/home_screen.dart';
import 'package:earlyecho/presentation/screens/questionnaire/questionnaire_screen.dart';
import 'package:earlyecho/presentation/screens/result/result_screen.dart';
import 'package:earlyecho/services/consent_audio_service.dart';
import 'package:earlyecho/services/elicitation_audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'pipeline_test_helpers.dart';

class _SilentConsentPlayer implements ConsentAudioPlayer {
  @override
  Future<void> play() async {}

  @override
  Future<void> stop() async {}
}

class _SilentElicitationPlayer implements ElicitationAudioPlayer {
  @override
  Future<void> playFor(String protocolKey) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  setUpAll(sqfliteFfiInit);

  for (final entry in ['system Back', 'AppBar Back', 'direct enrollment']) {
    testWidgets(
      '$entry then a new capture persists separate results and consent',
      (tester) async {
        installMockPipelineChannel(
          runPipelineResponse: completeRedPipelineResponse,
        );
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final helper = DatabaseHelper(
          factory: databaseFactoryFfiNoIsolate,
          databasePath: inMemoryDatabasePath,
        );
        await helper.database;
        addTearDown(helper.close);
        final repository = SessionRepository(helper: helper);
        final container = ProviderContainer(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(repository),
            consentAudioPlayerProvider.overrideWithValue(
              _SilentConsentPlayer(),
            ),
            elicitationAudioPlayerProvider.overrideWithValue(
              _SilentElicitationPlayer(),
            ),
            milestoneQuestionsLoaderProvider.overrideWithValue(
              () async => MilestoneEngine.parseQuestions(
                File('assets/data/milestones_hi.json').readAsStringSync(),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(routes: appRoutes);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: EarlyEchoTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        String text(String key) =>
            AppStrings.tr(key, container.read(appLocaleProvider));
        Future<void> tap(String key) async {
          await tester.tap(find.text(text(key)));
          await tester.pumpAndSettle();
        }

        Future<String> completeCapture(
          String child, {
          bool direct = false,
        }) async {
          if (direct) {
            router.push('/child-profile');
            await tester.pumpAndSettle();
          } else {
            await tap('home_new_screening');
            final fresh = container.read(sessionProvider);
            expect(fresh.sessionId, isNull);
            expect(fresh.biomarkerResult, isNull);
            expect(fresh.consentLogId, isNull);
          }
          for (final field in {
            'cp_child_name': child,
            'cp_age': '30',
            'cp_anganwadi': 'IN-MP-042',
            'cp_district': 'Indore',
            'cp_worker': 'Worker',
          }.entries) {
            await tester.enterText(
              find.widgetWithText(TextFormField, text(field.key)),
              field.value,
            );
          }
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Madhya Pradesh').last);
          await tester.pumpAndSettle();
          await tap('cp_next');
          final enrolled = container.read(sessionProvider);
          expect(enrolled.childProfile!.childName, child);
          expect(enrolled.sessionId, isNull);
          expect(enrolled.consentLogId, isNull);
          expect(enrolled.biomarkerResult, isNull);
          expect(enrolled.protocolTimings, isEmpty);
          await tap('goals_continue');
          await tap('q_skip');
          await tap('consent_play');
          await tap('consent_confirm');
          final id = container.read(sessionProvider).sessionId!;
          for (final (key, seconds) in [
            ('el_start', 60),
            ('el_next_activity', 80),
            ('el_next_activity', 60),
          ]) {
            await tester.tap(find.text(text(key)));
            await tester.pump();
            await tester.pump(Duration(seconds: seconds));
            await tester.pump();
          }
          await tester.pumpAndSettle();
          expect(find.byType(ResultScreen), findsOneWidget);
          expect(find.text(text('result_saved_local')), findsOneWidget);
          expect((await repository.getSessionById(id))!.childName, child);
          return id;
        }

        final firstId = await completeCapture('First child');
        final firstNotifier = container.read(sessionProvider.notifier);
        for (
          var i = 0;
          i < 8 && find.byType(HomeScreen).evaluate().isEmpty;
          i++
        ) {
          if (entry == 'AppBar Back') {
            await tester.pageBack();
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
        }
        expect(find.byType(HomeScreen), findsOneWidget);
        // Back itself does not mean a new capture or a result retry.
        expect(container.read(sessionProvider).sessionId, firstId);
        final secondId = await completeCapture(
          'Second child',
          direct: entry == 'direct enrollment',
        );
        expect(secondId, isNot(firstId));
        expect(
          identical(firstNotifier, container.read(sessionProvider.notifier)),
          isFalse,
        );
        expect(await repository.getAllSessions(), hasLength(2));
        for (final id in [firstId, secondId]) {
          final consent = (await repository.getConsentLogsForSession(
            id,
          )).single;
          expect(consent.id, id);
          expect(consent.sessionId, id);
        }
      },
    );
  }
}
