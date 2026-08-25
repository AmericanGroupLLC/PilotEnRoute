import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/app_env.dart';

/// Build-time guard for the environment configuration.
///
/// AppEnv.validate() deliberately does not throw in release, so this is where
/// a bad `env/*.json` is actually caught. It runs in CI on every push.
void main() {
  Map<String, dynamic> load(String env) =>
      jsonDecode(File('env/$env.json').readAsStringSync())
          as Map<String, dynamic>;

  const envs = ['dev', 'staging', 'prod'];

  // Keys the app reads via String.fromEnvironment that must be supplied by an
  // env file. Credentials are deliberately excluded: they come from the
  // gitignored env/secrets.json and must never appear in a committed env file.
  const required = [
    'APP_ENV',
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'PRIVACY_URL',
    'TERMS_URL',
    'SUPPORT_URL',
    'APP_STORE_URL',
    'PLAY_STORE_URL',
  ];

  const credentialKeys = [
    'QA_EMAIL',
    'QA_PASSWORD',
    'DEV_EMAIL',
    'DEV_PASSWORD',
    'ADMIN_EMAIL',
    'ADMIN_PASSWORD',
  ];

  for (final env in envs) {
    group('env/$env.json', () {
      test('exists and is valid JSON', () {
        expect(File('env/$env.json').existsSync(), isTrue);
        expect(load(env), isA<Map<String, dynamic>>());
      });

      test('APP_ENV matches the file name', () {
        expect(
          load(env)['APP_ENV'],
          env,
          reason: 'A build would report the wrong environment.',
        );
      });

      test('supplies every required key, non-empty', () {
        final cfg = load(env);
        for (final key in required) {
          expect(cfg.containsKey(key), isTrue, reason: '$key is missing');
          expect(
            (cfg[key] as String?) ?? '',
            isNotEmpty,
            reason: '$key is empty',
          );
        }
      });

      test('every http(s) URL is https', () {
        load(env).forEach((key, value) {
          if (value is String && value.startsWith('http')) {
            expect(
              value.startsWith('https://'),
              isTrue,
              reason: '$key must be https, got $value',
            );
          }
        });
      });

      test('carries no credentials', () {
        final cfg = load(env);
        for (final key in credentialKeys) {
          expect(
            cfg.containsKey(key),
            isFalse,
            reason:
                '$key must come from the gitignored env/secrets.json, '
                'never a committed env file.',
          );
        }
      });
    });
  }

  test('production points at the production store listing', () {
    final prod = load('prod');
    expect(prod['PLAY_STORE_URL'], isNot(contains('.dev')));
    expect(prod['PLAY_STORE_URL'], isNot(contains('.staging')));
  });

  test('dev and staging are isolated from the production store listing', () {
    expect(load('dev')['PLAY_STORE_URL'], contains('.dev'));
    expect(load('staging')['PLAY_STORE_URL'], contains('.staging'));
  });

  test('every fromEnvironment key in lib/ is a known key', () {
    final keys = <String>{};
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      keys.addAll(
        RegExp(
          r"fromEnvironment\(\s*'([A-Z_0-9]+)'",
        ).allMatches(f.readAsStringSync()).map((m) => m.group(1)!),
      );
    }
    const known = {
      ...required,
      ...credentialKeys,
      'ANTHROPIC_API_KEY',
      'GOOGLE_IOS_CLIENT_ID',
      'GOOGLE_SERVER_CLIENT_ID',
    };
    expect(
      keys.difference(known),
      isEmpty,
      reason:
          'Undocumented dart-define key(s). Add them to env/*.json and '
          'to env/README.md.',
    );
  });

  test('AppEnv defaults to prod when APP_ENV is not supplied', () {
    // The test binary is built without --dart-define, so this asserts the
    // fail-closed default: a forgotten flag must not yield a dev build.
    expect(AppEnv.name, 'prod');
    expect(AppEnv.isProd, isTrue);
    expect(AppEnv.banner, isEmpty);
  });

  test('validate() rejects a non-https or empty backend URL', () {
    expect(
      () => AppEnv.validate(
        supabaseUrl: 'http://insecure.example',
        supabaseAnonKey: 'k',
        testAccountEnabled: false,
      ),
      throwsStateError,
    );
    expect(
      () => AppEnv.validate(
        supabaseUrl: '',
        supabaseAnonKey: 'k',
        testAccountEnabled: false,
      ),
      throwsStateError,
    );
  });

  test('validate() accepts a sound configuration', () {
    expect(
      AppEnv.validate(
        supabaseUrl: 'https://ok.supabase.co',
        supabaseAnonKey: 'k',
        testAccountEnabled: false,
      ),
      isEmpty,
    );
  });

  test('no committed source ships a literal test credential', () {
    // The literals these replaced were extractable from any shipped APK.
    final offenders = <String>[];
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      if (RegExp(
        r"(qaPassword|devPassword|adminPassword|testPassword)\s*=\s*'[^']+'",
      ).hasMatch(src)) {
        offenders.add(f.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'credentials must come from String.fromEnvironment',
    );
  });
}
