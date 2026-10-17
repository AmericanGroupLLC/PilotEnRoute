import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for integration_test/should_features_test.dart. Writes to the
/// git-ignored build/ folder, never to store_screenshots/: these are
/// verification captures, not store art.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes,
        [Map<String, Object?>? args]) async {
      final file = File('build/verify_screenshots/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
