/// Google UMP "Privacy choices" entry, now in Settings (there is no account
/// screen any more).
///
/// Where a GDPR message applies (EEA/UK/Switzerland) users must be able to
/// change their ad-consent choice inside the app. The row is shown only when
/// UMP says privacy options are required, and opens Google's form.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/settings_screen.dart';
import 'package:pilot_enroute/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/harness.dart';

Future<void> pumpSettings(
  WidgetTester tester, {
  required bool required,
  required Future<void> Function() onShow,
  SettingsStore? settings,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(Harness(settings: settings).wrap(SettingsScreen(
    isPrivacyOptionsRequired: () async => required,
    showPrivacyOptions: onShow,
  )));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('row is hidden when privacy options are not required',
      (tester) async {
    await pumpSettings(tester, required: false, onShow: () async {});
    expect(find.text('Privacy choices'), findsNothing);
  });

  testWidgets('row shows when required and opens the form', (tester) async {
    var shown = 0;
    await pumpSettings(tester, required: true, onShow: () async => shown++);

    expect(find.text('Privacy choices'), findsOneWidget);
    await tester.ensureVisible(find.text('Privacy choices'));
    await tester.tap(find.text('Privacy choices'));
    await tester.pumpAndSettle();
    expect(shown, equals(1));
  });

  testWidgets('row shows for a fully set-up pilot too', (tester) async {
    await pumpSettings(tester,
        required: true,
        onShow: () async {},
        settings: SettingsStore(onboardingDone: true, homeAirport: 'KPAO'));
    expect(find.text('Privacy choices'), findsOneWidget);
    expect(find.text('KPAO'), findsOneWidget);
  });

  testWidgets('settings has no account, sign-in or delete-account entry',
      (tester) async {
    await pumpSettings(tester, required: true, onShow: () async {});
    for (final word in ['Sign in', 'Account', 'Delete account', 'Log out']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
    for (final word in [
      'Home airport',
      'Pilot profile',
      'Personal minimums',
      'Reminders',
      'About PilotEnRoute',
    ]) {
      expect(find.text(word), findsOneWidget, reason: word);
    }
  });
}
