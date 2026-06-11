import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

class Flashcard {
  final String id;
  final String category;
  final String question;
  final String answer;
  final String? detail;
  final String? reference; // FAA handbook reference
  int reviewCount;
  int correctCount;
  DateTime? lastReviewed;
  bool isStarred;

  Flashcard({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.detail,
    this.reference,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.lastReviewed,
    this.isStarred = false,
  });

  double get accuracy =>
      reviewCount > 0 ? correctCount / reviewCount : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'question': question,
        'answer': answer,
        'detail': detail,
        'reference': reference,
        'reviewCount': reviewCount,
        'correctCount': correctCount,
        'lastReviewed': lastReviewed?.toIso8601String(),
        'isStarred': isStarred,
      };

  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
        id: j['id'],
        category: j['category'],
        question: j['question'],
        answer: j['answer'],
        detail: j['detail'],
        reference: j['reference'],
        reviewCount: j['reviewCount'] ?? 0,
        correctCount: j['correctCount'] ?? 0,
        lastReviewed: j['lastReviewed'] != null
            ? DateTime.parse(j['lastReviewed'])
            : null,
        isStarred: j['isStarred'] ?? false,
      );
}

class FlashcardService extends ChangeNotifier {
  List<Flashcard> _cards = [];
  String _selectedCategory = 'All';
  int _currentIndex = 0;
  bool _isFlipped = false;

  List<Flashcard> get cards => _cards;
  String get selectedCategory => _selectedCategory;
  int get currentIndex => _currentIndex;
  bool get isFlipped => _isFlipped;

  List<String> get categories {
    final cats = {'All', ..._cards.map((c) => c.category)};
    return cats.toList()..sort();
  }

  List<Flashcard> get filteredCards {
    if (_selectedCategory == 'All') return _cards;
    return _cards.where((c) => c.category == _selectedCategory).toList();
  }

  Flashcard? get currentCard {
    final filtered = filteredCards;
    if (filtered.isEmpty || _currentIndex >= filtered.length) return null;
    return filtered[_currentIndex];
  }

  Future<void> loadCards() async {
    _cards = _getBuiltInCards();
    // Load user progress from prefs
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString('flashcard_progress');
      if (progressJson != null) {
        final progress = jsonDecode(progressJson) as Map<String, dynamic>;
        for (final card in _cards) {
          if (progress.containsKey(card.id)) {
            final p = progress[card.id];
            card.reviewCount = p['reviewCount'] ?? 0;
            card.correctCount = p['correctCount'] ?? 0;
            card.isStarred = p['isStarred'] ?? false;
          }
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    _currentIndex = 0;
    _isFlipped = false;
    notifyListeners();
  }

  void flip() {
    _isFlipped = !_isFlipped;
    notifyListeners();
  }

  void next() {
    final filtered = filteredCards;
    if (filtered.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % filtered.length;
    _isFlipped = false;
    notifyListeners();
  }

  void previous() {
    final filtered = filteredCards;
    if (filtered.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + filtered.length) % filtered.length;
    _isFlipped = false;
    notifyListeners();
  }

  void shuffle() {
    _cards.shuffle(Random());
    _currentIndex = 0;
    _isFlipped = false;
    notifyListeners();
  }

  Future<void> markCorrect(String id) async {
    final card = _cards.firstWhere((c) => c.id == id, orElse: () => _cards.first);
    card.reviewCount++;
    card.correctCount++;
    card.lastReviewed = DateTime.now();
    await _saveProgress();
    notifyListeners();
  }

  Future<void> markIncorrect(String id) async {
    final card = _cards.firstWhere((c) => c.id == id, orElse: () => _cards.first);
    card.reviewCount++;
    card.lastReviewed = DateTime.now();
    await _saveProgress();
    notifyListeners();
  }

  Future<void> toggleStar(String id) async {
    final card = _cards.firstWhere((c) => c.id == id, orElse: () => _cards.first);
    card.isStarred = !card.isStarred;
    await _saveProgress();
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final progress = <String, dynamic>{};
    for (final card in _cards) {
      progress[card.id] = {
        'reviewCount': card.reviewCount,
        'correctCount': card.correctCount,
        'isStarred': card.isStarred,
      };
    }
    await prefs.setString('flashcard_progress', jsonEncode(progress));
  }

  List<Flashcard> _getBuiltInCards() {
    return [
      // ── Aerodynamics ──────────────────────────────────────────────────────
      Flashcard(
        id: 'aero_001',
        category: 'Aerodynamics',
        question: 'What are the four forces acting on an aircraft in flight?',
        answer: 'Lift, Weight (Gravity), Thrust, and Drag',
        detail: 'In straight-and-level unaccelerated flight, lift equals weight and thrust equals drag.',
        reference: 'PHAK Chapter 4',
      ),
      Flashcard(
        id: 'aero_002',
        category: 'Aerodynamics',
        question: 'What is angle of attack (AOA)?',
        answer: 'The angle between the chord line of the wing and the relative wind.',
        detail: 'AOA is the primary determinant of lift coefficient. As AOA increases, lift increases until the critical AOA (stall angle) is reached.',
        reference: 'PHAK Chapter 4',
      ),
      Flashcard(
        id: 'aero_003',
        category: 'Aerodynamics',
        question: 'What causes a stall?',
        answer: 'Exceeding the critical angle of attack, causing airflow separation over the wing.',
        detail: 'A stall can occur at any airspeed, any attitude, and any power setting when the critical AOA is exceeded.',
        reference: 'PHAK Chapter 4',
      ),
      Flashcard(
        id: 'aero_004',
        category: 'Aerodynamics',
        question: 'What is Vso?',
        answer: 'Stall speed in landing configuration (flaps down, gear down, power off).',
        detail: 'Vso is the bottom of the white arc on the airspeed indicator.',
        reference: 'PHAK Chapter 8',
      ),
      Flashcard(
        id: 'aero_005',
        category: 'Aerodynamics',
        question: 'What is the load factor in a 60° banked level turn?',
        answer: '2G (twice the aircraft\'s weight)',
        detail: 'Load factor = 1/cos(bank angle). At 60°: 1/cos(60°) = 1/0.5 = 2G. Stall speed increases by √2 ≈ 41%.',
        reference: 'PHAK Chapter 4',
      ),
      Flashcard(
        id: 'aero_006',
        category: 'Aerodynamics',
        question: 'What is ground effect?',
        answer: 'A reduction in induced drag when the aircraft is within one wingspan of the ground.',
        detail: 'Ground effect increases lift and reduces drag, which can cause the aircraft to "float" during landing.',
        reference: 'PHAK Chapter 4',
      ),
      // ── Weather ──────────────────────────────────────────────────────────
      Flashcard(
        id: 'wx_001',
        category: 'Weather',
        question: 'What is a METAR?',
        answer: 'Aviation Routine Weather Report — hourly surface weather observation at an airport.',
        detail: 'Includes wind, visibility, sky condition, temperature, dewpoint, and altimeter setting.',
        reference: 'AIM 7-1-28',
      ),
      Flashcard(
        id: 'wx_002',
        category: 'Weather',
        question: 'What is a TAF?',
        answer: 'Terminal Aerodrome Forecast — weather forecast for a 5 statute mile radius around an airport.',
        detail: 'TAFs are issued 4 times daily and cover a 24-30 hour period.',
        reference: 'AIM 7-1-30',
      ),
      Flashcard(
        id: 'wx_003',
        category: 'Weather',
        question: 'What are the VFR weather minimums in Class G airspace below 1,200 ft AGL during the day?',
        answer: '1 statute mile visibility, clear of clouds.',
        detail: 'At night in Class G below 1,200 ft: 3 SM visibility, 500 ft below, 1,000 ft above, 2,000 ft horizontal from clouds.',
        reference: '14 CFR 91.155',
      ),
      Flashcard(
        id: 'wx_004',
        category: 'Weather',
        question: 'What is a SIGMET?',
        answer: 'Significant Meteorological Information — advisory for hazardous weather affecting all aircraft.',
        detail: 'Issued for severe/extreme turbulence, severe icing, widespread dust/sand storms, volcanic ash.',
        reference: 'AIM 7-1-6',
      ),
      Flashcard(
        id: 'wx_005',
        category: 'Weather',
        question: 'What causes a thunderstorm?',
        answer: 'Three requirements: sufficient moisture, a lifting action, and unstable air.',
        detail: 'Thunderstorms have three stages: cumulus, mature (most dangerous), and dissipating.',
        reference: 'PHAK Chapter 12',
      ),
      // ── Regulations ──────────────────────────────────────────────────────
      Flashcard(
        id: 'reg_001',
        category: 'Regulations',
        question: 'What is the minimum safe altitude over a congested area?',
        answer: '1,000 feet above the highest obstacle within 2,000 feet horizontally.',
        detail: '14 CFR 91.119(b). Over non-congested areas: 500 ft AGL. Over open water/sparsely populated: 500 ft from people/vessels/structures.',
        reference: '14 CFR 91.119',
      ),
      Flashcard(
        id: 'reg_002',
        category: 'Regulations',
        question: 'What documents must be on board the aircraft? (AROW)',
        answer: 'Airworthiness certificate, Registration, Operating handbook (AFM/POH), Weight and balance data.',
        detail: 'Memory aid: AROW — Airworthiness, Registration, Operating limitations, Weight & balance.',
        reference: '14 CFR 91.9, 91.203',
      ),
      Flashcard(
        id: 'reg_003',
        category: 'Regulations',
        question: 'What is the blood alcohol limit for pilots?',
        answer: '0.04% blood alcohol content. No flying within 8 hours of consuming alcohol.',
        detail: '"8 hours bottle to throttle" is the minimum. FAA recommends 24 hours for safety.',
        reference: '14 CFR 91.17',
      ),
      Flashcard(
        id: 'reg_004',
        category: 'Regulations',
        question: 'What is the required equipment for VFR day flight? (ATOMATOFLAMES)',
        answer: 'Airspeed indicator, Tachometer, Oil pressure gauge, Manifold pressure gauge, Altimeter, Temperature gauge (liquid cooled), Oil temperature, Fuel gauge, Landing gear position indicator, Anticollision lights, Magnetic compass, ELT, Safety belts.',
        detail: 'Memory aid: A TOMATO FLAMES',
        reference: '14 CFR 91.205',
      ),
      // ── Navigation ───────────────────────────────────────────────────────
      Flashcard(
        id: 'nav_001',
        category: 'Navigation',
        question: 'What is the difference between true north and magnetic north?',
        answer: 'Magnetic variation (declination) — the angular difference between true and magnetic north at a given location.',
        detail: 'East variation: subtract from true course. West variation: add to true course. "East is least, West is best."',
        reference: 'PHAK Chapter 16',
      ),
      Flashcard(
        id: 'nav_002',
        category: 'Navigation',
        question: 'What is wind correction angle (WCA)?',
        answer: 'The angle between the desired course and the heading required to maintain that course in the presence of wind.',
        detail: 'Calculated using the E6B or flight computer. Heading = Course ± WCA.',
        reference: 'PHAK Chapter 16',
      ),
      Flashcard(
        id: 'nav_003',
        category: 'Navigation',
        question: 'What does ATIS stand for?',
        answer: 'Automatic Terminal Information Service — continuous broadcast of non-control airport information.',
        detail: 'Includes weather, active runways, NOTAMs, and other pertinent information. Updated hourly or when conditions change.',
        reference: 'AIM 4-1-13',
      ),
      // ── Aircraft Systems ─────────────────────────────────────────────────
      Flashcard(
        id: 'sys_001',
        category: 'Aircraft Systems',
        question: 'What is the purpose of the pitot-static system?',
        answer: 'Provides ram air pressure (pitot) and static pressure to operate the airspeed indicator, altimeter, and vertical speed indicator.',
        detail: 'Pitot tube measures impact pressure. Static ports measure ambient atmospheric pressure.',
        reference: 'PHAK Chapter 8',
      ),
      Flashcard(
        id: 'sys_002',
        category: 'Aircraft Systems',
        question: 'How does a gyroscopic instrument work?',
        answer: 'Uses gyroscopic rigidity (precession) to maintain orientation in space.',
        detail: 'Attitude indicator, heading indicator, and turn coordinator use gyroscopes. Can be vacuum or electrically powered.',
        reference: 'PHAK Chapter 8',
      ),
      // ── Airspace ─────────────────────────────────────────────────────────
      Flashcard(
        id: 'air_001',
        category: 'Airspace',
        question: 'What equipment is required to fly in Class B airspace?',
        answer: 'Two-way radio, Mode C transponder, and ATC clearance.',
        detail: 'Class B surrounds the nation\'s busiest airports. Speed limit: 250 KIAS below 10,000 ft MSL, 200 KIAS within 4 NM/2,500 ft of Class B.',
        reference: '14 CFR 91.131',
      ),
      Flashcard(
        id: 'air_002',
        category: 'Airspace',
        question: 'What is a TFR?',
        answer: 'Temporary Flight Restriction — restricts flight in a designated area for safety, security, or national defense.',
        detail: 'TFRs are issued via NOTAM. Common reasons: VIP movement, disaster areas, airshows, sporting events.',
        reference: '14 CFR 91.137-91.145',
      ),
      // ── Emergency Procedures ─────────────────────────────────────────────
      Flashcard(
        id: 'emg_001',
        category: 'Emergency',
        question: 'What is the emergency squawk code?',
        answer: '7700 — General emergency. 7600 — Radio failure. 7500 — Hijacking.',
        detail: 'Memory: 7700 = Heaven (emergency), 7600 = Radio gone (lost comm), 7500 = Taken (hijack).',
        reference: 'AIM 6-3-2',
      ),
      Flashcard(
        id: 'emg_002',
        category: 'Emergency',
        question: 'What is the emergency frequency?',
        answer: '121.5 MHz — International distress frequency (Guard frequency).',
        detail: 'All aircraft should monitor 121.5 MHz when practicable. Military uses 243.0 MHz (UHF Guard).',
        reference: 'AIM 6-3-1',
      ),
      Flashcard(
        id: 'emg_003',
        category: 'Emergency',
        question: 'What is the best glide speed used for?',
        answer: 'Maximum glide distance after engine failure — provides the best lift-to-drag ratio.',
        detail: 'Found in the POH. Flying faster or slower than Vbg reduces glide distance.',
        reference: 'AFH Chapter 17',
      ),
      // ── Drone / Part 107 ─────────────────────────────────────────────────
      Flashcard(
        id: 'drone_001',
        category: 'Part 107 (Drone)',
        question: 'What is the maximum altitude for Part 107 drone operations?',
        answer: '400 feet AGL, or within 400 feet of a structure.',
        detail: 'Waiver required for operations above 400 ft AGL away from structures.',
        reference: '14 CFR 107.51',
      ),
      Flashcard(
        id: 'drone_002',
        category: 'Part 107 (Drone)',
        question: 'What is the maximum groundspeed for Part 107 operations?',
        answer: '100 mph (87 knots)',
        detail: '14 CFR 107.51(a)',
        reference: '14 CFR 107.51',
      ),
      Flashcard(
        id: 'drone_003',
        category: 'Part 107 (Drone)',
        question: 'Can you fly a drone at night under Part 107?',
        answer: 'Yes, but the drone must have anti-collision lighting visible for 3 statute miles.',
        detail: 'Night operations were added without waiver requirement in 2021 final rule.',
        reference: '14 CFR 107.29',
      ),
      // ── Human Factors ────────────────────────────────────────────────────
      Flashcard(
        id: 'hf_001',
        category: 'Human Factors',
        question: 'What does IMSAFE stand for?',
        answer: 'Illness, Medication, Stress, Alcohol, Fatigue, Eating/Emotion',
        detail: 'Personal preflight checklist for pilot fitness. Any "yes" answer should ground the pilot.',
        reference: 'PHAK Chapter 17',
      ),
      Flashcard(
        id: 'hf_002',
        category: 'Human Factors',
        question: 'What is spatial disorientation?',
        answer: 'A state in which the pilot\'s perception of position, attitude, or movement does not correspond to reality.',
        detail: 'Most dangerous in IMC. The leans, graveyard spiral, and Coriolis illusion are common types.',
        reference: 'PHAK Chapter 17',
      ),
      Flashcard(
        id: 'hf_003',
        category: 'Human Factors',
        question: 'What is hypoxia?',
        answer: 'A state of oxygen deficiency in the body sufficient to impair functions of the brain and other organs.',
        detail: 'Symptoms: euphoria, impaired judgment, cyanosis. Supplemental O2 required above 12,500 ft for 30+ min, mandatory above 14,000 ft.',
        reference: 'PHAK Chapter 17',
      ),
      // ── IFR ──────────────────────────────────────────────────────────────
      Flashcard(
        id: 'ifr_001',
        category: 'IFR',
        question: 'What are the IFR currency requirements?',
        answer: '6 instrument approaches, holding procedures, and intercepting/tracking courses within the preceding 6 calendar months.',
        detail: 'If currency lapses, an IPC (Instrument Proficiency Check) with a CFII is required.',
        reference: '14 CFR 61.57(c)',
      ),
      Flashcard(
        id: 'ifr_002',
        category: 'IFR',
        question: 'What is a Decision Altitude (DA)?',
        answer: 'The altitude at which a missed approach must be initiated if the required visual references are not established.',
        detail: 'Used for precision approaches (ILS, LPV). Decision Height (DH) is measured above touchdown zone elevation.',
        reference: 'AIM 5-4-5',
      ),
    ];
  }
}
