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
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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
    // For demo, generate fresh notifications based on pilot level
    _notifications = _generateNotifications(_pilotLevel);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> setPilotLevel(PilotLevel level) async {
    _pilotLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pilot_level', level.name);
    _notifications = _generateNotifications(level);
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

  // ─── Generate In-App Notifications Based on Pilot Level ───────────────────
  List<PilotNotification> _generateNotifications(PilotLevel level) {
    final now = DateTime.now();
    final notifications = <PilotNotification>[];

    // Universal notifications for ALL pilots
    notifications.addAll([
      PilotNotification(
        id: 'faa_001',
        title: '🏛️ FAA Safety Alert: SAFO 24001',
        body: 'FAA issues Safety Alert for Operators regarding runway incursion prevention procedures.',
        category: NotificationCategory.faaAlert,
        scheduledDate: now.subtract(const Duration(hours: 2)),
        deepLink: '/education',
      ),
      PilotNotification(
        id: 'quiz_001',
        title: '✈️ Daily Quiz Ready',
        body: 'Today\'s aviation knowledge quiz is ready. Test your understanding of ${_getSubjectForLevel(level)}.',
        category: NotificationCategory.dailyQuiz,
        scheduledDate: now.subtract(const Duration(hours: 1)),
        deepLink: '/quiz',
      ),
      PilotNotification(
        id: 'notam_001',
        title: '📢 NOTAM: KJFK Runway 13L/31R',
        body: 'NOTAM D0123/24: Runway 13L/31R closed 0600-1400Z daily for maintenance. Effective through 30 days.',
        category: NotificationCategory.notam,
        scheduledDate: now.subtract(const Duration(minutes: 30)),
        deepLink: '/airport',
      ),
    ]);

    // Student Pilot notifications
    if (level == PilotLevel.student || level == PilotLevel.sport) {
      notifications.addAll([
        PilotNotification(
          id: 'student_001',
          title: '📚 Student Pilot: Solo Endorsement Requirements',
          body: 'Review the requirements for your first solo flight. Your CFI must provide endorsements per 14 CFR 61.87.',
          category: NotificationCategory.licenseRenewal,
          scheduledDate: now.subtract(const Duration(days: 1)),
          deepLink: '/endorsements',
        ),
        PilotNotification(
          id: 'student_002',
          title: '🩺 Student Pilot Medical Required',
          body: 'You need at least a 3rd Class FAA Medical Certificate before your first solo flight.',
          category: NotificationCategory.medicalReminder,
          scheduledDate: now.subtract(const Duration(days: 2)),
          deepLink: '/notifications',
        ),
      ]);
    }

    // Private Pilot and above
    if ([PilotLevel.private, PilotLevel.instrument, PilotLevel.commercial,
         PilotLevel.cfi, PilotLevel.atp].contains(level)) {
      notifications.addAll([
        PilotNotification(
          id: 'bfr_001',
          title: '📋 Flight Review (BFR) Reminder',
          body: 'Your Biennial Flight Review is due within 60 days. Schedule with a CFI to maintain pilot-in-command privileges.',
          category: NotificationCategory.bfrReminder,
          scheduledDate: now.subtract(const Duration(days: 3)),
          deepLink: '/endorsements',
        ),
        PilotNotification(
          id: 'currency_001',
          title: '🛬 Passenger Currency Check',
          body: 'To carry passengers, you need 3 takeoffs and landings in the last 90 days in the same category/class.',
          category: NotificationCategory.currencyReminder,
          scheduledDate: now.subtract(const Duration(days: 4)),
          deepLink: '/logbook',
        ),
        PilotNotification(
          id: 'medical_001',
          title: '🏥 3rd Class Medical Expiry',
          body: 'Your 3rd Class Medical Certificate expires in 90 days. Under 40: valid 60 months. Over 40: valid 24 months.',
          category: NotificationCategory.medicalReminder,
          scheduledDate: now.subtract(const Duration(days: 5)),
          deepLink: '/notifications',
        ),
        PilotNotification(
          id: 'wings_001',
          title: '🦅 FAA WINGS Program',
          body: 'Complete your FAA WINGS Phase to maintain currency and improve your skills. Visit faasafety.gov.',
          category: NotificationCategory.wingsProgram,
          scheduledDate: now.subtract(const Duration(days: 6)),
          deepLink: '/education',
        ),
      ]);
    }

    // Instrument Rating and above
    if ([PilotLevel.instrument, PilotLevel.commercial,
         PilotLevel.cfi, PilotLevel.atp].contains(level)) {
      notifications.addAll([
        PilotNotification(
          id: 'ifr_001',
          title: '☁️ IFR Currency Reminder',
          body: 'IFR currency requires 6 instrument approaches, holds, and intercepting/tracking in the last 6 months.',
          category: NotificationCategory.ifrCurrency,
          scheduledDate: now.subtract(const Duration(days: 7)),
          deepLink: '/logbook',
        ),
        PilotNotification(
          id: 'ifr_002',
          title: '📡 IPC Reminder',
          body: 'If your IFR currency has lapsed, you need an Instrument Proficiency Check (IPC) with a CFII.',
          category: NotificationCategory.ifrCurrency,
          scheduledDate: now.subtract(const Duration(days: 8)),
          deepLink: '/endorsements',
        ),
      ]);
    }

    // Commercial and above
    if ([PilotLevel.commercial, PilotLevel.cfi, PilotLevel.atp].contains(level)) {
      notifications.addAll([
        PilotNotification(
          id: 'comm_001',
          title: '💼 Commercial Pilot: 1st Class Medical',
          body: 'For commercial operations, you need a 1st Class Medical Certificate valid for 12 months (under 40) or 6 months (40+).',
          category: NotificationCategory.medicalReminder,
          scheduledDate: now.subtract(const Duration(days: 9)),
          deepLink: '/notifications',
        ),
      ]);
    }

    // ATP
    if (level == PilotLevel.atp) {
      notifications.addAll([
        PilotNotification(
          id: 'atp_001',
          title: '✈️ ATP: Recurrent Training Due',
          body: 'Part 121/135 operators require recurrent training every 12 months. Check your training schedule.',
          category: NotificationCategory.licenseRenewal,
          scheduledDate: now.subtract(const Duration(days: 10)),
          deepLink: '/education',
        ),
        PilotNotification(
          id: 'atp_002',
          title: '🏥 1st Class Medical: 6-Month Renewal',
          body: 'Your 1st Class Medical Certificate requires renewal every 6 months for ATP operations.',
          category: NotificationCategory.medicalReminder,
          scheduledDate: now.subtract(const Duration(days: 11)),
          deepLink: '/notifications',
        ),
      ]);
    }

    // Drone Part 107
    if (level == PilotLevel.drone107) {
      notifications.addAll([
        PilotNotification(
          id: 'drone_001',
          title: '🚁 Part 107 Certificate Renewal',
          body: 'Your Remote Pilot Certificate requires recurrent knowledge test every 24 months.',
          category: NotificationCategory.licenseRenewal,
          scheduledDate: now.subtract(const Duration(days: 1)),
          deepLink: '/drone',
        ),
        PilotNotification(
          id: 'drone_002',
          title: '📡 Remote ID Compliance',
          body: 'Ensure your drone has FAA-compliant Remote ID. Required for all operations since September 2023.',
          category: NotificationCategory.faaAlert,
          scheduledDate: now.subtract(const Duration(days: 2)),
          deepLink: '/drone',
        ),
      ]);
    }

    // ICARA notifications for international students
    notifications.add(
      PilotNotification(
        id: 'icara_001',
        title: '🌍 ICARA: International Student Alert',
        body: 'TSA ICARA approval required for non-US citizens training in US-registered aircraft. Check your status.',
        category: NotificationCategory.icara,
        scheduledDate: now.subtract(const Duration(days: 12)),
        deepLink: '/icara',
      ),
    );

    // Sort by date (newest first)
    notifications.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    return notifications;
  }

  String _getSubjectForLevel(PilotLevel level) {
    switch (level) {
      case PilotLevel.student:
      case PilotLevel.sport:
        return 'principles of flight and air law';
      case PilotLevel.private:
        return 'navigation and meteorology';
      case PilotLevel.instrument:
        return 'instrument procedures and radio navigation';
      case PilotLevel.commercial:
        return 'performance and flight planning';
      case PilotLevel.cfi:
        return 'instructional techniques and human performance';
      case PilotLevel.atp:
        return 'ATPL systems and mass & balance';
      case PilotLevel.drone107:
        return 'Part 107 regulations and airspace';
    }
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
