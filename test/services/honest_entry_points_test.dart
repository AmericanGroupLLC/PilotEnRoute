/// Entry points that used to promise something the app could not deliver.
///
/// - The AI assistant and token refresh / logout called a gateway
///   (api.americangroupllc.com) that no longer resolves.
/// - The drawer offered NOTAMs with no FAA credentials and an AI assistant
///   with no model.
/// - Radio streamed LiveATC audio without a licence.
/// - "Continue with Google" was shown on iOS with no iOS client id.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/ai_service.dart';
import 'package:pilot_enroute/services/auth_service.dart';
import 'package:pilot_enroute/services/notam_service.dart';
import 'package:pilot_enroute/services/radio_service.dart';
import 'package:pilot_enroute/widgets/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

Iterable<File> _libDart() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing in lib/ calls the retired API gateway', () {
    for (final f in _libDart()) {
      final src = f.readAsStringSync();
      expect(src.contains('api.americangroupllc.com/api'), isFalse,
          reason: '${f.path} still targets the dead gateway');
      expect(src.contains('apiBaseUrl'), isFalse, reason: f.path);
    }
  });

  test('nothing in lib/ streams LiveATC audio directly', () {
    for (final f in _libDart()) {
      expect(f.readAsStringSync().contains('d.liveatc.net'), isFalse,
          reason: f.path);
    }
  });

  test('ATC entries link out to the airport page on liveatc.net', () {
    final uri = RadioService.feeds.first.liveAtcPage;
    expect(uri.host, 'www.liveatc.net');
    expect(uri.queryParameters['icao'], 'kjfk');
  });

  group('AI assistant', () {
    test('without a model key the assistant is not live', () {
      expect(AiService.liveAiAvailable, isFalse);
      expect(AiService().configured, isFalse);
    });

    test('a signed-in user does not make it claim to be live', () async {
      SharedPreferences.setMockInitialValues({'agl_is_local_session': true});
      await AuthService.instance.init();
      expect(AuthService.instance.isAuthenticated, isTrue);
      expect(AiService().configured, isFalse);
      await AuthService.instance.signOut();
    });

    test('a message gets a labelled offline answer, not a network error',
        () async {
      final ai = AiService();
      final reply = await ai.sendMessage('Decode this METAR');
      expect(reply, startsWith('**Offline reference'));
      expect(reply, isNot(contains('Could not reach')));
      expect(ai.messages.last.offline, isTrue);
    });
  });

  test('a token left by the retired gateway is discarded, not a session',
      () async {
    SharedPreferences.setMockInitialValues({
      'agl_access_token': 'legacy',
      'agl_refresh_token': 'legacy-refresh',
      'agl_user_id': 'u1',
    });
    await AuthService.instance.init();
    expect(AuthService.instance.isAuthenticated, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.get('agl_access_token'), isNull);
    expect(prefs.get('agl_refresh_token'), isNull);
  });

  group('Google sign-in availability', () {
    test('hidden on iOS without an iOS client id', () {
      expect(
          AuthService.googleSignInAvailableOn(TargetPlatform.iOS,
              iosClientId: ''),
          isFalse);
    });

    test('offered on iOS once a client id is configured', () {
      expect(
          AuthService.googleSignInAvailableOn(TargetPlatform.iOS,
              iosClientId: '123-abc.apps.googleusercontent.com'),
          isTrue);
    });

    test('offered on Android', () {
      expect(
          AuthService.googleSignInAvailableOn(TargetPlatform.android,
              iosClientId: ''),
          isTrue);
    });
  });

  testWidgets('the drawer hides entries that cannot work in this build',
      (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expect(NotamService.credentialsConfigured, isFalse);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppDrawer())));
    await tester.pump();

    expect(find.text('NOTAMs'), findsNothing);
    expect(find.text('AI Assistant'), findsNothing);
    expect(find.text('Moving Map'), findsNothing);
    expect(find.text('AI Flight Simulator'), findsNothing);
    expect(find.text('Garmin Connect'), findsNothing);
    expect(find.text('Aviation Map'), findsOneWidget);
    expect(find.text('Basic Flight Sim'), findsOneWidget);
    expect(find.text('GPS'), findsNothing);
  });
}
