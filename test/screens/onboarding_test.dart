/// Three-screen onboarding: airport + class, medical + flight review, then
/// personal minimums that start blank. No account anywhere.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/screens/onboarding_screen.dart';
import 'package:pilot_enroute/services/settings_store.dart';

import '../support/awc_fixtures.dart';
import '../support/harness.dart';

Future<Harness> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final h = Harness(settings: SettingsStore());
  await tester.pumpWidget(h.wrap(const OnboardingScreen()));
  await tester.pump();
  return h;
}

Future<void> page1(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('onboarding-airport')), 'kpao');
  await tester.tap(find.byKey(const Key('class-ASEL')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('onboarding-next-1')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the airport check names the field from aviationweather.gov',
      (tester) async {
    await open(tester);
    await http.runWithClient(() async {
      await tester.enterText(find.byKey(const Key('onboarding-airport')), 'kpao');
      await tester.tap(find.text('Check'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }, awcClient);
    expect(find.textContaining('KPAO · PALO ALTO/PALO ALTO'), findsOneWidget);
  });

  testWidgets('an unknown airport is reported, not guessed', (tester) async {
    await open(tester);
    await http.runWithClient(() async {
      await tester.enterText(find.byKey(const Key('onboarding-airport')), 'kzzz');
      await tester.tap(find.text('Check'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }, awcClient);
    expect(find.textContaining('does not know KZZZ'), findsOneWidget);
  });

  testWidgets('medical details on screen 2 are saved at the end',
      (tester) async {
    final h = await open(tester);
    await page1(tester);
    await tester.tap(find.byKey(const Key('medical-third')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('age-40plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-skip-3')));
    await tester.pumpAndSettle();
    expect(h.settings.onboardingDone, isTrue);
    expect(h.settings.homeAirport, 'KPAO');
    expect(h.settings.profile.medicalKind, MedicalKind.third);
    expect(h.settings.profile.age40OrOlderAtExam, isTrue);
    expect(h.settings.profile.homeCategoryClass, 'ASEL');
  });

  testWidgets('minimums start blank: the app suggests nothing', (tester) async {
    await open(tester);
    await page1(tester);
    await tester.tap(find.byKey(const Key('onboarding-skip-2')));
    await tester.pumpAndSettle();
    for (final p in ['day', 'night']) {
      for (final f in [
        'ceilingFt',
        'visibilitySm',
        'maxWindKt',
        'maxGustKt',
        'maxCrosswindKt'
      ]) {
        final field =
            tester.widget<TextFormField>(find.byKey(Key('min-$p-$f')));
        expect(field.controller!.text, isEmpty, reason: '$p $f');
      }
    }
  });

  testWidgets('minimums typed on screen 3 are saved on Finish', (tester) async {
    final h = await open(tester);
    await page1(tester);
    await tester.tap(find.byKey(const Key('onboarding-skip-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('min-day-ceilingFt')), '2500');
    await tester.enterText(find.byKey(const Key('min-day-maxCrosswindKt')), '10');
    await tester.enterText(find.byKey(const Key('min-night-visibilitySm')), '5');
    await tester.tap(find.byKey(const Key('onboarding-finish')));
    await tester.pumpAndSettle();
    expect(h.settings.onboardingDone, isTrue);
    expect(h.settings.minimums.day.ceilingFt, 2500);
    expect(h.settings.minimums.day.maxCrosswindKt, 10);
    expect(h.settings.minimums.day.visibilitySm, isNull);
    expect(h.settings.minimums.night.visibilitySm, 5);
  });

  testWidgets('an invalid minimum stops Finish with a reason', (tester) async {
    final h = await open(tester);
    await page1(tester);
    await tester.tap(find.byKey(const Key('onboarding-skip-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('min-day-maxWindKt')), '12.5');
    await tester.tap(find.byKey(const Key('onboarding-finish')));
    await tester.pump();
    expect(find.text('Whole numbers'), findsOneWidget);
    expect(h.settings.onboardingDone, isFalse);
  });

  testWidgets('nothing on any screen asks for an account', (tester) async {
    await open(tester);
    for (final w in ['Sign in', 'Sign up', 'Password', 'Create account', 'Log in']) {
      expect(find.textContaining(w), findsNothing, reason: w);
    }
  });
}
