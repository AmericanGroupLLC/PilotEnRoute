/// Session state, restore and sign-out for the shared AuthService singleton.
///
/// Supabase is deliberately never initialised in these tests: that is the same
/// state as a cold, offline launch, which is the path most likely to strand a
/// user on a blank screen or — worse — to let an empty form in.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final auth = AuthService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // The service is a process-wide singleton, so state leaks between tests
    // unless each one starts signed out.
    await auth.signOut();
  });

  group('field validation', () {
    test('an empty email is rejected with a message the form can show', () {
      expect(auth.validateEmailField(''), isNotNull);
      expect(auth.validateEmailField(null), isNotNull);
      expect(auth.validateEmailField('   '), isNotNull);
    });

    test('an address without an @ or a dot is rejected', () {
      expect(auth.validateEmailField('pilot'), isNotNull);
      expect(auth.validateEmailField('pilot@example'), isNotNull);
      expect(auth.validateEmailField('pilot example.com'), isNotNull);
      expect(auth.validateEmailField('@example.com'), isNotNull);
    });

    test('a normal address passes, including surrounding whitespace', () {
      expect(auth.validateEmailField('pilot@example.com'), isNull);
      expect(auth.validateEmailField('  pilot@example.com  '), isNull);
      expect(auth.validateEmailField('first.last+tag@sub.example.co.uk'),
          isNull);
    });

    test('a password shorter than the advertised minimum is rejected', () {
      expect(AuthService.minPasswordLength, equals(6));
      expect(auth.validatePasswordField(''), isNotNull);
      expect(auth.validatePasswordField('12345'), isNotNull);
      expect(auth.validatePasswordField('123456'), isNull);
    });

    test('the password rule states the actual minimum', () {
      // A message that disagrees with the check is its own support ticket.
      expect(auth.validatePasswordField('abc'),
          contains('${AuthService.minPasswordLength}'));
    });
  });

  group('user mapping', () {
    test('an id arrives under any of the keys the backends use', () {
      expect(AuthUser.fromJson({'id': 'a'}).id, equals('a'));
      expect(AuthUser.fromJson({'user_id': 'b'}).id, equals('b'));
      expect(AuthUser.fromJson({'uid': 'c'}).id, equals('c'));
      expect(AuthUser.fromJson({'sub': 'd'}).id, equals('d'));
      expect(AuthUser.fromJson(const {}).id, isEmpty);
    });

    test('a name arrives under any of the keys the backends use', () {
      expect(AuthUser.fromJson({'full_name': 'Amelia'}).name, equals('Amelia'));
      expect(
          AuthUser.fromJson({'display_name': 'Amelia'}).name, equals('Amelia'));
      expect(AuthUser.fromJson({'username': 'amelia'}).name, equals('amelia'));
      expect(AuthUser.fromJson(const {}).name, isNull);
    });

    test('a blank string is treated as absent, not as a name', () {
      // Otherwise the profile header renders an empty line.
      expect(AuthUser.fromJson({'name': '   '}).name, isNull);
    });

    test('an unknown role falls back to student rather than throwing', () {
      expect(UserRoleX.fromId('cfi'), equals(UserRole.cfi));
      expect(UserRoleX.fromId('CFI'), equals(UserRole.cfi));
      expect(UserRoleX.fromId('  admin '), equals(UserRole.admin));
      expect(UserRoleX.fromId('wizard'), equals(UserRole.student));
      expect(UserRoleX.fromId(null), equals(UserRole.student));
    });

    test('the persisted role id is the stable name, not the label', () {
      // Localising or prettifying `id` would break every stored session.
      expect(UserRole.cfi.id, equals('cfi'));
      expect(UserRole.cfi.label, equals('CFI'));
      expect(UserRole.operator.id, equals('operator'));
    });

    test('a user round-trips through JSON', () {
      const user = AuthUser(
        id: 'u1',
        email: 'pilot@example.com',
        name: 'Amelia',
        role: UserRole.cfi,
      );
      final restored = AuthUser.fromJson(user.toJson());
      expect(restored.id, equals('u1'));
      expect(restored.email, equals('pilot@example.com'));
      expect(restored.name, equals('Amelia'));
      expect(restored.role, equals(UserRole.cfi));
    });
  });

  group('cold start', () {
    test('with nothing stored the app starts signed out but initialised',
        () async {
      await auth.init();

      expect(auth.isInitialized, isTrue,
          reason: 'the AuthGate waits on this — false means a stuck splash');
      expect(auth.isAuthenticated, isFalse);
      expect(auth.canEnterApp, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('a persisted offline session is restored with its profile', () async {
      SharedPreferences.setMockInitialValues({
        'agl_is_local_session': true,
        'agl_user_id': 'local-demo-user',
        'agl_local_email': 'pilot@example.com',
        'agl_local_name': 'Amelia',
      });
      await auth.init();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.isLocalSession, isTrue);
      expect(auth.canEnterApp, isTrue);
      expect(auth.currentUser?.email, equals('pilot@example.com'));
      expect(auth.currentUser?.name, equals('Amelia'));
    });

    test('a local session with no stored email shows a placeholder, not an '
        'empty address', () async {
      SharedPreferences.setMockInitialValues({'agl_is_local_session': true});
      await auth.init();
      expect(auth.currentUser?.email, isNotEmpty);
    });

    test('corrupt preferences are treated as signed out, never as a crash',
        () async {
      // A String where a bool is expected is what a bad migration looks like.
      SharedPreferences.setMockInitialValues({
        'agl_is_local_session': 'yes',
        'agl_access_token': 42,
      });
      await auth.init();

      expect(auth.isInitialized, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('init is safe to call twice', () async {
      await auth.init();
      await auth.init();
      expect(auth.isInitialized, isTrue);
    });
  });

  group('guest', () {
    test('a guest can enter the app without being authenticated', () {
      auth.continueAsGuest();
      expect(auth.isGuest, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.canEnterApp, isTrue);
    });

    test('entering as a guest notifies once so the gate rebuilds', () {
      var notifications = 0;
      void listener() => notifications++;
      auth.addListener(listener);
      addTearDown(() => auth.removeListener(listener));

      auth.continueAsGuest();
      auth.continueAsGuest(); // already a guest — must not re-notify
      expect(notifications, equals(1));
    });

    test('signing out drops guest mode too', () async {
      auth.continueAsGuest();
      await auth.signOut();
      expect(auth.isGuest, isFalse);
      expect(auth.canEnterApp, isFalse);
    });
  });

  group('sign out', () {
    test('every persisted session key is removed', () async {
      SharedPreferences.setMockInitialValues({
        'agl_is_local_session': true,
        'agl_access_token': 'token',
        'agl_refresh_token': 'refresh',
        'agl_user_id': 'u1',
        'agl_local_email': 'pilot@example.com',
        'agl_local_name': 'Amelia',
      });
      await auth.init();
      expect(auth.isAuthenticated, isTrue);

      await auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      for (final key in const [
        'agl_is_local_session',
        'agl_access_token',
        'agl_refresh_token',
        'agl_user_id',
        'agl_local_email',
        'agl_local_name',
      ]) {
        expect(prefs.get(key), isNull, reason: '$key survived sign-out');
      }
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('a signed-out session does not come back on the next launch',
        () async {
      SharedPreferences.setMockInitialValues({
        'agl_is_local_session': true,
        'agl_user_id': 'u1',
      });
      await auth.init();
      await auth.signOut();
      await auth.init();

      expect(auth.isAuthenticated, isFalse);
    });
  });

  group('offline sign-in', () {
    test('an ordinary account gets an honest network error, not a fake '
        'session', () async {
      // Supabase is not initialised here, so this is the offline path.
      final result = await auth.loginEmail('pilot@example.com', 'hunter22');

      expect(result.ok, isFalse);
      expect(result.error, contains('Network'));
      expect(auth.isAuthenticated, isFalse);
    });

    test('empty credentials never authenticate', () async {
      // The test-account comparison is against build-time constants that are
      // empty in a shipped build; '' == '' must not open the app.
      final result = await auth.loginEmail('', '');

      expect(result.ok, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('a failed sign-in leaves the button enabled again', () async {
      await auth.loginEmail('pilot@example.com', 'hunter22');
      expect(auth.isBusy, isFalse,
          reason: 'a stuck busy flag disables the sign-in button forever');
    });
  });

  group('AuthResult', () {
    test('a cancellation is not an error the UI should shout about', () {
      const r = AuthResult.cancelled();
      expect(r.ok, isFalse);
      expect(r.cancelled, isTrue);
      expect(r.error, isNull);
    });

    test('a failure carries a message and no user', () {
      const r = AuthResult.failure('nope');
      expect(r.ok, isFalse);
      expect(r.cancelled, isFalse);
      expect(r.error, equals('nope'));
      expect(r.user, isNull);
    });
  });
}
