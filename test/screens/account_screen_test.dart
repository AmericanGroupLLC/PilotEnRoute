/// In-app account deletion (App Store 5.1.1(v)).
///
/// The delete must be confirmed, must say it is permanent, and a failed server
/// call must leave the user signed in with the error on screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/account_screen.dart';
import 'package:pilot_enroute/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openSignedIn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'agl_is_local_session': true,
    'agl_user_id': 'u1',
    'agl_local_email': 'pilot@example.com',
  });
  await AuthService.instance.init();
  await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
  await tester.pumpAndSettle();
}

void main() {
  final auth = AuthService.instance;
  final realDelete = auth.deleteUserOnServer;
  tearDown(() async {
    auth.deleteUserOnServer = realDelete;
    await auth.signOut();
  });

  testWidgets('delete asks first and says it is permanent', (tester) async {
    await openSignedIn(tester);
    var calls = 0;
    auth.deleteUserOnServer = () async => calls++;

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete account?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, equals(0));
    expect(auth.isAuthenticated, isTrue);
  });

  testWidgets('a confirmed delete signs out', (tester) async {
    await openSignedIn(tester);
    auth.deleteUserOnServer = () async {};

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    // Sign-out awaits real platform calls; let them finish outside fake time.
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 200),
        ));
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isFalse);
    expect(find.text('Your account has been deleted'), findsOneWidget);
  });

  testWidgets('a failed delete shows the error and stays signed in',
      (tester) async {
    await openSignedIn(tester);
    auth.deleteUserOnServer =
        () async => throw Exception('function not found');

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isTrue);
    expect(find.textContaining('function not found'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
