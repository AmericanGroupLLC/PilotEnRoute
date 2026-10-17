/// Honest scope (spec M6): no login wall, no dead or off-core surfaces, no
/// placeholder strings, no third-party weather proxy.
///
/// The AI assistant, NOTAM, radio, Google sign-in and drawer tests that used
/// to live here went with those features (study modules, accounts and the
/// drawer were removed); the two lib-wide checks that still apply are kept.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _libDart() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
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

  // Spec M6: these strings are template tells or placeholders.
  const forbidden = [
    'demo@local',
    'Test Pilot',
    'coming soon',
    'TRAINING MODULES',
    '500+',
    'rotatepilot.com',
  ];
  for (final word in forbidden) {
    test('lib/ never says "$word"', () {
      final hits = <String>[];
      for (final f in _libDart()) {
        if (f.readAsStringSync().toLowerCase().contains(word.toLowerCase())) {
          hits.add(f.path);
        }
      }
      expect(hits, isEmpty);
    });
  }

  test('there is no sign-in: no Supabase auth, Apple or Google sign-in', () {
    for (final f in _libDart()) {
      final src = f.readAsStringSync();
      for (final token in [
        'supabase_flutter',
        'sign_in_with_apple',
        'google_sign_in',
        'delete_user',
        'LoginScreen',
        'AuthGate',
        'AuthService',
      ]) {
        expect(src.contains(token), isFalse, reason: '${f.path}: $token');
      }
    }
  });

  // Home and the knowledge-test quiz came back on 2026-10-17 (founder's
  // Clear Skies design, decision-log), built only on the pilot's own data and
  // FAA-sourced content; test/content/sourced_content_test.dart holds them
  // to that. The rest stay removed.
  test('the removed modules are gone from lib/', () {
    for (final name in [
      'simulation', 'emergency', 'drone', 'education', 'exam',
      'flashcard', 'glossary', 'regulations', 'career', 'icara', 'garmin',
      'integrations', 'ai_assistant', 'notam', 'radio', 'wind', 'map',
      'navdb', 'flight_tracker', 'debrief', 'alerts', 'news',
      'notifications', 'endorsements', 'account', 'login',
    ]) {
      expect(File('lib/screens/${name}_screen.dart').existsSync(), isFalse,
          reason: name);
    }
    expect(File('lib/widgets/app_drawer.dart').existsSync(), isFalse);
    expect(File('lib/widgets/daily_quote_card.dart').existsSync(), isFalse);
  });

  test('pubspec bundles no empty data files and fetches no fonts', () {
    final pub = File('pubspec.yaml').readAsStringSync();
    expect(pub, isNot(contains('assets/data/')));
    expect(pub, isNot(contains('assets/icons/')));
    expect(pub, isNot(contains('assets/lottie/')));
    expect(pub, isNot(contains('google_fonts')));
    expect(pub, isNot(contains('supabase_flutter')));
    expect(Directory('assets/data').existsSync() &&
            Directory('assets/data').listSync().isNotEmpty,
        isFalse);
  });

  test('every bundled font is in assets/fonts with its OFL licence', () {
    final pub = File('pubspec.yaml').readAsStringSync();
    final fonts = RegExp(r'asset: (assets/fonts/\S+\.ttf)')
        .allMatches(pub)
        .map((m) => m.group(1)!)
        .toList();
    expect(fonts, hasLength(11));
    for (final f in fonts) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
    for (final l in ['OFL-SofiaSans.txt', 'OFL-FiraMono.txt']) {
      final text = File('assets/fonts/$l').readAsStringSync();
      expect(text, contains('SIL Open Font License, Version 1.1'));
    }
  });
}
