import 'dart:async';

import 'package:agl_i18n/agl_i18n.dart';
import 'package:agl_observability/agl_observability.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'screens/airport_screen.dart';
import 'screens/app_shell.dart';
import 'screens/charts_screen.dart';
import 'screens/checklist_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/e6b_screen.dart';
import 'screens/flight_plan_screen.dart';
import 'screens/fuel_screen.dart';
import 'screens/go_history_screen.dart';
import 'screens/minimums_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/today_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/weight_balance_screen.dart';
import 'services/ad_service.dart';
import 'services/document_service.dart';
import 'services/error_reporter.dart';
import 'services/flight_plan_service.dart';
import 'services/logbook_service.dart';
import 'services/notification_service.dart';
import 'services/practice_store.dart';
import 'services/reminder_service.dart';
import 'services/settings_store.dart';
import 'services/weather_service.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Crash reporting, before anything that could fail. Inactive and
  // harmless until the Firebase config files are added.
  await AglCrash.init(appName: 'PilotEnRoute');
  await AglInsights.init(appName: 'PilotEnRoute');
  ErrorReporter.sink = (error, stack, {context}) =>
      AglCrash.recordError(error, stack, reason: context);
  ErrorReporter.install();

  // Timezone data for scheduling lapse reminders.
  tz.initializeTimeZones();

  // A failing plugin must degrade its own feature, never the first frame.
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }

  // AdMob gathers UMP consent; not awaited so the consent dialog never sits
  // over a black screen. Ad call sites wait for consent on their own.
  unawaited(AdService().initialize());

  final settings = await SettingsStore.load();
  final practice = await PracticeStore.load();
  final locale = AglLocaleController();
  await locale.load();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  runApp(PilotEnRouteApp(
      settings: settings, practice: practice, locale: locale));
}

class PilotEnRouteApp extends StatefulWidget {
  const PilotEnRouteApp({
    super.key,
    this.settings,
    this.logbook,
    this.weather,
    this.practice,
    this.locale,
    this.clock,
  });

  /// Injected in tests; loaded from the device in [main].
  final SettingsStore? settings;
  final LogbookService? logbook;
  final WeatherService? weather;
  final PracticeStore? practice;
  final AglLocaleController? locale;
  final DateTime Function()? clock;

  @override
  State<PilotEnRouteApp> createState() => _PilotEnRouteAppState();
}

class _PilotEnRouteAppState extends State<PilotEnRouteApp> {
  late final SettingsStore _settings = widget.settings ?? SettingsStore();
  late final LogbookService _logbook = widget.logbook ?? LogbookService();
  late final WeatherService _weather = widget.weather ?? WeatherService();
  late final PracticeStore _practice = widget.practice ?? PracticeStore();
  late final AglLocaleController _locale =
      widget.locale ?? AglLocaleController();
  late final ReminderService _reminders =
      ReminderService(settings: _settings, logbook: _logbook, clock: widget.clock);

  @override
  void initState() {
    super.initState();
    _reminders.attach();
    DocumentService.onChanged = () {
      if (_settings.onboardingDone) _reminders.reschedule();
    };
    _logbook.init();
  }

  @override
  void dispose() {
    _reminders.dispose();
    DocumentService.onChanged = null;
    super.dispose();
  }

  static Route<dynamic> panel(Widget w, RouteSettings s) =>
      MaterialPageRoute(settings: s, builder: (_) => PanelTheme(child: w));

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: _settings),
        ChangeNotifierProvider<LogbookService>.value(value: _logbook),
        ChangeNotifierProvider<WeatherService>.value(value: _weather),
        ChangeNotifierProvider<PracticeStore>.value(value: _practice),
        ChangeNotifierProvider<ReminderService>.value(value: _reminders),
        ChangeNotifierProvider<AglLocaleController>.value(value: _locale),
        ChangeNotifierProvider(create: (_) => FlightPlanService()),
        // A process-wide singleton: provided with `.value` so the provider
        // never disposes it.
        ChangeNotifierProvider<AdService>.value(value: AdService()),
      ],
      child: ListenableBuilder(
        listenable: _locale,
        builder: (context, _) => MaterialApp(
          // Twelve languages for the framework and shared strings; `locale`
          // null follows the device unless the user picked one.
          localizationsDelegates: aglLocalizationsDelegates(null),
          supportedLocales: AglLocales.standard,
          locale: _locale.locale,
          title: 'PilotEnRoute',
          debugShowCheckedModeBanner: false,
          theme: buildSkyTheme(Brightness.light),
          darkTheme: buildSkyTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          home: RootGate(clock: widget.clock),
          onGenerateRoute: (s) {
            switch (s.name) {
              case '/e6b':
                return panel(const E6BScreen(), s);
              case '/weight-balance':
                return panel(const WeightBalanceScreen(), s);
              case '/fuel':
                return panel(const FuelScreen(), s);
              case '/flight-plan':
                return panel(const FlightPlanScreen(), s);
              case '/checklist':
                return panel(const ChecklistScreen(), s);
              case '/documents':
                return panel(const DocumentsScreen(), s);
              case '/charts':
                return panel(const ChartsScreen(), s);
              case '/airport':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const AirportScreen());
              case '/settings':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const SettingsScreen());
              case '/minimums':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const MinimumsScreen());
              case '/reminders':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const RemindersScreen());
              case '/history':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const GoHistoryScreen());
              case '/go':
                return MaterialPageRoute(
                    settings: s,
                    builder: (_) => TodayScreen(clock: widget.clock));
              case '/weather':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const WeatherScreen());
            }
            return null;
          },
        ),
      ),
    );
  }
}

/// Onboarding until it is finished once; then Home, on every launch.
class RootGate extends StatelessWidget {
  const RootGate({super.key, this.clock});
  final DateTime Function()? clock;

  /// Every named route the app registers (asserted by the boot test).
  static const routes = <String>[
    '/e6b',
    '/weight-balance',
    '/fuel',
    '/flight-plan',
    '/checklist',
    '/documents',
    '/charts',
    '/airport',
    '/settings',
    '/minimums',
    '/reminders',
    '/history',
    '/go',
    '/weather',
  ];

  @override
  Widget build(BuildContext context) {
    final done = context.watch<SettingsStore>().onboardingDone;
    return done ? AppShell(clock: clock) : const OnboardingScreen();
  }
}
