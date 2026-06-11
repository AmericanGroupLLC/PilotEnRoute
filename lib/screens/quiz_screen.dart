import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/aviation_api_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  String _selectedSubject = 'all';
  List<AviationQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  int _total = 0;
  bool _loading = false;
  bool _showExplanation = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _currentIndex = 0;
      _selectedAnswer = null;
      _answered = false;
      _score = 0;
      _total = 0;
    });

    final service = context.read<AviationApiService>();
    final questions = await service.fetchQuestions(
      subject: _selectedSubject == 'all' ? null : _selectedSubject,
      count: 5,
    );

    setState(() {
      _questions = questions;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('ATPL QUIZ'),
        actions: [
          if (_total > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '$_score/$_total',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    color: const Color(0xFFFFB300),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSubjectSelector(),
          Expanded(child: _buildQuizBody()),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector() {
    final subjects = [
      {'id': 'all', 'label': 'All Subjects'},
      ...AviationApiService.subjects.map((s) => {
            'id': s,
            'label': s.replaceAll('-', ' ').toUpperCase(),
          }),
    ];

    return Container(
      height: 48,
      color: const Color(0xFF0D1B2A),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: subjects.length,
        itemBuilder: (context, i) {
          final s = subjects[i];
          final isActive = _selectedSubject == s['id'];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedSubject = s['id']!);
              _loadQuestions();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFFFB300)
                    : const Color(0xFF112240),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? const Color(0xFFFFB300) : Colors.white24,
                ),
              ),
              child: Text(
                s['label']!,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.black : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuizBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
      );
    }

    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(
              'No questions loaded',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadQuestions,
              child: const Text('Load Questions'),
            ),
          ],
        ),
      );
    }

    if (_currentIndex >= _questions.length) {
      return _buildResultScreen();
    }

    final question = _questions[_currentIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProgressBar(),
          const SizedBox(height: 16),
          _buildQuestionCard(question),
          const SizedBox(height: 16),
          _buildOptions(question),
          if (_answered) ...[
            const SizedBox(height: 16),
            _buildExplanationCard(question),
            const SizedBox(height: 16),
            _buildNextButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _questions.isEmpty
        ? 0.0
        : (_currentIndex / _questions.length).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentIndex + 1} of ${_questions.length}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
            ),
            Text(
              'Score: $_score/$_total',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                color: const Color(0xFFFFB300),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF00BCD4)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(AviationQuestion question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF112240)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00BCD4)),
                ),
                child: Text(
                  question.subject.replaceAll('-', ' ').toUpperCase(),
                  style: GoogleFonts.orbitron(
                    fontSize: 8,
                    color: const Color(0xFF00BCD4),
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  question.authority,
                  style: GoogleFonts.orbitron(
                    fontSize: 8,
                    color: const Color(0xFFFFB300),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.question,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(AviationQuestion question) {
    return Column(
      children: question.options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        Color? bgColor;
        Color borderColor = Colors.white24;
        Color textColor = Colors.white;

        if (_answered) {
          if (index == question.correctAnswer) {
            bgColor = const Color(0xFF4CAF50).withOpacity(0.2);
            borderColor = const Color(0xFF4CAF50);
            textColor = const Color(0xFF4CAF50);
          } else if (index == _selectedAnswer) {
            bgColor = const Color(0xFFF44336).withOpacity(0.2);
            borderColor = const Color(0xFFF44336);
            textColor = const Color(0xFFF44336);
          }
        } else if (index == _selectedAnswer) {
          bgColor = const Color(0xFF1565C0).withOpacity(0.3);
          borderColor = const Color(0xFF1565C0);
        }

        return GestureDetector(
          onTap: _answered ? null : () => _selectAnswer(index, question),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor ?? const Color(0xFF112240),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      option.label,
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ),
                if (_answered && index == question.correctAnswer)
                  const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                if (_answered && index == _selectedAnswer && index != question.correctAnswer)
                  const Icon(Icons.cancel, color: Color(0xFFF44336), size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _selectAnswer(int index, AviationQuestion question) {
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      _total++;
      if (index == question.correctAnswer) _score++;
    });
  }

  Widget _buildExplanationCard(AviationQuestion question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Color(0xFFFFB300), size: 18),
              const SizedBox(width: 8),
              Text(
                'EXPLANATION',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  color: const Color(0xFFFFB300),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.explanation,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    final isLast = _currentIndex >= _questions.length - 1;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _currentIndex++;
            _selectedAnswer = null;
            _answered = false;
            _showExplanation = false;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isLast
              ? const Color(0xFFFFB300)
              : const Color(0xFF1565C0),
          foregroundColor: isLast ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          isLast ? 'SEE RESULTS' : 'NEXT QUESTION',
          style: GoogleFonts.orbitron(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final percentage = _total > 0 ? (_score / _total * 100).round() : 0;
    final passed = percentage >= 70;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336))
                    .withOpacity(0.2),
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
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                    ),
                  ),
                  Text(
                    passed ? 'PASS' : 'FAIL',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      color: passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              passed ? 'Excellent work, Pilot!' : 'Keep studying, Pilot!',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You scored $_score out of $_total questions correctly.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadQuestions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'NEW QUIZ',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
