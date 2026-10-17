/// Practice: the FAA sample-question bank, a quiz with the FAA quote behind
/// every answer, saved answers, readiness and missed-question review.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/content/faa_questions.g.dart';
import 'package:pilot_enroute/content/knowledge_question.dart';
import 'package:pilot_enroute/screens/practice_screen.dart';
import 'package:pilot_enroute/screens/quiz_screen.dart';
import 'package:pilot_enroute/services/practice_store.dart';

import '../support/harness.dart';

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
}

void main() {
  final q = faaSampleQuestions.first;
  final wrong = (q.answer + 1) % 3;

  testWidgets('the hub lists every question and each topic in the bank',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(Harness().wrap(const PracticeScreen()));
    expect(find.text('Practise all ${faaSampleQuestions.length} questions'),
        findsOneWidget);
    for (final t in faaSampleQuestions.map((q) => q.topic).toSet()) {
      expect(find.byKey(Key('practice-topic-$t')), findsOneWidget, reason: t);
    }
    expect(find.text('Try 10 different questions to see your score'),
        findsOneWidget);
    expect(find.textContaining('publishes no answer key'), findsOneWidget);
  });

  testWidgets('a right answer: RIGHT, the explanation, the FAA quote and cite',
      (tester) async {
    tall(tester);
    final h = Harness();
    await tester.pumpWidget(h.wrap(QuizScreen(title: 'T', questions: [q])));
    expect(find.text(q.stem), findsOneWidget);
    await tester.tap(find.byKey(Key('quiz-choice-${KnowledgeQuestion.letters[q.answer]}')));
    await tester.pumpAndSettle();
    expect(find.text('RIGHT'), findsOneWidget);
    expect(find.text('CORRECT'), findsOneWidget);
    expect(find.text(q.explanation), findsOneWidget);
    expect(find.text('“${q.quote}”'), findsOneWidget);
    expect(find.text(q.cite), findsOneWidget);
    expect(h.practice.answers.single.correct, isTrue);
    expect(h.practice.answers.single.questionId, q.id);
  });

  testWidgets('a wrong answer names the right letter; choices lock',
      (tester) async {
    tall(tester);
    final h = Harness();
    await tester.pumpWidget(h.wrap(QuizScreen(title: 'T', questions: [q])));
    await tester.tap(find.byKey(Key('quiz-choice-${KnowledgeQuestion.letters[wrong]}')));
    await tester.pumpAndSettle();
    expect(find.text('WRONG · ANSWER ${KnowledgeQuestion.letters[q.answer]}'),
        findsOneWidget);
    expect(find.text('YOUR ANSWER'), findsOneWidget);
    await tester.tap(find.byKey(Key('quiz-choice-${KnowledgeQuestion.letters[q.answer]}')));
    await tester.pumpAndSettle();
    expect(h.practice.answers, hasLength(1));
    expect(h.practice.missedQuestionIds, {q.id});
  });

  testWidgets('the result counts the set and offers the missed ones again',
      (tester) async {
    tall(tester);
    final two = faaSampleQuestions.take(2).toList();
    await tester.pumpWidget(Harness().wrap(QuizScreen(title: 'T', questions: two)));
    for (final x in two) {
      await tester.tap(find.byKey(Key('quiz-choice-${KnowledgeQuestion.letters[(x.answer + 1) % 3]}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quiz-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('0 of 2 correct · 0%'), findsOneWidget);
    expect(find.text('Missed (2)'), findsOneWidget);
    expect(find.textContaining('only the first try'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quiz-retry-missed')));
    await tester.pumpAndSettle();
    expect(find.text('Missed questions'), findsOneWidget);
  });

  testWidgets('readiness and review-missed appear from saved answers',
      (tester) async {
    tall(tester);
    final store = PracticeStore(answers: [
      for (final (i, x) in faaSampleQuestions.take(10).indexed)
        PracticeAnswer(
            questionId: x.id,
            topic: x.topic,
            correct: i != 0,
            at: DateTime.utc(2026, 10, 17)),
    ]);
    await tester.pumpWidget(Harness(practice: store)
        .wrap(PracticeScreen(random: math.Random(1))));
    expect(
        find.text('First try: 90% right on 10 of '
            '${faaSampleQuestions.length} questions'),
        findsOneWidget);
    expect(find.text('Review 1 missed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice-start-missed')));
    await tester.pumpAndSettle();
    expect(find.text(faaSampleQuestions.first.stem), findsOneWidget);
  });
}
