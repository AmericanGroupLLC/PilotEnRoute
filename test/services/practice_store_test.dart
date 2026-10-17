/// Readiness (first tries only) and weak areas come only from the pilot's own
/// answers, and survive a relaunch.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/practice_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

PracticeAnswer a(String q, bool ok, {String t = 'airspace', int min = 0}) =>
    PracticeAnswer(
        questionId: q,
        topic: t,
        correct: ok,
        at: DateTime.utc(2026, 10, 17, 12, min));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('no readiness until 10 different questions; then the first-try '
      'rate', () async {
    final s = PracticeStore();
    await s.record([for (var i = 0; i < 9; i++) a('PAR-$i', true)]);
    await s.record([a('PAR-0', true), a('PAR-1', true)]); // repeats
    expect(s.readiness, isNull);
    expect(s.questionsTried, 9);
    await s.record([a('PAR-9', false)]);
    expect(s.readiness, 0.9);
  });

  test('repeating questions after the explanation cannot raise readiness',
      () async {
    final s = PracticeStore();
    await s.record([for (var i = 0; i < 10; i++) a('PAR-$i', false)]);
    await s.record([for (var i = 0; i < 10; i++) a('PAR-$i', true, min: 1)]);
    expect(s.readiness, 0.0);
  });

  test('topic scores, weakest first', () async {
    final s = PracticeStore();
    await s.record([
      a('1', true, t: 'weather'),
      a('2', false, t: 'airspace'),
      a('3', true, t: 'airspace'),
    ]);
    expect(s.topicScores.map((t) => t.topic), ['airspace', 'weather']);
    expect(s.topicScores.first.correct, 1);
    expect(s.topicScores.first.answered, 2);
  });

  test('missed = the latest answer to that question was wrong', () async {
    final s = PracticeStore();
    await s.record([a('1', false), a('2', false), a('1', true, min: 1)]);
    expect(s.missedQuestionIds, {'2'});
  });

  test('answers persist and reload; garbage loads as empty', () async {
    final s = PracticeStore();
    await s.record([a('PAR-04', true)]);
    final again = await PracticeStore.load();
    expect(again.answers.single.questionId, 'PAR-04');
    SharedPreferences.setMockInitialValues({PracticeStore.kAnswers: '{oops'});
    expect((await PracticeStore.load()).answers, isEmpty);
  });

  test('clear forgets everything', () async {
    final s = PracticeStore();
    await s.record([a('1', true)]);
    await s.clear();
    expect(s.answers, isEmpty);
    expect((await PracticeStore.load()).answers, isEmpty);
  });
}
