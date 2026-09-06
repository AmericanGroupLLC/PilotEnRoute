import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The single place uncaught errors flow through.
///
/// Installing this does three things a release build otherwise gets wrong:
///
/// 1. Framework errors ([FlutterError.onError]) and errors from the engine's
///    root isolate ([PlatformDispatcher.onError]) are captured instead of only
///    being printed to a console nobody is attached to.
/// 2. A handled failure can be recorded deliberately via [report], so a
///    swallowed `catch` still leaves a trace.
/// 3. A build-time exception renders a plain panel instead of Flutter's
///    grey-on-red diagnostic screen, which must never reach a user.
///
/// ## Wiring a crash service
///
/// [sink] is deliberately a no-op by default, so this file has no third-party
/// dependency and no DSN baked into the binary. Until a sink is set, a release
/// build reports nothing off-device — that is a known gap, not an oversight.
/// To send crashes somewhere, set it once in `main()` before [install]:
///
/// ```dart
/// await SentryFlutter.init((o) => o.dsn = mySentryDsn);
/// ErrorReporter.sink = (error, stack, {context}) =>
///     Sentry.captureException(error, stackTrace: stack);
/// ```
///
/// Read the DSN from a build-time define rather than a literal - DriftDate
/// passes one as SENTRY_DSN. Register the key in `env/README.md` and in the
/// env-key test at the same time: that test greps lib/ for every
/// `String.fromEnvironment` call and fails on an undocumented one, which is
/// why the example above does not spell the call out.
typedef ErrorSink =
    void Function(Object error, StackTrace? stack, {String? context});

class ErrorReporter {
  const ErrorReporter._();

  /// Where captured errors go. Defaults to a no-op; see the class docs.
  static ErrorSink? sink;

  /// Records a handled (non-fatal) error — a failed backend write, a
  /// permission denial, a malformed payload. Use it instead of an empty
  /// `catch`.
  static void report(Object error, StackTrace? stack, {String? context}) {
    if (kDebugMode) {
      debugPrint('[pilot_enroute] ${context ?? 'error'}: $error');
      if (stack != null) debugPrintStack(stackTrace: stack);
    }
    try {
      sink?.call(error, stack, context: context);
    } catch (_) {
      // A failing reporter must never take the app down with it.
    }
  }

  /// Installs the framework-level handlers. Call once, immediately after
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  static void install() {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      report(
        details.exception,
        details.stack,
        context: details.context?.toDescription() ?? 'flutter',
      );
      previousOnError?.call(details);
    };

    // Catches uncaught async errors on the root isolate. Returning true marks
    // them handled so a single failed Future does not take the isolate down.
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, context: 'platform');
      return true;
    };

    // Never show the red screen of death in a shipped build.
    if (kReleaseMode) {
      ErrorWidget.builder = (details) => const _FriendlyErrorPanel();
    }
  }
}

/// The replacement for Flutter's diagnostic error widget.
class _FriendlyErrorPanel extends StatelessWidget {
  const _FriendlyErrorPanel();

  @override
  Widget build(BuildContext context) {
    // Deliberately theme-free: this renders when something else already
    // failed, so it must not depend on an inherited theme or localization
    // that may be part of what broke.
    return const ColoredBox(
      color: Color(0xFF121212),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Something went wrong here.\nGo back, or reopen the app.',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
