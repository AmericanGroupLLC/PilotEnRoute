/// Providers and theme around a screen under test, with in-memory stores.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/services/flight_plan_service.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/practice_store.dart';
import 'package:pilot_enroute/services/reminder_service.dart';
import 'package:pilot_enroute/services/settings_store.dart';
import 'package:pilot_enroute/services/weather_service.dart';
import 'package:pilot_enroute/ui/theme.dart';

class Harness {
  Harness(
      {SettingsStore? settings,
      LogbookService? logbook,
      WeatherService? weather,
      PracticeStore? practice})
      : settings = settings ?? SettingsStore(onboardingDone: true),
        logbook = logbook ?? LogbookService(store: MemoryLogbookStore()),
        weather = weather ?? WeatherService(),
        practice = practice ?? PracticeStore();

  final SettingsStore settings;
  final LogbookService logbook;
  final WeatherService weather;
  final PracticeStore practice;

  Widget wrap(Widget child, {double textScale = 1.0, Brightness brightness = Brightness.light}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<LogbookService>.value(value: logbook),
        ChangeNotifierProvider<WeatherService>.value(value: weather),
        ChangeNotifierProvider<PracticeStore>.value(value: practice),
        ChangeNotifierProvider<ReminderService>(
            create: (_) =>
                ReminderService(settings: settings, logbook: logbook)),
        ChangeNotifierProvider(create: (_) => FlightPlanService()),
      ],
      child: MaterialApp(
        theme: buildSkyTheme(brightness),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child,
          ),
        ),
      ),
    );
  }
}
