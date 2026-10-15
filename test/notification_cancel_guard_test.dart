import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// On iOS 27 flutter_local_notifications' cancel(id) waits on the main thread
/// for the system notification server; on the simulator that froze apps
/// (Verba's launch screen, FashionFactory's "Save order", 2026-10-14). Every
/// cancel must go through agl_notify, which only cancels ids that are pending
/// or delivered. The same rule is predelivery check "notifications: cancel
/// through agl_notify".
void main() {
  test('the notification plugin is only cancelled through AglNotify', () {
    final offenders = <String>[];
    var wired = 0;
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (!src.contains('package:flutter_local_notifications/')) continue;
      final names = <String>{
        for (final m in RegExp(r'FlutterLocalNotificationsPlugin\??\s+(\w+)')
            .allMatches(src))
          m.group(1)!,
        for (final m in RegExp(r'(\w+)\s*=\s*FlutterLocalNotificationsPlugin\(')
            .allMatches(src))
          m.group(1)!,
      }..removeWhere((n) => n == 'get' || n == 'Function');
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final n in names) {
          final call = RegExp(
              '\\b${RegExp.escape(n)}\\s*\\.\\s*(cancel|cancelAll|cancelAllPendingNotifications)\\b');
          if (!call.hasMatch(line)) continue;
          if (line.contains('cancelId:') || line.contains('cancelEverything:')) {
            wired++;
          } else {
            offenders.add('${f.path}:${i + 1}: ${line.trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'direct plugin cancel outside AglNotify (freezes iOS 27)');
    expect(wired, greaterThan(0), reason: 'AglNotify is wired to the plugin');
  });
}
