import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/error_reporter.dart';

/// Guards the app's only route for uncaught errors.
///
/// Before this existed, a framework error in a release build printed to a
/// console nobody was attached to and a build-time exception put Flutter's
/// grey-on-red diagnostic screen in front of the user.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => ErrorReporter.sink = null);

  test('report() forwards the error, stack and context to the sink', () {
    Object? seenError;
    StackTrace? seenStack;
    String? seenContext;
    ErrorReporter.sink = (e, s, {context}) {
      seenError = e;
      seenStack = s;
      seenContext = context;
    };

    final stack = StackTrace.current;
    ErrorReporter.report('boom', stack, context: 'unit');

    expect(seenError, 'boom');
    expect(seenStack, same(stack));
    expect(seenContext, 'unit');
  });

  test('report() is a no-op when no sink is attached', () {
    ErrorReporter.sink = null;
    expect(() => ErrorReporter.report('boom', StackTrace.current),
        returnsNormally);
  });

  test('a throwing sink never propagates to the caller', () {
    // A crash reporter that is itself broken must not take the app down.
    ErrorReporter.sink = (e, s, {context}) => throw StateError('sink down');
    expect(() => ErrorReporter.report('boom', StackTrace.current),
        returnsNormally);
  });

  test('install() routes framework errors into the sink', () {
    final previous = FlutterError.onError;
    addTearDown(() => FlutterError.onError = previous);

    final seen = <Object>[];
    ErrorReporter.sink = (e, s, {context}) => seen.add(e);
    ErrorReporter.install();

    FlutterError.onError!(FlutterErrorDetails(
      exception: StateError('framework boom'),
      library: 'test',
    ));

    expect(seen, hasLength(1));
    expect(seen.single, isStateError);
  });

  test('install() marks uncaught async errors handled', () {
    final previous = PlatformDispatcher.instance.onError;
    addTearDown(() => PlatformDispatcher.instance.onError = previous);

    final seen = <Object>[];
    ErrorReporter.sink = (e, s, {context}) => seen.add(e);
    ErrorReporter.install();

    // Returning true is what stops one failed Future killing the isolate.
    final handled = PlatformDispatcher.instance
        .onError!(StateError('async boom'), StackTrace.current);

    expect(handled, isTrue);
    expect(seen, hasLength(1));
  });
}
