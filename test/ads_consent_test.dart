import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every ad request has to sit behind UMP consent.
///
/// AdMob policy is that in the EEA, the UK and Switzerland an ad may not be
/// *requested* until the user has been asked — serving a non-personalised ad
/// instead is not sufficient, and getting it wrong risks the AdMob account
/// rather than just this app.
///
/// This reads the source rather than the runtime, because what it guards
/// against is someone adding a new ad somewhere and forgetting the gate; a
/// widget test would only cover the screens it happens to pump. For each place
/// an ad is constructed it looks at the enclosing method and insists the gate
/// is checked before the request goes out.
void main() {
  final adConstruction = RegExp(
    r'\bBannerAd\(|'
    r'\b(?:InterstitialAd|RewardedAd|RewardedInterstitialAd|AppOpenAd|NativeAd)'
    r'\.load\(',
  );
  final methodSignature = RegExp(
    r'^\s{2,6}(?:static\s+)?(?:Future<[^>]*>|void|[A-Z]\w*\??|bool|String\??)\s+'
    r'(\w+)\([^;]*\)\s*(?:async\s*)?\{',
  );
  final consentCheck = RegExp(r'AglConsent\.(?:canRequestAds|adsAllowed)');

  /// Call sites whose gate is one level up rather than inline. Each entry is a
  /// deliberate exception with a reason, not a way to silence the test.
  const gatedByCaller = <String, String>{
    'createBannerAd':
        'returns a non-nullable BannerAd so it cannot decline; every caller '
        'checks shouldShowAds() first, which is where the gate lives',
  };

  test('every ad request is gated on consent', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsStringSync().split('\n');

      for (var i = 0; i < lines.length; i++) {
        if (!adConstruction.hasMatch(lines[i])) continue;

        var method = '';
        var start = -1;
        for (var j = i; j >= 0 && j > i - 60; j--) {
          final match = methodSignature.firstMatch(lines[j]);
          if (match != null) {
            method = match.group(1)!;
            start = j;
            break;
          }
        }

        if (start < 0) {
          offenders.add('${entity.path}:${i + 1} — no enclosing method found');
          continue;
        }
        if (gatedByCaller.containsKey(method)) continue;

        final body = lines.sublist(start, i).join('\n');
        if (!consentCheck.hasMatch(body)) {
          offenders.add('${entity.path}:${i + 1} — $method() requests an ad '
              'with no consent check before it');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'ad requests with no consent gate:\n${offenders.join('\n')}',
    );
  });

  test('consent is resolved before the SDK is initialised', () {
    final initialisers = <File>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('MobileAds.instance.initialize(')) {
        initialisers.add(entity);
      }
    }

    expect(initialisers, isNotEmpty,
        reason: 'this app declares google_mobile_ads but never initialises it');

    for (final file in initialisers) {
      final source = file.readAsStringSync();
      final consent = source.indexOf('AglConsent.gather()');
      final sdk = source.indexOf('MobileAds.instance.initialize(');
      expect(consent, greaterThanOrEqualTo(0),
          reason: '${file.path} initialises the SDK without gathering consent');
      expect(consent, lessThan(sdk),
          reason: '${file.path} initialises the SDK before asking for consent');
    }
  });
}
