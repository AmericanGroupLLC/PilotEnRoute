@Tags(['sanity'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/ad_service.dart';

// Firebase caps apps per project, so the 43 apps are split across three
// AGL projects. The guard that matters is that the config belongs to one of
// OURS - a config from an unrelated project means no crash ever arrives.
const aglFirebaseProjects = <String>{
  'americangroupllc-5bdfc',
  'americangroupllc-agl2',
  'americangroupllc-agl3',
};


/// Release configuration that has to be right before anything is delivered.
///
/// These read files rather than pumping widgets, because the failures they
/// guard against do not appear in a widget test. Each one has actually
/// happened in this portfolio:
///
///   * a missing GADApplicationIdentifier — the AdMob SDK throws
///     GADInvalidInitializationException and iOS terminates the app on *every*
///     launch, after a completely green build;
///   * a release buildType left on `signingConfigs.getByName("debug")` — the
///     artifact installs and looks real, and Play rejects the upload;
///   * a version with no build number — Play has nothing to increment.
void main() {
  String read(String path) {
    final file = File(path);
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  group('release configuration', () {
    test('the version carries a build number', () {
      final match = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(read('pubspec.yaml'));
      expect(match, isNotNull, reason: 'pubspec.yaml declares no version');
      expect(match!.group(1), contains('+'),
          reason: 'Play needs a versionCode, which Flutter takes from the '
              '"+N" suffix. Without it every upload has the same code.');
    });

    test('a release build is not silently signed with the debug key', () {
      final gradle = read('android/app/build.gradle') +
          read('android/app/build.gradle.kts');
      if (gradle.isEmpty) return; // no Android target in this repo

      final release = RegExp(r'release\s*\{(.*?)\n    \}', dotAll: true)
          .firstMatch(gradle)
          ?.group(1);
      if (release == null || !release.contains('signingConfig')) return;

      final onlyDebug = release.contains('debug') &&
          !release.contains('if') &&
          !release.contains('?');
      expect(onlyDebug, isFalse,
          reason: 'the release buildType always uses the debug key, so the '
              'artifact cannot be uploaded to Play');
    });

    test('the Android manifest declares no debuggable release flag', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      if (manifest.isEmpty) return;
      expect(manifest.contains('android:debuggable="true"'), isFalse,
          reason: 'a debuggable release build is a security finding and a '
              'Play policy violation');
    });

    test('iOS declares the keys whose absence is a launch crash', () {
      final plist = read('ios/Runner/Info.plist');
      if (plist.isEmpty) return;

      for (final key in ['CFBundleShortVersionString', 'CFBundleVersion']) {
        expect(plist, contains(key), reason: '$key is required to submit');
      }
    });

    test('the iOS privacy manifest exists and is in the Xcode target', () {
      if (!Directory('ios/Runner').existsSync()) return;
      expect(File('ios/Runner/PrivacyInfo.xcprivacy').existsSync(), isTrue,
          reason: 'App Store Connect rejects a build that reaches a '
              'required-reason API without one');
      final project = read('ios/Runner.xcodeproj/project.pbxproj');
      expect(project, contains('PrivacyInfo.xcprivacy'),
          reason: 'the manifest exists but is not a member of the Runner '
              'target, so it is never copied into the .app and Apple never '
              'sees it');
    });

    test('a Firebase config, if present, is the real project', () {
      // A placeholder config is worse than none. The Gradle plugin applies,
      // Crashlytics initialises, AglCrash.isActive turns true — and every
      // report goes to a project that does not exist. That looks exactly like
      // an app which never crashes. MyHealth carried one of these
      // (project myhealth-local-dev, project_number 000000000000).
      final file = File('android/app/google-services.json');
      if (!file.existsSync()) return;

      final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final info = config['project_info'] as Map<String, dynamic>;

      expect(aglFirebaseProjects, contains(info['project_id']),
          reason: 'this google-services.json is for a different Firebase '
              'project, so no crash would ever arrive');
      expect(info['project_number'], isNot(matches(r'^0+$')),
          reason: 'a project_number of all zeros is a placeholder');
    });

    test('uncaught errors are captured before the app runs', () {
      final main = read('lib/main.dart');
      if (main.isEmpty) return;

      if (read('pubspec.yaml').contains('agl_observability')) {
        expect(main, contains('AglCrash.init'),
            reason: 'without this a release crash is never reported');
        return;
      }

      // An app can decline crash reporting — FashionFactory's published
      // privacy policy promises no crash-reporting service, and a test in that
      // repo enforces it. It still has to capture errors locally rather than
      // showing a user Flutter's grey-on-red diagnostic screen.
      final captures = main.contains('installErrorHandlers') ||
          main.contains('ErrorReporter.install') ||
          main.contains('FlutterError.onError') ||
          main.contains('runZonedGuarded');
      expect(captures, isTrue,
          reason: 'no crash reporting and no local error capture either');
    });

    test('the AdMob application ids are well formed on both platforms', () {
      // A malformed or absent id is not a degraded experience: on iOS the SDK
      // throws GADInvalidInitializationException and the app is terminated on
      // every launch.
      final appId = RegExp(r'ca-app-pub-\d+~\d+');

      final manifest = read('android/app/src/main/AndroidManifest.xml');
      if (manifest.contains('com.google.android.gms.ads.APPLICATION_ID')) {
        final value = RegExp(
                r'APPLICATION_ID"\s*\n?\s*android:value="([^"]+)"')
            .firstMatch(manifest)
            ?.group(1);
        expect(value, isNotNull);
        // A Gradle manifest placeholder is resolved at build time and is fine.
        if (!value!.startsWith(r'${')) {
          expect(appId.hasMatch(value), isTrue,
              reason: 'Android AdMob app id is malformed: $value');
        }
      }

      final plist = read('ios/Runner/Info.plist');
      if (plist.contains('GADApplicationIdentifier')) {
        final value = RegExp(
                r'<key>GADApplicationIdentifier</key>(?:\s|<!--[\s\S]*?-->)*'
                r'<string>([^<]*)</string>')
            .firstMatch(plist)
            ?.group(1);
        expect(value, isNotNull,
            reason: 'GADApplicationIdentifier has no value');
        // An Xcode build setting is substituted at build time.
        if (!value!.startsWith(r'$(')) {
          expect(appId.hasMatch(value), isTrue,
              reason: 'iOS AdMob app id is malformed: $value');
        }
      }
    });

    test('every ad request is behind a consent gate', () {
      // The detailed per-call-site check lives in ads_consent_test.dart; this
      // is the fast version, so a pull request cannot land an ad service with
      // no gate at all.
      final gated = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .any((f) => f.readAsStringSync().contains('Consent'));
      expect(gated, isTrue,
          reason: 'this app serves ads but nothing references consent');
    });

    test('the AdMob application ids are PilotEnRoute\'s real ones', () {
      // From agl-manifest/docs/admob-ids.json. Google's test app id here
      // would make every production impression worthless.
      expect(read('android/app/src/main/AndroidManifest.xml'),
          contains('ca-app-pub-8528784688453695~2760007152'));
      expect(read('ios/Runner/Info.plist'),
          contains('ca-app-pub-8528784688453695~9905754024'));
    });

    test('a release build without a unit define requests no ad', () {
      // Google's test units must never be served from a store build, so an
      // empty ADMOB_* define in release means "no ad", not "test ad".
      expect(
          AdUnitIds.resolve(
              define: '',
              testUnit: AdUnitIds.testAndroidBanner,
              release: true,
              screenshot: false),
          isNull);
      // Debug/profile keep the test unit so the integration stays testable.
      expect(
          AdUnitIds.resolve(
              define: '',
              testUnit: AdUnitIds.testAndroidBanner,
              release: false,
              screenshot: false),
          AdUnitIds.testAndroidBanner);
      // A unit passed at build time is used as is.
      const live = 'ca-app-pub-8528784688453695/9776841645';
      expect(
          AdUnitIds.resolve(
              define: live,
              testUnit: AdUnitIds.testAndroidBanner,
              release: true,
              screenshot: false),
          live);
      // A store-screenshot build never requests an ad.
      expect(
          AdUnitIds.resolve(
              define: live,
              testUnit: AdUnitIds.testAndroidBanner,
              release: true,
              screenshot: true),
          isNull);
      expect(
          AdUnitIds.resolve(
              define: '',
              testUnit: AdUnitIds.testAndroidBanner,
              release: false,
              screenshot: true),
          isNull);

      // This test binary is a debug build with no defines.
      expect(AdUnitIds.banner, AdUnitIds.testAndroidBanner);
      expect(AdUnitIds.adsAllowedForThisBuild, isTrue);
    });

    test('no ad unit id is hard-coded on a release path', () {
      // Units arrive as --dart-define=ADMOB_<FORMAT>_<PLATFORM>; the only
      // literal units allowed are Google's test units, reached solely through
      // AdUnitIds.resolve's non-release branch.
      final unit = RegExp(r'ca-app-pub-\d+/\d+');
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        for (final m in unit.allMatches(f.readAsStringSync())) {
          expect(m.group(0), startsWith('ca-app-pub-3940256099942544/'),
              reason: '${f.path} hard-codes a non-test ad unit');
        }
      }
      final service = read('lib/services/ad_service.dart');
      for (final key in const [
        'ADMOB_BANNER_ANDROID',
        'ADMOB_BANNER_IOS',
        'ADMOB_INTERSTITIAL_ANDROID',
        'ADMOB_INTERSTITIAL_IOS',
        'ADMOB_REWARDED_ANDROID',
        'ADMOB_REWARDED_IOS',
      ]) {
        expect(service, contains("String.fromEnvironment('$key')"));
      }
      // The places that would otherwise reach the SDK still consult the gate.
      expect(service, contains('adsAllowedForThisBuild'));
      expect(read('lib/widgets/ad_banner_widget.dart'),
          contains('AdUnitIds.banner == null'),
          reason: 'the banner slot would reserve 52px for an ad that is '
              'never requested');
    });
  });
}
