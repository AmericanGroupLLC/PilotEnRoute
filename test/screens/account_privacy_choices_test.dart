/// Google UMP "Privacy choices" entry.
///
/// Where a GDPR message applies (EEA/UK/Switzerland) users must be able to
/// change their ad-consent choice inside the app. The row is shown only when
/// UMP says privacy options are required, and opens Google's form.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/account_screen.dart';
import 'package:pilot_enroute/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpAccount(
  WidgetTester tester, {
  required bool required,
  required Future<void> Function() onShow,
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(signedIn
      ? {
          'agl_is_local_session': true,
          'agl_user_id': 'u1',
          'agl_local_email': 'pilot@example.com',
        }
      : {});
  await AuthService.instance.init();
  await tester.pumpWidget(MaterialApp(
    home: AccountScreen(
      isPrivacyOptionsRequired: () async => required,
      showPrivacyOptions: onShow,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() async => AuthService.instance.signOut());

  testWidgets('row is hidden when privacy options are not required',
      (tester) async {
    await pumpAccount(tester, required: false, onShow: () async {});
    expect(find.text('Privacy choices'), findsNothing);
  });

  testWidgets('row shows when required and opens the form', (tester) async {
    var shown = 0;
    await pumpAccount(tester, required: true, onShow: () async => shown++);

    expect(find.text('Privacy choices'), findsOneWidget);
    await tester.ensureVisible(find.text('Privacy choices'));
    await tester.tap(find.text('Privacy choices'));
    await tester.pumpAndSettle();
    expect(shown, equals(1));
  });

  testWidgets('row shows for a signed-in user too', (tester) async {
    await pumpAccount(tester,
        required: true, onShow: () async {}, signedIn: true);
    expect(find.text('Privacy choices'), findsOneWidget);
  });
}
