import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/knowledge_question.dart';
import '../services/practice_store.dart';
import '../ui/status_tag.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// A practice set: one question at a time. Answer, see right or wrong with
/// the FAA text that decides it, then go on. Every answer is saved as it is
/// given, so leaving part-way keeps what was done.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.title, required this.questions, this.clock});

  final String title;
  final List<KnowledgeQuestion> questions;
  final DateTime Function()? clock;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _i = 0;
  int? _picked;
  final _results = <KnowledgeQuestion, bool>{};

  KnowledgeQuestion get _q => widget.questions[_i];
  bool get _done => _i >= widget.questions.length;

  Future<void> _pick(int choice) async {
    if (_picked != null) return;
    final correct = choice == _q.answer;
    setState(() {
      _picked = choice;
      _results[_q] = correct;
    });
    await context.read<PracticeStore>().record([
      PracticeAnswer(
        questionId: _q.id,
        topic: _q.topic,
        correct: correct,
        at: (widget.clock ?? DateTime.now)(),
      ),
    ]);
  }

  void _next() => setState(() {
        _i++;
        _picked = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        title: PageTitle(widget.title,
            subtitle: _done
                ? 'Result'
                : 'Question ${_i + 1} of ${widget.questions.length}'),
      ),
      body: _done ? _result(context) : _question(context),
    );
  }

  Widget _question(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _q;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        ProgressStrip(
          label: KnowledgeQuestion.topicName(q.topic),
          trailing: '${_i + 1}/${widget.questions.length}',
          value: (_i + 1) / widget.questions.length,
        ),
        const SizedBox(height: 6),
        Text('FAA sample ${q.id} · ACS ${q.acsCode}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        SkyCard(
          child: Text(q.stem,
              key: const Key('quiz-stem'),
              style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  height: 1.3,
                  color: scheme.onSurface)),
        ),
        const SizedBox(height: 12),
        for (var c = 0; c < q.choices.length; c++) ...[
          _choice(context, q, c),
          const SizedBox(height: 10),
        ],
        if (_picked != null) ...[
          const SizedBox(height: 4),
          _explanation(context, q),
          const SizedBox(height: 14),
          FilledButton(
            key: const Key('quiz-next'),
            onPressed: _next,
            child: Text(_i + 1 == widget.questions.length
                ? 'See result'
                : 'Next question'),
          ),
        ],
      ],
    );
  }

  Widget _choice(BuildContext context, KnowledgeQuestion q, int c) {
    final scheme = Theme.of(context).colorScheme;
    final answered = _picked != null;
    final isAnswer = c == q.answer;
    final isPicked = c == _picked;
    Tone? tone;
    if (answered && isAnswer) tone = Tone.go;
    if (answered && isPicked && !isAnswer) tone = Tone.stop;
    return SkyCard(
      key: Key('quiz-choice-${KnowledgeQuestion.letters[c]}'),
      onTap: answered ? null : () => _pick(c),
      borderColor: tone == null ? null : toneColor(context, tone),
      color: tone == null ? null : toneSoft(context, tone),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(KnowledgeQuestion.letters[c],
                style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface)),
          ),
          Expanded(
              child: Text(q.choices[c],
                  style: TextStyle(fontSize: 15.5, color: scheme.onSurface))),
          if (tone != null) ...[
            const SizedBox(width: 8),
            StatusTag(
                tone == Tone.go
                    ? const StatusLook('CORRECT', Icons.check_circle, Tone.go)
                    : const StatusLook('YOUR ANSWER', Icons.cancel, Tone.stop),
                dense: true),
          ],
        ],
      ),
    );
  }

  Widget _explanation(BuildContext context, KnowledgeQuestion q) {
    final scheme = Theme.of(context).colorScheme;
    final right = _picked == q.answer;
    return SkyCard(
      key: const Key('quiz-explanation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusTag(right
              ? const StatusLook('RIGHT', Icons.check_circle, Tone.go)
              : StatusLook('WRONG · ANSWER ${KnowledgeQuestion.letters[q.answer]}',
                  Icons.cancel, Tone.stop)),
          const SizedBox(height: 10),
          Text(q.explanation,
              style: TextStyle(fontSize: 15, height: 1.4, color: scheme.onSurface)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: Sky.cornersM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('“${q.quote}”',
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurface)),
                const SizedBox(height: 6),
                Text(q.cite,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _results.length;
    final right = _results.values.where((v) => v).length;
    final pct = total == 0 ? 0 : (right * 100 / total).round();
    final missed = [
      for (final e in _results.entries)
        if (!e.value) e.key
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SkyCard(
          key: const Key('quiz-result'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$right of $total correct · $pct%',
                  style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: scheme.onSurface)),
              const SizedBox(height: 6),
              Text(
                  'Your readiness counts only the first try at each question. '
                  'A practice score does not predict your FAA test result.',
                  style: TextStyle(
                      fontSize: 13.5, height: 1.35, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionHeader('Missed (${missed.length})',
              subtitle: 'Read the cited FAA text, then try again'),
          for (final q in missed) ...[
            SkyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.stem, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                      'Answer ${KnowledgeQuestion.letters[q.answer]}: '
                      '${q.choices[q.answer]} · ${q.cite}',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton(
            key: const Key('quiz-retry-missed'),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => QuizScreen(
                    title: 'Missed questions',
                    questions: missed,
                    clock: widget.clock),
              ),
            ),
            child: const Text('Try the missed ones again'),
          ),
        ],
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
