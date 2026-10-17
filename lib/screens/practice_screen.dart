import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/faa_questions.g.dart';
import '../content/knowledge_question.dart';
import '../services/practice_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'quiz_screen.dart';

/// Practice: knowledge-test questions from the FAA's published Private
/// Pilot-Airplane samples. Readiness and weak areas come only from the
/// pilot's own answers.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key, this.questions = faaSampleQuestions, this.random});

  final List<KnowledgeQuestion> questions;

  /// Injected in tests so the shuffle is repeatable.
  final math.Random? random;

  void _start(BuildContext context, String title, List<KnowledgeQuestion> qs) {
    if (qs.isEmpty) return;
    final list = [...qs]..shuffle(random ?? math.Random());
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizScreen(title: title, questions: list)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PracticeStore>();
    final scheme = Theme.of(context).colorScheme;
    final readiness = store.readiness;
    final missedIds = store.missedQuestionIds;
    final missed = [for (final q in questions) if (missedIds.contains(q.id)) q];
    final byTopic = <String, List<KnowledgeQuestion>>{};
    for (final q in questions) {
      (byTopic[q.topic] ??= []).add(q);
    }
    final topics = byTopic.keys.toList()
      ..sort((a, b) => KnowledgeQuestion.topicName(a)
          .compareTo(KnowledgeQuestion.topicName(b)));
    final scores = {for (final t in store.topicScores) t.topic: t};

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: const PageTitle('Practice',
            subtitle: 'Knowledge test questions from the FAA'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SkyCard(
            key: const Key('practice-readiness'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const IconTile(Icons.quiz_outlined, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Private pilot knowledge test',
                            style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: scheme.onSurface)),
                        Text(
                            readiness == null
                                ? 'Try ${PracticeStore.readinessMinimum} different '
                                    'questions to see your score'
                                : 'First try: ${(readiness * 100).round()}% '
                                    'right on ${store.questionsTried} of '
                                    '${questions.length} questions',
                            style: TextStyle(
                                fontSize: 13, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ]),
                if (readiness != null) ...[
                  const SizedBox(height: 12),
                  ProgressStrip(
                    label: 'Study-plan goal: ${PracticeStore.goal} on first '
                        'tries',
                    trailing: '${(readiness * 100).round()}%',
                    value: readiness,
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('practice-start-all'),
                    onPressed: questions.isEmpty
                        ? null
                        : () => _start(context, 'All questions', questions),
                    child: Text('Practise all ${questions.length} questions'),
                  ),
                ),
                if (missed.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const Key('practice-start-missed'),
                      onPressed: () =>
                          _start(context, 'Missed questions', missed),
                      child: Text('Review ${missed.length} missed'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('By topic',
              subtitle: 'Your correct rate per topic, from your answers'),
          for (final t in topics) ...[
            NavRowCard(
              key: Key('practice-topic-$t'),
              icon: Icons.topic_outlined,
              title: KnowledgeQuestion.topicName(t),
              subtitle: scores[t] == null
                  ? '${byTopic[t]!.length} questions · not tried yet'
                  : '${byTopic[t]!.length} questions · '
                      '${scores[t]!.correct} of ${scores[t]!.answered} '
                      'answers correct',
              onTap: () => _start(
                  context, KnowledgeQuestion.topicName(t), byTopic[t]!),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Text(faaQuestionsSourceNote,
              style: TextStyle(
                  fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
