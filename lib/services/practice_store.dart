import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One answered knowledge-test question.
class PracticeAnswer {
  final String questionId;
  final String topic;
  final bool correct;
  final DateTime at;

  const PracticeAnswer({
    required this.questionId,
    required this.topic,
    required this.correct,
    required this.at,
  });

  Map<String, Object?> toJson() => {
        'q': questionId,
        't': topic,
        'c': correct,
        'at': at.toIso8601String(),
      };

  static PracticeAnswer? fromJson(Object? v) {
    if (v is! Map) return null;
    final q = v['q'], t = v['t'], c = v['c'], at = v['at'];
    if (q is! String || t is! String || c is! bool || at is! String) {
      return null;
    }
    final when = DateTime.tryParse(at);
    if (when == null) return null;
    return PracticeAnswer(questionId: q, topic: t, correct: c, at: when);
  }
}

/// Correct answers out of answered, for one topic.
class TopicScore {
  final String topic;
  final int correct;
  final int answered;
  const TopicScore(this.topic, this.correct, this.answered);
  double get rate => answered == 0 ? 0 : correct / answered;
}

/// The pilot's own practice answers, kept on the device. Readiness and weak
/// areas are worked out from these and nothing else.
class PracticeStore extends ChangeNotifier {
  PracticeStore({List<PracticeAnswer>? answers})
      : _answers = [...?answers];

  static const kAnswers = 'practice_answers_v1';

  /// Readiness is the first-try score, shown once at least this many
  /// different questions have been tried. Only first tries count: a repeat
  /// comes after the explanation, so it measures memory, not knowledge.
  static const readinessMinimum = 10;

  /// The study-plan goal from the founder's starter kit; not an FAA number.
  static const goal = '85–90%';

  /// Kept on the device; older answers are dropped.
  static const maxStored = 2000;

  final List<PracticeAnswer> _answers;

  List<PracticeAnswer> get answers => List.unmodifiable(_answers);

  static Future<PracticeStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kAnswers);
    final list = <PracticeAnswer>[];
    if (raw != null) {
      try {
        final v = jsonDecode(raw);
        if (v is List) {
          list.addAll(v.map(PracticeAnswer.fromJson).whereType<PracticeAnswer>());
        }
      } catch (_) {
        // Unreadable: start empty rather than show invented progress.
      }
    }
    return PracticeStore(answers: list);
  }

  Future<void> record(List<PracticeAnswer> answers) async {
    if (answers.isEmpty) return;
    _answers.addAll(answers);
    if (_answers.length > maxStored) {
      _answers.removeRange(0, _answers.length - maxStored);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        kAnswers, jsonEncode([for (final a in _answers) a.toJson()]));
  }

  Future<void> clear() async {
    _answers.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kAnswers);
  }

  /// Whether the first answer to each question was right, by question id.
  Map<String, bool> get firstTries {
    final first = <String, bool>{};
    for (final a in _answers) {
      first.putIfAbsent(a.questionId, () => a.correct);
    }
    return first;
  }

  /// Different questions answered at least once.
  int get questionsTried => firstTries.length;

  /// Share of questions answered right the first time; null until
  /// [readinessMinimum] different questions have been tried.
  double? get readiness {
    final first = firstTries;
    if (first.length < readinessMinimum) return null;
    return first.values.where((v) => v).length / first.length;
  }

  /// Per topic, over every stored answer, weakest first.
  List<TopicScore> get topicScores {
    final c = <String, int>{}, n = <String, int>{};
    for (final a in _answers) {
      n[a.topic] = (n[a.topic] ?? 0) + 1;
      if (a.correct) c[a.topic] = (c[a.topic] ?? 0) + 1;
    }
    final list = [for (final t in n.keys) TopicScore(t, c[t] ?? 0, n[t]!)]
      ..sort((a, b) {
        final r = a.rate.compareTo(b.rate);
        return r != 0 ? r : a.topic.compareTo(b.topic);
      });
    return list;
  }

  /// Question ids whose most recent answer was wrong.
  Set<String> get missedQuestionIds {
    final last = <String, bool>{};
    for (final a in _answers) {
      last[a.questionId] = a.correct;
    }
    return {
      for (final e in last.entries)
        if (!e.value) e.key
    };
  }
}
