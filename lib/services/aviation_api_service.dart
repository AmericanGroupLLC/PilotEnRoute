import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// RotatePilot API — Free, no auth, CORS enabled
// https://rotatepilot.com/developers
const String _baseUrl = 'https://rotatepilot.com/api/v1';

class AviationQuestion {
  final String id;
  final String subject;
  final String authority;
  final String question;
  final List<QuestionOption> options;
  final int correctAnswer;
  final String explanation;

  AviationQuestion({
    required this.id,
    required this.subject,
    required this.authority,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory AviationQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List? ?? [];
    return AviationQuestion(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      authority: json['authority']?.toString() ?? 'FAA',
      question: json['question']?.toString() ?? '',
      options: rawOptions
          .map((o) => QuestionOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      correctAnswer: (json['correctAnswer'] as num?)?.toInt() ?? 0,
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}

class QuestionOption {
  final String label;
  final String text;
  QuestionOption({required this.label, required this.text});
  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      label: json['label']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}

class AirportInfo {
  final String icao;
  final String iata;
  final String name;
  final String city;
  final String country;
  final double lat;
  final double lon;
  final int elevation;
  final int runways;
  final bool hasTraining;
  final String description;

  AirportInfo({
    required this.icao,
    required this.iata,
    required this.name,
    required this.city,
    required this.country,
    required this.lat,
    required this.lon,
    required this.elevation,
    required this.runways,
    required this.hasTraining,
    required this.description,
  });

  factory AirportInfo.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as Map<String, dynamic>? ?? {};
    return AirportInfo(
      icao: json['icao']?.toString() ?? '',
      iata: json['iata']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      lat: (coords['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (coords['lon'] as num?)?.toDouble() ?? 0.0,
      elevation: (json['elevation'] as num?)?.toInt() ?? 0,
      runways: (json['runways'] as num?)?.toInt() ?? 0,
      hasTraining: json['hasTraining'] as bool? ?? false,
      description: json['description']?.toString() ?? '',
    );
  }
}

class AircraftInfo {
  final String slug;
  final String name;
  final String manufacturer;
  final int engines;
  final int rangeNm;
  final int cruiseSpeedKt;
  final int ceilingFt;
  final double mtowKg;
  final bool typeRatingRequired;

  AircraftInfo({
    required this.slug,
    required this.name,
    required this.manufacturer,
    required this.engines,
    required this.rangeNm,
    required this.cruiseSpeedKt,
    required this.ceilingFt,
    required this.mtowKg,
    required this.typeRatingRequired,
  });

  factory AircraftInfo.fromJson(Map<String, dynamic> json) {
    return AircraftInfo(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      manufacturer: json['manufacturer']?.toString() ?? '',
      engines: (json['engines'] as num?)?.toInt() ?? 1,
      rangeNm: (json['rangeNm'] as num?)?.toInt() ?? 0,
      cruiseSpeedKt: (json['cruiseSpeedKt'] as num?)?.toInt() ?? 0,
      ceilingFt: (json['ceilingFt'] as num?)?.toInt() ?? 0,
      mtowKg: (json['mtowKg'] as num?)?.toDouble() ?? 0.0,
      typeRatingRequired: json['typeRatingRequired'] as bool? ?? false,
    );
  }
}

class GlossaryTerm {
  final String slug;
  final String term;
  final String abbreviation;
  final String category;
  final String definition;
  final List<String> related;

  GlossaryTerm({
    required this.slug,
    required this.term,
    required this.abbreviation,
    required this.category,
    required this.definition,
    required this.related,
  });

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) {
    return GlossaryTerm(
      slug: json['slug']?.toString() ?? '',
      term: json['term']?.toString() ?? '',
      abbreviation: json['abbreviation']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      definition: json['definition']?.toString() ?? '',
      related: (json['related'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class DailyQuote {
  final String text;
  final String author;
  final String date;

  DailyQuote({required this.text, required this.author, required this.date});

  factory DailyQuote.fromJson(Map<String, dynamic> json) {
    return DailyQuote(
      text: json['text']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }
}

class AviationApiService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  DailyQuote? _dailyQuote;
  AviationQuestion? _quizOfDay;
  List<AviationQuestion> _questions = [];
  AirportInfo? _currentAirport;
  AircraftInfo? _currentAircraft;
  GlossaryTerm? _currentGlossaryTerm;

  bool get isLoading => _isLoading;
  String? get error => _error;
  DailyQuote? get dailyQuote => _dailyQuote;
  AviationQuestion? get quizOfDay => _quizOfDay;
  List<AviationQuestion> get questions => _questions;
  AirportInfo? get currentAirport => _currentAirport;
  AircraftInfo? get currentAircraft => _currentAircraft;
  GlossaryTerm? get currentGlossaryTerm => _currentGlossaryTerm;

  static const List<String> subjects = [
    'air-law',
    'airframes-systems',
    'communications',
    'flight-planning',
    'general-navigation',
    'human-performance',
    'instruments',
    'mass-balance',
    'meteorology',
    'operational-procedures',
    'performance',
    'principles-of-flight',
    'radio-navigation',
  ];

  Future<void> fetchDailyQuote() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/quote'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _dailyQuote = DailyQuote.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Quote fetch error: $e');
    }
  }

  Future<void> fetchQuizOfDay() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/quiz-of-day'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['question'] != null) {
          _quizOfDay = AviationQuestion.fromJson(data['question']);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Quiz of day fetch error: $e');
    }
  }

  Future<List<AviationQuestion>> fetchQuestions({
    String? subject,
    int count = 5,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String url = '$_baseUrl/question?count=$count';
      if (subject != null && subject.isNotEmpty) {
        url += '&subject=$subject';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['questions'] as List? ?? [];
        _questions = raw
            .map((q) => AviationQuestion.fromJson(q as Map<String, dynamic>))
            .toList();
        _isLoading = false;
        notifyListeners();
        return _questions;
      }
    } catch (e) {
      _error = 'Failed to load questions: $e';
      debugPrint(_error);
    }
    _isLoading = false;
    notifyListeners();
    return [];
  }

  /// Maps an FAA exam type / certificate to the RotatePilot API subject(s)
  /// most relevant to that test. Matches the exam types defined in
  /// [ExamScreen] (PAR/Private, IRA/Instrument, CAX/Commercial, ATM/ATP,
  /// FOI/CFI, RPA/Remote-Part 107, SPR/Sport). Falls back to a broad,
  /// private-pilot-style spread for anything unrecognized.
  static List<String> subjectsForExamType(String examType) {
    final t = examType.toLowerCase();

    if (t.contains('instrument') || t.contains('ira')) {
      return const [
        'instruments',
        'radio-navigation',
        'meteorology',
        'air-law',
        'flight-planning',
        'general-navigation',
        'communications',
      ];
    }
    if (t.contains('commercial') || t.contains('cax')) {
      return const [
        'air-law',
        'operational-procedures',
        'performance',
        'mass-balance',
        'principles-of-flight',
        'airframes-systems',
        'flight-planning',
        'meteorology',
      ];
    }
    if (t.contains('atp') || t.contains('atm')) {
      // ATP is the most comprehensive test — pull from every subject.
      return subjects;
    }
    if (t.contains('instructor') || t.contains('foi') || t.contains('cfi')) {
      return const [
        'human-performance',
        'principles-of-flight',
        'operational-procedures',
        'air-law',
        'meteorology',
        'performance',
      ];
    }
    if (t.contains('remote') ||
        t.contains('rpa') ||
        t.contains('drone') ||
        t.contains('107')) {
      return const [
        'air-law',
        'operational-procedures',
        'meteorology',
        'human-performance',
        'communications',
      ];
    }
    if (t.contains('sport') || t.contains('spr')) {
      return const [
        'air-law',
        'principles-of-flight',
        'meteorology',
        'operational-procedures',
        'communications',
      ];
    }

    // Private Pilot (PAR) and default.
    return const [
      'air-law',
      'meteorology',
      'principles-of-flight',
      'general-navigation',
      'airframes-systems',
      'human-performance',
      'operational-procedures',
      'communications',
    ];
  }

  /// Fetches a full exam's worth of live questions for [examType].
  ///
  /// Aggregates several per-subject calls against the live RotatePilot API to
  /// reach [count], de-duplicating by question id. Fails gracefully: any
  /// subject request that errors is skipped and whatever was gathered so far
  /// is returned (possibly an empty list, which the caller should treat as
  /// "use the offline fallback bank"). Does not mutate the shared loading/
  /// error/questions state used by [fetchQuestions].
  Future<List<AviationQuestion>> fetchExamQuestions({
    required String examType,
    int count = 60,
  }) async {
    final subjectList = subjectsForExamType(examType);
    if (subjectList.isEmpty || count <= 0) return const [];

    // Request a buffer per subject so the exam can still be filled even if
    // some subject calls fail or return duplicates.
    final perSubject =
        ((count / subjectList.length) * 1.5).ceil().clamp(5, count);

    final collected = <AviationQuestion>[];
    final seenIds = <String>{};

    for (final subject in subjectList) {
      if (collected.length >= count) break;
      try {
        final url = '$_baseUrl/question?count=$perSubject&subject=$subject';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);
        final raw = data['questions'] as List? ?? [];
        for (final q in raw) {
          if (q is! Map<String, dynamic>) continue;
          final parsed = AviationQuestion.fromJson(q);
          // De-dup by id; fall back to a composite key when id is missing.
          final key = parsed.id.isNotEmpty
              ? parsed.id
              : '${parsed.subject}::${parsed.question}';
          if (parsed.question.isEmpty || parsed.options.length < 2) continue;
          if (seenIds.add(key)) {
            collected.add(parsed);
            if (collected.length >= count) break;
          }
        }
      } catch (e) {
        debugPrint('Exam questions fetch error ($subject): $e');
        // Keep going with remaining subjects; return what we have.
      }
    }

    return collected.take(count).toList();
  }

  Future<AirportInfo?> fetchAirport(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$_baseUrl/airport/$code'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentAirport = AirportInfo.fromJson(data);
        _isLoading = false;
        notifyListeners();
        return _currentAirport;
      } else {
        _error = 'Airport not found';
      }
    } catch (e) {
      _error = 'Failed to load airport: $e';
      debugPrint(_error);
    }
    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<AircraftInfo?> fetchAircraft(String slug) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$_baseUrl/aircraft/$slug'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentAircraft = AircraftInfo.fromJson(data);
        _isLoading = false;
        notifyListeners();
        return _currentAircraft;
      } else {
        _error = 'Aircraft not found';
      }
    } catch (e) {
      _error = 'Failed to load aircraft: $e';
      debugPrint(_error);
    }
    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<GlossaryTerm?> fetchGlossaryTerm(String term) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$_baseUrl/glossary/$term'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentGlossaryTerm = GlossaryTerm.fromJson(data);
        _isLoading = false;
        notifyListeners();
        return _currentGlossaryTerm;
      } else {
        _error = 'Term not found';
      }
    } catch (e) {
      _error = 'Failed to load glossary: $e';
      debugPrint(_error);
    }
    _isLoading = false;
    notifyListeners();
    return null;
  }
}
