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
