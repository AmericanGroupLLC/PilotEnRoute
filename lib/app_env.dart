/// Which deployment the binary was built for.
enum Environment { dev, staging, prod }

/// Build-time environment selection.
///
/// Values arrive via `--dart-define-from-file=env/<name>.json`; see
/// `env/README.md`. [name] defaults to `prod` so a build that forgets the flag
/// fails closed onto production configuration rather than silently pointing a
/// shipped binary at development infrastructure.
class AppEnv {
  const AppEnv._();

  static const String name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'prod',
  );

  static Environment get current => switch (name) {
    'dev' => Environment.dev,
    'staging' => Environment.staging,
    _ => Environment.prod,
  };

  static bool get isDev => current == Environment.dev;
  static bool get isStaging => current == Environment.staging;
  static bool get isProd => current == Environment.prod;

  /// Shown in-app and attached to diagnostics so a report can be tied to the
  /// build it came from. Empty in production.
  static String get banner => isProd ? '' : name.toUpperCase();
}
