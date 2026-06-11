import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  EmergencyScenario? _activeScenario;
  int _currentStep = 0;
  int _score = 0;
  bool _completed = false;
  int _timeLeft = 0;
  Timer? _timer;
  List<bool> _stepResults = [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startScenario(EmergencyScenario scenario) {
    _timer?.cancel();
    setState(() {
      _activeScenario = scenario;
      _currentStep = 0;
      _score = 0;
      _completed = false;
      _stepResults = [];
      _timeLeft = scenario.timeLimitSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 0) {
        t.cancel();
        _completeScenario();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _selectAction(int actionIndex) {
    final step = _activeScenario!.steps[_currentStep];
    final isCorrect = actionIndex == step.correctActionIndex;
    _stepResults.add(isCorrect);
    if (isCorrect) _score += 10;

    setState(() {});

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_currentStep < _activeScenario!.steps.length - 1) {
        setState(() => _currentStep++);
      } else {
        _completeScenario();
      }
    });
  }

  void _completeScenario() {
    _timer?.cancel();
    setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_activeScenario == null) return _buildScenarioList();
    if (_completed) return _buildResults();
    return _buildSimulation();
  }

  Widget _buildScenarioList() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text('EMERGENCY PROCEDURES')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7F0000), Color(0xFFB71C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'EMERGENCY SIMULATOR',
                        style: GoogleFonts.orbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Practice emergency procedures in a timed, scored environment. '
                    'Correct procedures save lives.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SELECT EMERGENCY SCENARIO',
              style: GoogleFonts.orbitron(
                fontSize: 11,
                color: const Color(0xFF00BCD4),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            ..._getScenarios().map((s) => _buildScenarioCard(s)),
            const SizedBox(height: 20),
            Text(
              'EMERGENCY REFERENCE',
              style: GoogleFonts.orbitron(
                fontSize: 11,
                color: const Color(0xFF00BCD4),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            _buildReferenceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioCard(EmergencyScenario scenario) {
    return GestureDetector(
      onTap: () => _startScenario(scenario),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF112240),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scenario.color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scenario.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(scenario.icon, color: scenario.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenario.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    scenario.description,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scenario.difficulty == 'Hard'
                        ? const Color(0xFFF44336).withOpacity(0.15)
                        : scenario.difficulty == 'Medium'
                            ? const Color(0xFFFFB300).withOpacity(0.15)
                            : const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    scenario.difficulty,
                    style: GoogleFonts.orbitron(
                      fontSize: 8,
                      color: scenario.difficulty == 'Hard'
                          ? const Color(0xFFF44336)
                          : scenario.difficulty == 'Medium'
                              ? const Color(0xFFFFB300)
                              : const Color(0xFF4CAF50),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${scenario.timeLimitSeconds}s',
                  style: GoogleFonts.orbitron(fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulation() {
    final scenario = _activeScenario!;
    final step = scenario.steps[_currentStep];
    final answered = _currentStep < _stepResults.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: Text(scenario.title),
        backgroundColor: const Color(0xFF7F0000),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _timeLeft < 30
                  ? const Color(0xFFF44336).withOpacity(0.3)
                  : Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '$_timeLeft s',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    color: _timeLeft < 30 ? const Color(0xFFF44336) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / scenario.steps.length,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Color(0xFFF44336)),
            minHeight: 3,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Situation
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F0000).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF44336).withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Color(0xFFF44336), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'SITUATION',
                              style: GoogleFonts.orbitron(
                                fontSize: 10,
                                color: const Color(0xFFF44336),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.situation,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'WHAT DO YOU DO?',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      color: Colors.white54,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...step.actions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final action = entry.value;
                    Color borderColor = Colors.white24;
                    Color bgColor = const Color(0xFF112240);
                    IconData? icon;
                    Color? iconColor;

                    if (answered) {
                      if (i == step.correctActionIndex) {
                        borderColor = const Color(0xFF4CAF50);
                        bgColor = const Color(0xFF4CAF50).withOpacity(0.1);
                        icon = Icons.check_circle;
                        iconColor = const Color(0xFF4CAF50);
                      } else if (i == (_currentStep < _stepResults.length ? step.correctActionIndex : -1)) {
                        // wrong selection
                      }
                    }

                    return GestureDetector(
                      onTap: !answered ? () => _selectAction(i) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
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
                                action,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (icon != null)
                              Icon(icon, color: iconColor, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (answered && _currentStep < _stepResults.length) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3F51B5).withOpacity(0.4)),
                      ),
                      child: Text(
                        step.explanation,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final scenario = _activeScenario!;
    final maxScore = scenario.steps.length * 10;
    final percentage = (_score / maxScore * 100).round();
    final passed = percentage >= 70;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: passed
                      ? [const Color(0xFF4CAF50).withOpacity(0.3), const Color(0xFF4CAF50).withOpacity(0.05)]
                      : [const Color(0xFFF44336).withOpacity(0.3), const Color(0xFFF44336).withOpacity(0.05)],
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
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                    ),
                  ),
                  Text(
                    passed ? 'PASSED' : 'REVIEW',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      color: passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              scenario.title,
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _resultStat('Score', '$_score / $maxScore', const Color(0xFF00BCD4)),
                _resultStat('Correct', '${_stepResults.where((r) => r).length}', const Color(0xFF4CAF50)),
                _resultStat('Missed', '${_stepResults.where((r) => !r).length}', const Color(0xFFF44336)),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startScenario(scenario),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _activeScenario = null),
                child: Text(
                  'BACK TO SCENARIOS',
                  style: GoogleFonts.orbitron(fontSize: 11, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildReferenceCard() {
    final refs = [
      ('Engine Failure', 'Best glide → Mayday → Squawk 7700 → Restart attempt → Forced landing'),
      ('Engine Fire', 'Mixture cutoff → Fuel off → Master off → Heater off → Dive to extinguish'),
      ('Electrical Fire', 'Master off → All electrics off → Ventilate → Land ASAP'),
      ('Spin Recovery', 'PARE: Power idle → Ailerons neutral → Rudder opposite → Elevator forward'),
      ('Radio Failure', 'Squawk 7600 → Light gun signals → Land at controlled airport'),
      ('Inadvertent IMC', 'Standard rate 180° turn → Climb → Contact ATC'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: refs.asMap().entries.map((entry) {
          final i = entry.key;
          final ref = entry.value;
          return Column(
            children: [
              if (i > 0) const Divider(height: 1, color: Colors.white12),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF44336),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.$1,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            ref.$2,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white54,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  List<EmergencyScenario> _getScenarios() {
    return [
      EmergencyScenario(
        title: 'Engine Failure After Takeoff',
        description: 'Engine quits at 500 ft AGL during climb-out',
        icon: Icons.warning,
        color: const Color(0xFFF44336),
        difficulty: 'Hard',
        timeLimitSeconds: 120,
        steps: [
          EmergencyStep(
            situation: 'You\'ve just rotated and are climbing through 500 ft AGL when the engine suddenly loses all power. Runway behind you, trees ahead.',
            actions: [
              'Pull back to maintain altitude and turn back to runway',
              'Lower nose to best glide speed (65 KIAS), look for landing area ahead',
              'Add full power and climb steeply',
              'Declare emergency on 121.5 MHz first',
            ],
            correctActionIndex: 1,
            explanation: 'NEVER attempt to turn back below 1,000 ft AGL. Lower nose to best glide immediately. The runway behind you is NOT an option — look ahead.',
          ),
          EmergencyStep(
            situation: 'You\'ve established best glide. You have a field 1 mile ahead. What do you do next?',
            actions: [
              'Squawk 7700 and call Mayday on 121.5',
              'Attempt engine restart: Fuel selector BOTH, Mixture RICH, Carb heat ON, Ignition START',
              'Flaps down immediately to slow down',
              'Turn off all electrical equipment to prevent fire',
            ],
            correctActionIndex: 1,
            explanation: 'Attempt restart WHILE gliding. Fuel selector BOTH, Mixture RICH, Carb heat ON, Ignition START. If no restart, then squawk 7700.',
          ),
          EmergencyStep(
            situation: 'Engine restart failed. You\'re 200 ft AGL approaching the field. What now?',
            actions: [
              'Full flaps, aim for near end of field, Mixture CUTOFF, Fuel OFF, Master OFF',
              'Maintain best glide, no flaps until certain you can make it',
              'Turn on all lights and make radio call',
              'Maintain cruise speed to have more options',
            ],
            correctActionIndex: 0,
            explanation: 'Secure the aircraft: Full flaps, aim for near end of field. Mixture CUTOFF, Fuel selector OFF, Master switch OFF to prevent fire. Brace for impact.',
          ),
        ],
      ),
      EmergencyScenario(
        title: 'Inadvertent IMC Entry',
        description: 'VFR pilot enters instrument meteorological conditions',
        icon: Icons.cloud,
        color: const Color(0xFF2196F3),
        difficulty: 'Medium',
        timeLimitSeconds: 90,
        steps: [
          EmergencyStep(
            situation: 'You\'re VFR and suddenly enter clouds. Visibility drops to zero. You feel disoriented.',
            actions: [
              'Pull up to climb above the clouds',
              'Trust your instruments, maintain wings level, begin a standard-rate 180° turn',
              'Descend below the clouds immediately',
              'Close your eyes and fly by feel',
            ],
            correctActionIndex: 1,
            explanation: 'TRUST YOUR INSTRUMENTS. Spatial disorientation is fatal. Begin a standard-rate (3°/sec) 180° turn to exit the way you came. Do NOT climb or descend until clear.',
          ),
          EmergencyStep(
            situation: 'You\'re in the 180° turn. Your body tells you you\'re in a bank but instruments show wings level.',
            actions: [
              'Trust your body — add aileron to level out',
              'Trust the instruments — maintain wings level per attitude indicator',
              'Look out the window for visual reference',
              'Reduce power and slow down',
            ],
            correctActionIndex: 1,
            explanation: 'ALWAYS trust instruments over your senses in IMC. The vestibular system is unreliable in clouds. The "leans" and graveyard spiral kill VFR pilots in IMC.',
          ),
          EmergencyStep(
            situation: 'You\'ve exited the clouds. You\'re now VFR again. What do you do?',
            actions: [
              'Continue to your destination — you\'re fine now',
              'Land at the nearest airport, contact ATC, file a PIREP about the conditions',
              'Climb above the cloud layer and continue VFR on top',
              'Descend to 500 ft AGL to stay below clouds',
            ],
            correctActionIndex: 1,
            explanation: 'Land at nearest airport. Contact ATC for assistance. File a PIREP to warn other pilots. Do NOT continue — conditions may worsen.',
          ),
        ],
      ),
      EmergencyScenario(
        title: 'Electrical Fire',
        description: 'Smoke and burning smell in cockpit',
        icon: Icons.local_fire_department,
        color: const Color(0xFFFF9800),
        difficulty: 'Medium',
        timeLimitSeconds: 60,
        steps: [
          EmergencyStep(
            situation: 'You smell burning and see smoke coming from behind the instrument panel.',
            actions: [
              'Open windows to ventilate',
              'Master switch OFF, all avionics OFF, identify and isolate the source',
              'Declare emergency immediately on 121.5',
              'Increase airspeed to blow smoke out',
            ],
            correctActionIndex: 1,
            explanation: 'Master switch OFF immediately to cut electrical power. Turn off all avionics. Identify source. If fire persists, use fire extinguisher. Land ASAP.',
          ),
          EmergencyStep(
            situation: 'You\'ve turned off the master switch. The smoke is clearing. What next?',
            actions: [
              'Turn master back on to use radios and navigate',
              'Ventilate cockpit, use battery-powered handheld radio if available, land at nearest airport',
              'Continue to destination — fire appears out',
              'Climb to higher altitude for better glide range',
            ],
            correctActionIndex: 1,
            explanation: 'Do NOT turn master back on — the fire could reignite. Use handheld radio. Ventilate. Land at nearest airport. Treat this as an emergency.',
          ),
        ],
      ),
    ];
  }
}

class EmergencyScenario {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String difficulty;
  final int timeLimitSeconds;
  final List<EmergencyStep> steps;

  EmergencyScenario({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.difficulty,
    required this.timeLimitSeconds,
    required this.steps,
  });
}

class EmergencyStep {
  final String situation;
  final List<String> actions;
  final int correctActionIndex;
  final String explanation;

  EmergencyStep({
    required this.situation,
    required this.actions,
    required this.correctActionIndex,
    required this.explanation,
  });
}
