import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import '../services/aviation_api_service.dart';

class ExamQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String reference;
  final String category;

  ExamQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.reference,
    required this.category,
  });
}

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  bool _examStarted = false;
  bool _examFinished = false;
  bool _isLoading = false;
  bool _usingOfflineBank = false;
  int _currentQuestion = 0;
  int _score = 0;
  int _timeLeft = 0;
  Timer? _timer;
  List<int?> _selectedAnswers = [];
  List<ExamQuestion> _questions = [];
  String _selectedExamType = 'Private Pilot (PAR)';
  late ConfettiController _confettiController;

  final List<String> _examTypes = [
    'Private Pilot (PAR)',
    'Instrument Rating (IRA)',
    'Commercial Pilot (CAX)',
    'Flight Instructor (FOI)',
    'ATP (ATM)',
    'Remote Pilot (RPA) - Part 107',
    'Sport Pilot (SPR)',
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _startExam() {
    // FAA standard full exam: 60 questions, 150-minute timer.
    _prepareExam(limit: 60, timed: true);
  }

  void _startQuickQuiz() {
    // Quick quiz mode: 10 questions, no timer.
    _prepareExam(limit: 10, timed: false);
  }

  /// Loads questions for the selected exam from the live API, falling back to
  /// the offline bank when the API returns nothing. Shows a loading state
  /// while fetching and never crashes on empty/failed fetches.
  Future<void> _prepareExam({required int limit, required bool timed}) async {
    _timer?.cancel();
    setState(() {
      _isLoading = true;
      _usingOfflineBank = false;
    });

    List<ExamQuestion> loaded = [];
    try {
      final api = context.read<AviationApiService>();
      final apiQuestions = await api.fetchExamQuestions(
        examType: _selectedExamType,
        count: limit,
      );
      loaded = apiQuestions
          .map(_mapApiQuestion)
          .where((q) => q.options.length >= 2 && q.question.isNotEmpty)
          .toList();
    } catch (e) {
      loaded = [];
    }

    if (!mounted) return;

    bool usedFallback = false;
    if (loaded.isEmpty) {
      // Offline fallback bank — used ONLY when the live API returns nothing
      // (no network, API down, or empty response). See
      // [_getOfflineFallbackQuestions].
      loaded = _getOfflineFallbackQuestions(_selectedExamType);
      usedFallback = true;
    }

    loaded.shuffle(Random());
    loaded = loaded.take(limit).toList();

    setState(() {
      _questions = loaded;
      _selectedAnswers = List.filled(_questions.length, null);
      _currentQuestion = 0;
      _score = 0;
      _timeLeft = timed ? 150 * 60 : 999999; // 150 minutes (FAA standard)
      _examStarted = true;
      _examFinished = false;
      _isLoading = false;
      _usingOfflineBank = usedFallback;
    });

    if (timed) _startTimer();
  }

  /// Converts a live [AviationQuestion] into the local [ExamQuestion] model,
  /// guarding against out-of-range indices and empty fields.
  ExamQuestion _mapApiQuestion(AviationQuestion q) {
    final opts = q.options
        .map((o) => o.text)
        .where((t) => t.isNotEmpty)
        .toList();
    var correct = q.correctAnswer;
    if (correct < 0 || correct >= opts.length) correct = 0;
    return ExamQuestion(
      id: q.id.isNotEmpty ? q.id : 'api_${q.question.hashCode}',
      question: q.question,
      options: opts,
      correctIndex: correct,
      explanation:
          q.explanation.isNotEmpty ? q.explanation : 'No explanation provided.',
      reference: q.authority.isNotEmpty ? q.authority : 'FAA',
      category: _prettySubject(q.subject),
    );
  }

  String _prettySubject(String subject) {
    if (subject.isEmpty) return 'General';
    return subject
        .split('-')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 0) {
        t.cancel();
        _finishExam();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _selectAnswer(int index) {
    if (_selectedAnswers[_currentQuestion] != null) return;
    setState(() {
      _selectedAnswers[_currentQuestion] = index;
    });
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() => _currentQuestion++);
    } else {
      _finishExam();
    }
  }

  void _finishExam() {
    _timer?.cancel();
    _score = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctIndex) _score++;
    }
    final percentage = (_score / _questions.length * 100).round();
    if (percentage >= 70) _confettiController.play();
    setState(() => _examFinished = true);
  }

  String get _timeString {
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();
    if (!_examStarted) return _buildExamSelector();
    if (_examFinished) return _buildResults();
    return _buildExamUI();
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text('FAA KNOWLEDGE TESTS')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF00BCD4)),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading live question bank…',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedExamType,
              style: GoogleFonts.orbitron(
                fontSize: 11,
                color: const Color(0xFF00BCD4),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamSelector() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text('FAA KNOWLEDGE TESTS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FAA KNOWLEDGE TEST PREP',
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Practice with a live FAA-style question bank. '
                    '60 questions · 150 minutes · 70% passing score.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SELECT EXAM TYPE',
              style: GoogleFonts.orbitron(
                fontSize: 11,
                color: const Color(0xFF00BCD4),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            ...(_examTypes.map((type) {
              final selected = _selectedExamType == type;
              final info = _getExamInfo(type);
              return GestureDetector(
                onTap: () => setState(() => _selectedExamType = type),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF00BCD4).withValues(alpha: 0.15)
                        : const Color(0xFF112240),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF00BCD4)
                          : Colors.white12,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (info['color'] as Color).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          info['icon'] as IconData,
                          color: info['color'] as Color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              info['desc'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle,
                            color: Color(0xFF00BCD4), size: 22),
                    ],
                  ),
                ),
              );
            })),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startExam,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'START EXAM',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _startQuickQuiz,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB300),
                  side: const BorderSide(color: Color(0xFFFFB300)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'QUICK QUIZ (10 QUESTIONS)',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamUI() {
    final q = _questions[_currentQuestion];
    final answered = _selectedAnswers[_currentQuestion];

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: Text(
          'Q ${_currentQuestion + 1} / ${_questions.length}',
          style: GoogleFonts.orbitron(fontSize: 13),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _timeLeft < 300
                  ? const Color(0xFFF44336).withValues(alpha: 0.2)
                  : const Color(0xFF112240),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _timeLeft < 300
                    ? const Color(0xFFF44336)
                    : Colors.white24,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 14,
                  color: _timeLeft < 300
                      ? const Color(0xFFF44336)
                      : Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  _timeString,
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    color: _timeLeft < 300
                        ? const Color(0xFFF44336)
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress
          LinearProgressIndicator(
            value: (_currentQuestion + 1) / _questions.length,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF00BCD4)),
            minHeight: 3,
          ),
          if (_usingOfflineBank)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFB300).withValues(alpha: 0.12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off,
                      size: 14, color: Color(0xFFFFB300)),
                  const SizedBox(width: 6),
                  Text(
                    'Offline practice bank (live questions unavailable)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFFFB300),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF3F51B5)),
                    ),
                    child: Text(
                      q.category.toUpperCase(),
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        color: const Color(0xFF7986CB),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Question
                  Text(
                    q.question,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Options
                  ...q.options.asMap().entries.map((entry) {
                    final i = entry.key;
                    final opt = entry.value;
                    Color borderColor = Colors.white24;
                    Color bgColor = const Color(0xFF112240);
                    Color textColor = Colors.white;
                    IconData? trailingIcon;
                    Color? iconColor;

                    if (answered != null) {
                      if (i == q.correctIndex) {
                        borderColor = const Color(0xFF4CAF50);
                        bgColor = const Color(0xFF4CAF50).withValues(alpha: 0.1);
                        trailingIcon = Icons.check_circle;
                        iconColor = const Color(0xFF4CAF50);
                      } else if (i == answered && answered != q.correctIndex) {
                        borderColor = const Color(0xFFF44336);
                        bgColor = const Color(0xFFF44336).withValues(alpha: 0.1);
                        trailingIcon = Icons.cancel;
                        iconColor = const Color(0xFFF44336);
                        textColor = Colors.white54;
                      } else {
                        textColor = Colors.white38;
                      }
                    } else if (answered == i) {
                      borderColor = const Color(0xFF00BCD4);
                      bgColor = const Color(0xFF00BCD4).withValues(alpha: 0.1);
                    }

                    return GestureDetector(
                      onTap: answered == null ? () => _selectAnswer(i) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor),
                                color: bgColor,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + i),
                                  style: GoogleFonts.orbitron(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: borderColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                opt,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: textColor,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (trailingIcon != null)
                              Icon(trailingIcon, color: iconColor, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                  // Explanation (shown after answering)
                  if (answered != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3F51B5).withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Color(0xFF7986CB), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'EXPLANATION',
                                style: GoogleFonts.orbitron(
                                  fontSize: 9,
                                  color: const Color(0xFF7986CB),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            q.explanation,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reference: ${q.reference}',
                            style: GoogleFonts.orbitron(
                              fontSize: 9,
                              color: Colors.white38,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Bottom navigation
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0D1B2A),
            child: Row(
              children: [
                if (_currentQuestion > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _currentQuestion--),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Icon(Icons.arrow_back),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: answered != null ? _nextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentQuestion == _questions.length - 1
                        ? 'FINISH'
                        : 'NEXT',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final percentage = (_score / _questions.length * 100).round();
    final passed = percentage >= 70;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Score circle
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: passed
                          ? [const Color(0xFF4CAF50).withValues(alpha: 0.3), const Color(0xFF4CAF50).withValues(alpha: 0.05)]
                          : [const Color(0xFFF44336).withValues(alpha: 0.3), const Color(0xFFF44336).withValues(alpha: 0.05)],
                    ),
                    border: Border.all(
                      color: passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$percentage%',
                        style: GoogleFonts.orbitron(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                        ),
                      ),
                      Text(
                        passed ? 'PASSED' : 'FAILED',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          color: passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  passed ? '🎉 Congratulations!' : '📚 Keep Studying',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  passed
                      ? 'You\'re ready for the real FAA knowledge test!'
                      : 'Review the topics you missed and try again.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Stats grid
                Row(
                  children: [
                    _resultStat('Correct', '$_score', const Color(0xFF4CAF50)),
                    _resultStat('Incorrect', '${_questions.length - _score}', const Color(0xFFF44336)),
                    _resultStat('Total', '${_questions.length}', const Color(0xFF00BCD4)),
                  ],
                ),
                const SizedBox(height: 32),
                // Category breakdown
                Text(
                  'CATEGORY BREAKDOWN',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    color: const Color(0xFF00BCD4),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                ..._getCategoryBreakdown().entries.map((e) {
                  final catScore = e.value['correct']! / e.value['total']!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            e.key,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: catScore,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation(
                                catScore >= 0.7
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFF44336),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(catScore * 100).round()}%',
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            color: catScore >= 0.7
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFF44336),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() {
                      _examStarted = false;
                      _examFinished = false;
                    }),
                    child: Text(
                      'TRY AGAIN',
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFF00BCD4),
                Color(0xFFFFB300),
                Color(0xFF4CAF50),
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.orbitron(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Map<String, int>> _getCategoryBreakdown() {
    final breakdown = <String, Map<String, int>>{};
    for (int i = 0; i < _questions.length; i++) {
      final cat = _questions[i].category;
      breakdown.putIfAbsent(cat, () => {'correct': 0, 'total': 0});
      breakdown[cat]!['total'] = breakdown[cat]!['total']! + 1;
      if (_selectedAnswers[i] == _questions[i].correctIndex) {
        breakdown[cat]!['correct'] = breakdown[cat]!['correct']! + 1;
      }
    }
    return breakdown;
  }

  Map<String, dynamic> _getExamInfo(String type) {
    final infos = {
      'Private Pilot (PAR)': {'icon': Icons.flight, 'color': const Color(0xFF4CAF50), 'desc': '60 questions · 150 min · 70% passing'},
      'Instrument Rating (IRA)': {'icon': Icons.cloud, 'color': const Color(0xFF2196F3), 'desc': '60 questions · 150 min · 70% passing'},
      'Commercial Pilot (CAX)': {'icon': Icons.star, 'color': const Color(0xFFFFB300), 'desc': '100 questions · 180 min · 70% passing'},
      'Flight Instructor (FOI)': {'icon': Icons.person_pin, 'color': const Color(0xFFFF9800), 'desc': '50 questions · 150 min · 70% passing'},
      'ATP (ATM)': {'icon': Icons.workspace_premium, 'color': const Color(0xFFF44336), 'desc': '125 questions · 180 min · 70% passing'},
      'Remote Pilot (RPA) - Part 107': {'icon': Icons.flight_takeoff, 'color': const Color(0xFF009688), 'desc': '60 questions · 120 min · 70% passing'},
      'Sport Pilot (SPR)': {'icon': Icons.paragliding, 'color': const Color(0xFF8BC34A), 'desc': '40 questions · 90 min · 70% passing'},
    };
    return infos[type] ?? {'icon': Icons.quiz, 'color': const Color(0xFF00BCD4), 'desc': '60 questions · 150 min'};
  }

  // ---------------------------------------------------------------------------
  // OFFLINE FALLBACK BANK
  //
  // These hardcoded questions are used ONLY when the live API
  // (AviationApiService.fetchExamQuestions) returns nothing — e.g. the device
  // is offline or the RotatePilot API is unavailable. Under normal, online
  // operation the exam is populated from the live question bank and these are
  // never shown. They are intentionally general FAA-knowledge questions so the
  // app remains usable for any selected exam type while offline.
  // ---------------------------------------------------------------------------
  List<ExamQuestion> _getOfflineFallbackQuestions(String examType) {
    return [
      ExamQuestion(
        id: 'par_001',
        question: 'What is the minimum visibility and cloud clearance required for VFR flight in Class E airspace at 10,500 feet MSL?',
        options: [
          '1 SM visibility; 500 ft below, 1,000 ft above, 2,000 ft horizontal',
          '3 SM visibility; 500 ft below, 1,000 ft above, 2,000 ft horizontal',
          '5 SM visibility; 1,000 ft below, 1,000 ft above, 1 SM horizontal',
        ],
        correctIndex: 1,
        explanation: 'Above 10,000 ft MSL in Class E airspace, VFR minimums are 5 SM visibility and 1,000 ft below, 1,000 ft above, 1 SM horizontal from clouds.',
        reference: '14 CFR 91.155',
        category: 'Airspace',
      ),
      ExamQuestion(
        id: 'par_002',
        question: 'During a night flight, you observe a red light on the right and a white light on the tail of another aircraft. What is the relative position of the other aircraft?',
        options: [
          'The aircraft is flying toward you from your left',
          'The aircraft is flying away from you',
          'The aircraft is crossing from right to left',
        ],
        correctIndex: 2,
        explanation: 'Red light = port (left) side. White = tail. If you see a red light on your right, the aircraft\'s left side is facing you, meaning it is crossing from right to left.',
        reference: '14 CFR 91.209',
        category: 'Navigation',
      ),
      ExamQuestion(
        id: 'par_003',
        question: 'What is the maximum speed for aircraft in Class B airspace?',
        options: [
          '200 KIAS',
          '250 KIAS',
          '156 KIAS',
        ],
        correctIndex: 1,
        explanation: '250 KIAS below 10,000 ft MSL per 14 CFR 91.117. Within 4 NM and 2,500 ft of Class B, the limit is 200 KIAS.',
        reference: '14 CFR 91.117',
        category: 'Airspace',
      ),
      ExamQuestion(
        id: 'par_004',
        question: 'What is the stall speed of an aircraft in a 60° banked level turn compared to wings-level?',
        options: [
          'Same as wings-level',
          'Increases by approximately 19%',
          'Increases by approximately 41%',
        ],
        correctIndex: 2,
        explanation: 'At 60° bank, load factor is 2G. Stall speed increases by √2 ≈ 1.41, or about 41%. Vs_turn = Vs × √(load factor).',
        reference: 'PHAK Chapter 4',
        category: 'Aerodynamics',
      ),
      ExamQuestion(
        id: 'par_005',
        question: 'A METAR reads: METAR KORD 151755Z 28015G25KT 3/4SM +TSRA BKN030CB OVC080 27/23 A2985. What does "BKN030CB" indicate?',
        options: [
          'Broken clouds at 3,000 feet, cumulonimbus',
          'Broken clouds at 30,000 feet, cumulus',
          'Below clouds at 300 feet, cumulonimbus',
        ],
        correctIndex: 0,
        explanation: 'BKN = broken (5-7 oktas), 030 = 3,000 ft AGL (multiply by 100), CB = cumulonimbus cloud type. This indicates thunderstorm conditions.',
        reference: 'AIM 7-1-28',
        category: 'Weather',
      ),
      ExamQuestion(
        id: 'par_006',
        question: 'What is the required preflight action for a flight not in the vicinity of an airport?',
        options: [
          'Review weather reports and forecasts only',
          'Review all available information concerning that flight including weather, NOTAMs, and fuel requirements',
          'File a VFR flight plan with the nearest FSS',
        ],
        correctIndex: 1,
        explanation: 'Per 14 CFR 91.103, pilots must review all available information including weather, NOTAMs, known ATC delays, runway lengths, and takeoff/landing distances.',
        reference: '14 CFR 91.103',
        category: 'Regulations',
      ),
      ExamQuestion(
        id: 'par_007',
        question: 'What is the effect of a headwind on the glide ratio of an aircraft?',
        options: [
          'Increases the glide ratio over the ground',
          'Has no effect on glide ratio',
          'Decreases the distance covered over the ground',
        ],
        correctIndex: 2,
        explanation: 'A headwind reduces groundspeed while maintaining the same airspeed, reducing the distance covered over the ground for the same altitude loss.',
        reference: 'PHAK Chapter 4',
        category: 'Aerodynamics',
      ),
      ExamQuestion(
        id: 'par_008',
        question: 'What is the maximum altitude for VFR cruising flight on a magnetic course of 185°?',
        options: [
          'Odd thousands plus 500 feet (e.g., 3,500 ft)',
          'Even thousands plus 500 feet (e.g., 4,500 ft)',
          'Any altitude above 3,000 ft AGL',
        ],
        correctIndex: 1,
        explanation: 'VFR cruising altitudes: 0-179° magnetic = odd thousands + 500 ft. 180-359° magnetic = even thousands + 500 ft. Course 185° = even thousands + 500 ft.',
        reference: '14 CFR 91.159',
        category: 'Regulations',
      ),
      ExamQuestion(
        id: 'par_009',
        question: 'What is the definition of "night" for the purpose of logging flight time?',
        options: [
          'The period between sunset and sunrise',
          'The time between the end of evening civil twilight and the beginning of morning civil twilight',
          '1 hour after sunset to 1 hour before sunrise',
        ],
        correctIndex: 1,
        explanation: 'Per 14 CFR 1.1, "night" means the time between the end of evening civil twilight and the beginning of morning civil twilight, as published in the Air Almanac.',
        reference: '14 CFR 1.1',
        category: 'Regulations',
      ),
      ExamQuestion(
        id: 'par_010',
        question: 'What type of weather is associated with a fast-moving cold front?',
        options: [
          'Widespread stratiform clouds and steady rain',
          'Narrow band of severe thunderstorms and squall lines',
          'Fog and low ceilings for extended periods',
        ],
        correctIndex: 1,
        explanation: 'Fast-moving cold fronts produce narrow bands of severe weather including thunderstorms, squall lines, and turbulence. Slow cold fronts produce broader areas of precipitation.',
        reference: 'PHAK Chapter 12',
        category: 'Weather',
      ),
      ExamQuestion(
        id: 'par_011',
        question: 'What is the minimum fuel requirement for VFR flight during the day?',
        options: [
          'Enough to fly to the destination',
          'Enough to fly to the destination plus 30 minutes at normal cruise speed',
          'Enough to fly to the destination plus 45 minutes at normal cruise speed',
        ],
        correctIndex: 1,
        explanation: 'Per 14 CFR 91.151, day VFR: enough fuel to fly to destination plus 30 minutes at normal cruise. Night VFR: destination plus 45 minutes.',
        reference: '14 CFR 91.151',
        category: 'Regulations',
      ),
      ExamQuestion(
        id: 'par_012',
        question: 'What is the purpose of the ELT (Emergency Locator Transmitter)?',
        options: [
          'To communicate with ATC during normal operations',
          'To transmit a distress signal on 121.5 MHz and 406 MHz after a crash',
          'To provide GPS navigation backup',
        ],
        correctIndex: 1,
        explanation: 'ELTs transmit on 121.5 MHz (civil) and 406 MHz (digital) when activated by impact or manually. The 406 MHz signal is detected by COSPAS-SARSAT satellites for SAR.',
        reference: '14 CFR 91.207',
        category: 'Aircraft Systems',
      ),
      ExamQuestion(
        id: 'par_013',
        question: 'When should a pilot file a PIREP (Pilot Report)?',
        options: [
          'Only when requested by ATC',
          'Whenever hazardous conditions are encountered or when requested',
          'Only during IFR flight',
        ],
        correctIndex: 1,
        explanation: 'Pilots are encouraged to file PIREPs whenever hazardous conditions (turbulence, icing, low visibility) are encountered or when requested by ATC or FSS.',
        reference: 'AIM 7-1-20',
        category: 'Weather',
      ),
      ExamQuestion(
        id: 'par_014',
        question: 'What is the right-of-way rule when two aircraft are on final approach?',
        options: [
          'The higher aircraft has the right-of-way',
          'The aircraft lower on the approach has the right-of-way',
          'The faster aircraft has the right-of-way',
        ],
        correctIndex: 1,
        explanation: 'Per 14 CFR 91.113(g), when two aircraft are approaching to land, the aircraft at the lower altitude has the right-of-way. However, it shall not take advantage of this rule to cut in front of another.',
        reference: '14 CFR 91.113',
        category: 'Regulations',
      ),
      ExamQuestion(
        id: 'par_015',
        question: 'What is the effect of high density altitude on aircraft performance?',
        options: [
          'Improved engine performance and shorter takeoff roll',
          'Decreased engine power, reduced lift, and longer takeoff roll',
          'No significant effect on piston aircraft',
        ],
        correctIndex: 1,
        explanation: 'High density altitude (high elevation, high temperature, high humidity) reduces air density, resulting in less engine power, less lift, and degraded propeller efficiency — all requiring longer takeoff distances.',
        reference: 'PHAK Chapter 11',
        category: 'Aerodynamics',
      ),
      ExamQuestion(
        id: 'par_016',
        question: 'What does a special VFR clearance allow a pilot to do?',
        options: [
          'Operate in Class A airspace without an IFR clearance',
          'Operate within controlled airspace below basic VFR minimums with ATC clearance, clear of clouds and at least 1 SM visibility',
          'Ignore right-of-way rules during an emergency',
        ],
        correctIndex: 1,
        explanation: 'Special VFR lets a pilot operate within surface-area controlled airspace below basic VFR weather minimums, provided ATC issues a clearance, the aircraft remains clear of clouds, and flight visibility is at least 1 SM.',
        reference: '14 CFR 91.157',
        category: 'Airspace',
      ),
      ExamQuestion(
        id: 'par_017',
        question: 'What is the appropriate action when experiencing spatial disorientation at night?',
        options: [
          'Rely on outside visual references only',
          'Trust and rely on the flight instruments',
          'Make immediate large control inputs to recover',
        ],
        correctIndex: 1,
        explanation: 'Spatial disorientation occurs when bodily senses conflict with reality. Pilots must trust and rely on the flight instruments rather than physical sensations, using smooth control inputs.',
        reference: 'PHAK Chapter 17',
        category: 'Human Factors',
      ),
      ExamQuestion(
        id: 'par_018',
        question: 'On an instrument approach, what does the term "decision altitude (DA)" refer to?',
        options: [
          'The altitude at which a missed approach must be initiated if the required visual references are not in sight (precision approach)',
          'The lowest altitude authorized for en route flight',
          'The altitude at which the autopilot must be disengaged',
        ],
        correctIndex: 0,
        explanation: 'On a precision approach (e.g., ILS), the decision altitude is the altitude at which the pilot must decide to continue to land (with required visual references) or execute a missed approach.',
        reference: 'AIM 5-4-5',
        category: 'Instrument Procedures',
      ),
      ExamQuestion(
        id: 'par_019',
        question: 'Under Part 107, what is the maximum groundspeed allowed for a small unmanned aircraft?',
        options: [
          '87 knots (100 mph)',
          '100 knots (115 mph)',
          '55 knots (63 mph)',
        ],
        correctIndex: 0,
        explanation: 'Per 14 CFR 107.51, a small unmanned aircraft may not exceed a groundspeed of 87 knots (100 mph) and may not fly higher than 400 ft AGL (or within 400 ft of a structure).',
        reference: '14 CFR 107.51',
        category: 'Regulations',
      ),
      ExamQuestion(
        id: 'par_020',
        question: 'What is the primary purpose of carburetor heat?',
        options: [
          'To increase engine power for takeoff',
          'To prevent or remove induction-system icing by warming the air entering the carburetor',
          'To lean the fuel-air mixture at altitude',
        ],
        correctIndex: 1,
        explanation: 'Carburetor heat routes warm air into the induction system to prevent or clear carburetor ice, which can form even in warm weather with high humidity at reduced power settings.',
        reference: 'PHAK Chapter 7',
        category: 'Aircraft Systems',
      ),
      ExamQuestion(
        id: 'par_021',
        question: 'When operating radio communications, what does "squawk 7600" indicate?',
        options: [
          'Hijacking in progress',
          'Two-way radio communication failure',
          'General emergency',
        ],
        correctIndex: 1,
        explanation: 'Transponder code 7600 indicates a two-way radio communication (comm) failure. 7500 = hijacking; 7700 = general emergency.',
        reference: 'AIM 6-4-2',
        category: 'Communications',
      ),
      ExamQuestion(
        id: 'par_022',
        question: 'What is the recommended entry into a standard traffic pattern at a non-towered airport?',
        options: [
          'A straight-in approach to the active runway',
          'A 45° entry to the downwind leg at pattern altitude',
          'A direct crosswind entry from any direction',
        ],
        correctIndex: 1,
        explanation: 'The FAA recommends entering the traffic pattern at a non-towered airport on a 45° angle to the midpoint of the downwind leg at pattern altitude.',
        reference: 'AIM 4-3-3',
        category: 'Operational Procedures',
      ),
    ];
  }
}
