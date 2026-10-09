import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// PilotEnRoute Notification Service
/// Handles all pilot-level notifications:
///   - FAA regulatory alerts
///   - License renewal reminders
///   - FAA Medical certificate reminders
///   - Currency requirements (takeoffs/landings)
///   - BFR / Flight Review reminders
///   - IFR currency
///   - WINGS program
///   - New FAA NOTAMs
///   - International student (ICARA) alerts
///   - Daily quiz reminders
///   - Weather briefing reminders

enum PilotLevel {
  student,
  sport,
  private,
  instrument,
  commercial,
  cfi,
  atp,
  drone107,
}

enum NotificationCategory {
  faaAlert,
  medicalReminder,
  licenseRenewal,
  currencyReminder,
  bfrReminder,
  ifrCurrency,
  wingsProgram,
  notam,
  icara,
  dailyQuiz,
  weatherBriefing,
  flightPlan,
  logbook,
}

class PilotNotification {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime scheduledDate;
  final bool isRead;
  final String? deepLink;

  PilotNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.scheduledDate,
    this.isRead = false,
    this.deepLink,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category.name,
        'scheduledDate': scheduledDate.toIso8601String(),
        'isRead': isRead,
        'deepLink': deepLink,
      };

  factory PilotNotification.fromJson(Map<String, dynamic> json) {
    return PilotNotification(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      category: NotificationCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => NotificationCategory.faaAlert,
      ),
      scheduledDate: DateTime.parse(json['scheduledDate']),
      isRead: json['isRead'] ?? false,
      deepLink: json['deepLink'],
    );
  }
}

class NotificationService extends ChangeNotifier {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  List<PilotNotification> _notifications = [];
  PilotLevel _pilotLevel = PilotLevel.private;
  int _unreadCount = 0;

  List<PilotNotification> get notifications => _notifications;
  PilotLevel get pilotLevel => _pilotLevel;
  int get unreadCount => _unreadCount;

  // ─── Static Initialization ─────────────────────────────────────────────────
  /// Sets the plugin up. Deliberately does **not** ask for permission.
  ///
  /// This is awaited by `main()` before `runApp()`. With the three
  /// `request*Permission` flags set, `_plugin.initialize` calls iOS's
  /// `requestAuthorization` and does not return until the user answers the
  /// system alert — so on a clean install the app painted nothing at all, and
  /// an unanswered alert meant it never launched. Verified on a freshly
  /// erased iPhone 17 Pro Max simulator: "PilotEnRoute Would Like to Send You
  /// Notifications" over a black screen, and `runApp()` never reached.
  ///
  /// Asking at cold start is also the wrong moment on its own terms: the user
  /// has not seen the app yet, so the one prompt iOS ever gives is spent with
  /// no context. Call [requestPermissions] from the place that actually needs
  /// alerts instead.
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels (Android)
    await _createNotificationChannels();
  }

  /// Asks for notification permission, at a moment the user is expecting it.
  ///
  /// Returns whether alerts may now be posted. Safe to call more than once:
  /// iOS shows the system alert only for the first request and afterwards
  /// answers from the stored decision.
  static Future<bool> requestPermissions() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static Future<void> _createNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'faa_alerts',
        'FAA Alerts',
        description: 'Critical FAA regulatory alerts and NOTAMs',
        importance: Importance.max,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'medical_reminders',
        'Medical Reminders',
        description: 'FAA Medical certificate renewal reminders',
        importance: Importance.high,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'currency_reminders',
        'Currency Reminders',
        description: 'Pilot currency and BFR reminders',
        importance: Importance.high,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'daily_training',
        'Daily Training',
        description: 'Daily quiz and training reminders',
        importance: Importance.defaultImportance,
        playSound: false,
      ),
      AndroidNotificationChannel(
        'flight_alerts',
        'Flight Alerts',
        description: 'Flight plan and weather alerts',
        importance: Importance.high,
        playSound: true,
      ),
    ];

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in channels) {
      await androidPlugin?.createNotificationChannel(channel);
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Deep link handling would go here
  }

  // ─── Instance Methods ──────────────────────────────────────────────────────
  Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final level = prefs.getString('pilot_level') ?? 'private';
    _pilotLevel = PilotLevel.values.firstWhere(
      (e) => e.name == level,
      orElse: () => PilotLevel.private,
    );

    // Load saved notifications (reserved for future persistence)
    // ignore: unused_local_variable
    final saved = prefs.getStringList('notifications') ?? [];
    // No invented feed: in-app notifications are empty until real items
    // (stored dates, fetched NOTAMs) are wired in.
    _notifications = [];
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> setPilotLevel(PilotLevel level) async {
    _pilotLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pilot_level', level.name);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = PilotNotification(
        id: _notifications[index].id,
        title: _notifications[index].title,
        body: _notifications[index].body,
        category: _notifications[index].category,
        scheduledDate: _notifications[index].scheduledDate,
        isRead: true,
        deepLink: _notifications[index].deepLink,
      );
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications
        .map((n) => PilotNotification(
              id: n.id,
              title: n.title,
              body: n.body,
              category: n.category,
              scheduledDate: n.scheduledDate,
              isRead: true,
              deepLink: n.deepLink,
            ))
        .toList();
    _unreadCount = 0;
    notifyListeners();
  }

  // ─── Schedule Real Local Notifications ─────────────────────────────────────
  Future<void> scheduleDailyQuizReminder() async {
    await _plugin.zonedSchedule(
      1001,
      '✈️ Daily Aviation Quiz',
      'Keep your knowledge sharp — complete today\'s ATPL quiz!',
      _nextInstanceOfTime(8, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_training',
          'Daily Training',
          channelDescription: 'Daily quiz and training reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'daily_training',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleMedicalReminder(DateTime expiryDate) async {
    // 90 days before
    final reminderDate = expiryDate.subtract(const Duration(days: 90));
    if (reminderDate.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        2001,
        '🏥 FAA Medical Certificate Expiring',
        'Your FAA Medical Certificate expires in 90 days. Schedule your AME appointment now.',
        tz.TZDateTime.from(reminderDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medical_reminders',
            'Medical Reminders',
            channelDescription: 'FAA Medical certificate renewal reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> scheduleBFRReminder(DateTime lastBFR) async {
    // BFR required every 24 calendar months
    final nextBFR = DateTime(lastBFR.year + 2, lastBFR.month, lastBFR.day);
    final reminderDate = nextBFR.subtract(const Duration(days: 60));
    if (reminderDate.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        3001,
        '📋 Flight Review (BFR) Due Soon',
        'Your Biennial Flight Review is due in 60 days. Schedule with a CFI to maintain currency.',
        tz.TZDateTime.from(reminderDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'currency_reminders',
            'Currency Reminders',
            channelDescription: 'Pilot currency and BFR reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> sendImmediateNotification({
    required String title,
    required String body,
    required String channelId,
    int id = 9999,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // ─── Medical Doctor Finder (AME) ───────────────────────────────────────────
  static const List<Map<String, String>> ameResources = [
    {
      'title': 'FAA AME Locator',
      'desc': 'Find an FAA Aviation Medical Examiner near you',
      'url': 'https://designee.faa.gov/designeeLocator',
    },
    {
      'title': 'FAA MedXPress',
      'desc': 'Complete your FAA medical application online before your exam',
      'url': 'https://medxpress.faa.gov',
    },
    {
      'title': 'BasicMed Program',
      'desc': 'Alternative to 3rd Class Medical for private pilots',
      'url': 'https://www.faa.gov/licenses_certificates/airmen_certification/basic_med',
    },
    {
      'title': 'AOPA Medical Services',
      'desc': 'AOPA medical certification services and advocacy',
      'url': 'https://www.aopa.org/go-fly/medical-resources',
    },
  ];

  // ─── Medical Class Requirements ───────────────────────────────────────────
  static const Map<String, Map<String, dynamic>> medicalClasses = {
    '1st Class': {
      'required_for': 'ATP, Airline Transport Pilot operations',
      'validity_under_40': '12 months',
      'validity_over_40': '6 months',
      'requirements': [
        'Vision: 20/20 or correctable to 20/20',
        'Near vision: 20/40 or better',
        'Color vision: Distinguish aviation signal colors',
        'Hearing: Conversational voice test',
        'No disqualifying conditions',
      ],
    },
    '2nd Class': {
      'required_for': 'Commercial Pilot operations',
      'validity_under_40': '12 months',
      'validity_over_40': '12 months',
      'requirements': [
        'Vision: 20/20 or correctable to 20/20',
        'Near vision: 20/40 or better',
        'Color vision: Distinguish aviation signal colors',
        'Hearing: Conversational voice test',
      ],
    },
    '3rd Class': {
      'required_for': 'Private, Recreational, Student Pilot',
      'validity_under_40': '60 months',
      'validity_over_40': '24 months',
      'requirements': [
        'Vision: 20/40 or correctable to 20/40',
        'Near vision: 20/40 or better',
        'Color vision: Distinguish aviation signal colors',
        'Hearing: Conversational voice test',
      ],
    },
  };
}
