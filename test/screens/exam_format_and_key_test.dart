/// The knowledge-test practice screen: answer key and test format.
///
/// The offline bank once keyed par_001 (Class E VFR minimums above
/// 10,000 ft MSL) to the wrong option, so students who answered correctly
/// were marked wrong. Each exam card also stated its own format while every
/// test actually ran 60 questions on a 150-minute clock.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/exam_screen.dart';

/// Every number in [text] (e.g. "5", "1,000", "121.5"), as written.
Set<String> _numbers(String text) => RegExp(r'\d[\d,]*(?:\.\d+)?')
    .allMatches(text)
    .map((m) => m.group(0)!.replaceAll(RegExp(r',$'), ''))
    .toSet();

void main() {
  group('offline fallback answer key', () {
    final bank = offlineFallbackExamQuestions();

    test('par_001 is keyed to 5 SM / 1,000 / 1,000 / 1 SM (14 CFR 91.155)',
        () {
      final q = bank.firstWhere((q) => q.id == 'par_001');
      expect(q.options[q.correctIndex], startsWith('5 SM visibility'));
    });

    test('every keyed option is in range', () {
      for (final q in bank) {
        expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1),
            reason: q.id);
      }
    });

    test('every figure in a keyed option appears in its own explanation', () {
      // A keyed option whose numbers contradict the explanation is a wrong
      // key: the explanation is what the student reads as the right answer.
      for (final q in bank) {
        final keyed = _numbers(q.options[q.correctIndex]);
        final explained = _numbers(q.explanation);
        expect(explained.containsAll(keyed), isTrue,
            reason: '${q.id}: keyed option "${q.options[q.correctIndex]}" '
                'has figures ${keyed.difference(explained)} that the '
                'explanation does not support');
      }
    });

    test('question ids are unique', () {
      final ids = bank.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('exam formats', () {
    test('the card table and the runner share one source', () {
      expect(kExamFormats, isNotEmpty);
      for (final entry in kExamFormats.entries) {
        expect(entry.value.questions, greaterThan(0), reason: entry.key);
        expect(entry.value.minutes, greaterThan(0), reason: entry.key);
      }
    });

    test('formats differ per exam instead of a fixed 60 / 150', () {
      expect(kExamFormats['Commercial Pilot (CAX)']!.questions, 100);
      expect(kExamFormats['ATP (ATM)']!.questions, 125);
      expect(kExamFormats['Sport Pilot (SPR)']!.questions, 40);
      expect(kExamFormats['Flight Instructor (FOI)']!.questions, 50);
      expect(
        kExamFormats.values.map((f) => f.minutes).toSet().length,
        greaterThan(1),
      );
    });

    test('a full test gets the full clock', () {
      const f = ExamFormat(questions: 100, minutes: 180);
      expect(f.secondsFor(100), 180 * 60);
      expect(f.secondsFor(150), 180 * 60);
    });

    test('a short test gets a proportional clock, rounded up', () {
      const f = ExamFormat(questions: 60, minutes: 150);
      expect(f.secondsFor(22), (150 * 60 * 22 / 60).ceil());
      expect(f.secondsFor(1), 150);
      expect(f.secondsFor(0), 0);
    });
  });
}
