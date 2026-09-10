import 'package:agl_observability/agl_observability.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
// `show Supabase` keeps the import narrow so it can't clash with the
// `provider` package's `Provider` (both packages export a `Provider` symbol).
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, FlutterAuthClientOptions;

import 'app_env.dart';
import 'services/supabase_config.dart';

import 'services/aviation_api_service.dart';
import 'services/weather_service.dart';
import 'services/news_service.dart';
import 'services/notification_service.dart';
import 'services/logbook_service.dart';
import 'services/flight_plan_service.dart';
import 'services/flight_tracker_service.dart';
import 'services/flashcard_service.dart';
import 'services/premium_service.dart';
import 'services/ad_service.dart';
import 'services/auth_service.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/news_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/airport_screen.dart';
import 'screens/glossary_screen.dart';
import 'screens/simulation_screen.dart';
import 'screens/drone_screen.dart';
import 'screens/garmin_screen.dart';
import 'screens/education_screen.dart';
import 'screens/flashcard_screen.dart';
import 'screens/exam_screen.dart';
import 'screens/logbook_screen.dart';
import 'screens/flight_plan_screen.dart';
import 'screens/flight_tracker_screen.dart';
import 'screens/map_screen.dart';
import 'screens/e6b_screen.dart';
import 'screens/weight_balance_screen.dart';
import 'screens/fuel_screen.dart';
import 'screens/notam_screen.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/account_screen.dart';
import 'screens/debrief_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/integrations_screen.dart';
import 'screens/charts_screen.dart';
import 'screens/wind_screen.dart';
import 'screens/radio_screen.dart';
import 'screens/regulations_screen.dart';
import 'screens/navdb_screen.dart';
import 'screens/endorsements_screen.dart';
import 'screens/career_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/icara_screen.dart';
import 'screens/checklist_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/store_screen.dart';
import 'services/error_reporter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Crash reporting, before anything that could fail. Inactive and
  // harmless until the Firebase config files are added.
  await AglCrash.init(appName: 'PilotEnRoute');
  ErrorReporter.sink = (error, stack, {context}) =>
      AglCrash.recordError(error, stack, reason: context);
  // Capture framework and uncaught async errors. No-op sink by
  // default - see services/error_reporter.dart to attach a crash service.
  ErrorReporter.install();
  // Fail loudly in dev if this binary was built without (or with the wrong)
  // --dart-define-from-file=env/<env>.json. In release this only reports.
  AppEnv.validate(
    supabaseUrl: SupabaseConfig.url,
    supabaseAnonKey: SupabaseConfig.anonKey,
    testAccountEnabled: SupabaseConfig.testAccountEnabled,
  );

  // Initialize the org's Supabase backend before anything reads the client.
  // Wrapped in try/catch so a misconfiguration or offline start can never
  // block app launch — AuthService degrades gracefully (see loginEmail).
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      // AUTO-LOGIN: keep the default persistent, auto-refreshing session so a
      // returning user is signed in on launch with no login screen. The session
      // is stored in the platform-secure local store (Keychain/Keystore) and
      // the access token is refreshed in the background.
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
    );
  } catch (e) {
    debugPrint('Supabase.initialize failed: $e');
  }

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize timezone data for notifications
  tz.initializeTimeZones();

  // Initialize notifications
  await NotificationService.initialize();

  // Initialize AdMob SDK
  await AdService().initialize();

  // Restore any existing AmericanGroupLLC backend session.
  await AuthService.instance.init();

  // Lock orientation to portrait + landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A1628),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const PilotEnRouteApp());
}

class PilotEnRouteApp extends StatelessWidget {
  const PilotEnRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Core Services ─────────────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => AviationApiService()),
        ChangeNotifierProvider(create: (_) => WeatherService()),
        ChangeNotifierProvider(create: (_) => NewsService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => LogbookService()),
        ChangeNotifierProvider(create: (_) => FlightPlanService()),
        ChangeNotifierProvider(create: (_) => FlightTrackerService()),
        ChangeNotifierProvider(create: (_) => FlashcardService()),
        // ── Monetization Services ─────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => PremiumService()),
        ChangeNotifierProvider(create: (_) => AdService()),
        // ── Auth (AmericanGroupLLC backend) — shared singleton ────────────
        ChangeNotifierProvider<AuthService>.value(value: AuthService.instance),
      ],
      child: MaterialApp(
        title: 'PilotEnRoute',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        initialRoute: '/',
        routes: {
          // ── Core Screens ───────────────────────────────────────────────
          // Root gate: shows the login screen until the user signs in (or taps
          // "Continue without signing in"), then the home dashboard.
          '/': (ctx) => const AuthGate(),
          '/login': (ctx) => const LoginScreen(),
          '/home': (ctx) => const HomeScreen(),
          '/weather': (ctx) => const WeatherScreen(),
          '/news': (ctx) => const NewsScreen(),
          '/quiz': (ctx) => const QuizScreen(),
          '/airport': (ctx) => const AirportScreen(),
          '/glossary': (ctx) => const GlossaryScreen(),
          '/simulation': (ctx) => const SimulationScreen(),
          '/drone': (ctx) => const DroneScreen(),
          '/garmin': (ctx) => const GarminScreen(),
          '/education': (ctx) => const EducationScreen(),
          '/flashcards': (ctx) => const FlashcardScreen(),
          '/exam': (ctx) => const ExamScreen(),
          '/logbook': (ctx) => const LogbookScreen(),
          '/flight-plan': (ctx) => const FlightPlanScreen(),
          '/flight-tracker': (ctx) => const FlightTrackerScreen(),
          '/map': (ctx) => const MapScreen(),
          '/e6b': (ctx) => const E6BScreen(),
          '/weight-balance': (ctx) => const WeightBalanceScreen(),
          '/fuel': (ctx) => const FuelScreen(),
          '/notams': (ctx) => const NotamScreen(),
          '/ai': (ctx) => const AiAssistantScreen(),
          '/documents': (ctx) => const DocumentsScreen(),
          '/account': (ctx) => const AccountScreen(),
          '/debrief': (ctx) => const DebriefScreen(),
          '/alerts': (ctx) => const AlertsScreen(),
          '/integrations': (ctx) => const IntegrationsScreen(),
          '/charts': (ctx) => const ChartsScreen(),
          '/wind': (ctx) => const WindScreen(),
          '/radio': (ctx) => const RadioScreen(),
          '/regulations': (ctx) => const RegulationsScreen(),
          '/navdb': (ctx) => const NavDbScreen(),
          '/endorsements': (ctx) => const EndorsementsScreen(),
          '/career': (ctx) => const CareerScreen(),
          '/notifications': (ctx) => const NotificationsScreen(),
          '/icara': (ctx) => const IcaraScreen(),
          '/checklist': (ctx) => const ChecklistScreen(),
          '/emergency': (ctx) => const EmergencyScreen(),
          '/profile': (ctx) => const ProfileScreen(),
          // ── Monetization Screens ───────────────────────────────────────
          '/premium': (ctx) => const PremiumScreen(),
          '/store': (ctx) => const StoreScreen(),
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A1628),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00BCD4),
        secondary: Color(0xFFFFB300),
        surface: Color(0xFF112240),
        error: Color(0xFFF44336),
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0D1B2A),
        selectedItemColor: Color(0xFF00BCD4),
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: const Color(0xFF00BCD4),
        unselectedLabelColor: Colors.white54,
        indicatorColor: const Color(0xFF00BCD4),
        labelStyle: GoogleFonts.orbitron(fontSize: 10, letterSpacing: 1),
        unselectedLabelStyle: GoogleFonts.orbitron(fontSize: 10),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF112240),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BCD4),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF112240),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: Colors.white12, thickness: 1),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.orbitron(color: Colors.white),
        displayMedium: GoogleFonts.orbitron(color: Colors.white),
        displaySmall: GoogleFonts.orbitron(color: Colors.white),
        headlineLarge: GoogleFonts.orbitron(color: Colors.white),
        headlineMedium: GoogleFonts.orbitron(color: Colors.white),
        headlineSmall: GoogleFonts.orbitron(color: Colors.white),
        titleLarge: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: GoogleFonts.inter(
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.inter(color: Colors.white),
        bodyMedium: GoogleFonts.inter(color: Colors.white70),
        bodySmall: GoogleFonts.inter(color: Colors.white54),
        labelLarge: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: GoogleFonts.inter(color: Colors.white70),
        labelSmall: GoogleFonts.inter(color: Colors.white54),
      ),
    );
  }
}
