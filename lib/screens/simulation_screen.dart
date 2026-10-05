import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:agl_i18n/agl_i18n.dart';

// ─── Lightweight AI Flight Simulation ─────────────────────────────────────────
// Uses the Flame game engine for 2D top-down flight simulation.
// AI autopilot uses simple rule-based physics (no server required).

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  late FlightSimGame _game;
  String _selectedAircraft = 'Cessna 172';
  String _selectedScenario = 'Normal Cruise';
  bool _gameStarted = false;

  final List<String> _aircraft = [
    'Cessna 172',
    'Piper Cherokee',
    'Cirrus SR22',
    'Boeing 737',
    'Airbus A320',
    'DJI Phantom (Drone)',
  ];

  final List<String> _scenarios = [
    'Normal Cruise',
    'Takeoff Training',
    'Landing Approach',
    'Emergency: Engine Failure',
    'Emergency: Electrical Failure',
    'Cross-Country Navigation',
    'Drone FPV Flight',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('AI FLIGHT SIMULATOR'),
        actions: [
          if (_gameStarted)
            IconButton(
              tooltip: (AglL10n.of(context)?.actionStop ?? 'Stop'),
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: () => setState(() => _gameStarted = false),
            ),
        ],
      ),
      body: _gameStarted ? _buildGame() : _buildSetup(),
    );
  }

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSetupHeader(),
          const SizedBox(height: 24),
          _buildAircraftSelector(),
          const SizedBox(height: 20),
          _buildScenarioSelector(),
          const SizedBox(height: 32),
          _buildAircraftInfo(),
          const SizedBox(height: 32),
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildSetupHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.flight_takeoff, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI FLIGHT SIMULATOR',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lightweight AI-driven flight simulation\nSelect aircraft and scenario to begin',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAircraftSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT AIRCRAFT',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: const Color(0xFF00BCD4),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _aircraft.map((a) {
            final isSelected = a == _selectedAircraft;
            return GestureDetector(
              onTap: () => setState(() => _selectedAircraft = a),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF112240),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00BCD4)
                        : Colors.white24,
                  ),
                ),
                child: Text(
                  a,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScenarioSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT SCENARIO',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: const Color(0xFF00BCD4),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        ..._scenarios.map((s) {
          final isSelected = s == _selectedScenario;
          final isEmergency = s.startsWith('Emergency');
          return GestureDetector(
            onTap: () => setState(() => _selectedScenario = s),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isEmergency
                        ? const Color(0xFFB71C1C).withValues(alpha: 0.3)
                        : const Color(0xFF1565C0).withValues(alpha: 0.3))
                    : const Color(0xFF112240),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? (isEmergency
                          ? const Color(0xFFF44336)
                          : const Color(0xFF00BCD4))
                      : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEmergency
                        ? Icons.warning_amber
                        : s.contains('Drone')
                            ? Icons.toys
                            : Icons.flight,
                    color: isEmergency
                        ? const Color(0xFFF44336)
                        : const Color(0xFF00BCD4),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    s,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAircraftInfo() {
    final specs = _getAircraftSpecs(_selectedAircraft);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFFFB300), size: 18),
              const SizedBox(width: 8),
              Text(
                _selectedAircraft.toUpperCase(),
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  color: const Color(0xFFFFB300),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 2.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: specs.entries.map((e) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      e.key,
                      style: GoogleFonts.orbitron(
                        fontSize: 7,
                        color: Colors.white38,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      e.value,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Map<String, String> _getAircraftSpecs(String aircraft) {
    final specs = {
      'Cessna 172': {'CRUISE': '124 kt', 'CEILING': '14,000 ft', 'RANGE': '640 nm', 'ENGINE': '1 Piston', 'MTOW': '2,550 lb', 'RATING': 'PPL'},
      'Piper Cherokee': {'CRUISE': '117 kt', 'CEILING': '14,000 ft', 'RANGE': '520 nm', 'ENGINE': '1 Piston', 'MTOW': '2,325 lb', 'RATING': 'PPL'},
      'Cirrus SR22': {'CRUISE': '183 kt', 'CEILING': '17,500 ft', 'RANGE': '1,000 nm', 'ENGINE': '1 Piston', 'MTOW': '3,600 lb', 'RATING': 'PPL'},
      'Boeing 737': {'CRUISE': '453 kt', 'CEILING': '41,000 ft', 'RANGE': '3,440 nm', 'ENGINE': '2 Turbofan', 'MTOW': '174,200 lb', 'RATING': 'ATP'},
      'Airbus A320': {'CRUISE': '447 kt', 'CEILING': '39,800 ft', 'RANGE': '3,300 nm', 'ENGINE': '2 Turbofan', 'MTOW': '172,000 lb', 'RATING': 'ATP'},
      'DJI Phantom (Drone)': {'CRUISE': '35 kt', 'CEILING': '19,685 ft', 'RANGE': '4.3 nm', 'ENGINE': '4 Electric', 'MTOW': '3.3 lb', 'RATING': 'Part 107'},
    };
    return specs[aircraft] ?? {};
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _game = FlightSimGame(
              aircraft: _selectedAircraft,
              scenario: _selectedScenario,
            );
            _gameStarted = true;
          });
        },
        icon: const Icon(Icons.play_arrow),
        label: Text(
          'START SIMULATION',
          style: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BCD4),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Stack(
      children: [
        GameWidget(game: _game),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _buildHUD(),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: _buildControls(),
        ),
      ],
    );
  }

  Widget _buildHUD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildHudItem('AIRCRAFT', _selectedAircraft.split(' ').first),
          _buildHudItem('SCENARIO', _selectedScenario.split(':').first),
          _buildHudItem('STATUS', 'ACTIVE'),
        ],
      ),
    );
  }

  Widget _buildHudItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 8,
            color: Colors.white38,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: const Color(0xFF00BCD4),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlBtn(Icons.arrow_upward, 'UP', () => _game.pitchUp()),
          _buildControlBtn(Icons.arrow_back, 'LEFT', () => _game.bankLeft()),
          _buildControlBtn(Icons.arrow_downward, 'DOWN', () => _game.pitchDown()),
          _buildControlBtn(Icons.arrow_forward, 'RIGHT', () => _game.bankRight()),
          _buildControlBtn(Icons.add, 'THROTTLE+', () => _game.increaseThrottle()),
          _buildControlBtn(Icons.remove, 'THROTTLE-', () => _game.decreaseThrottle()),
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            Text(
              label,
              style: GoogleFonts.orbitron(fontSize: 6, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Flame Game Engine — Lightweight AI Flight Simulation ─────────────────────
class FlightSimGame extends FlameGame with TapCallbacks {
  final String aircraft;
  final String scenario;

  // AI Flight State
  double _altitude = 5000.0;
  double _airspeed = 120.0;
  double _heading = 0.0;
  double _throttle = 0.75;
  double _pitch = 0.0;
  double _bank = 0.0;
  double _verticalSpeed = 0.0;
  bool _autopilot = true;

  // AI autopilot targets
  double _targetAltitude = 5000.0;
  final double _targetHeading = 0.0;
  double _targetAirspeed = 120.0;

  late TextComponent _altText;
  late TextComponent _spdText;
  late TextComponent _hdgText;
  late TextComponent _vsText;
  // ignore: unused_field
  late SpriteComponent? _planeSprite;

  // Simple aircraft icon drawn with Canvas
  late RectangleComponent _plane;
  late RectangleComponent _sky;
  late RectangleComponent _ground;

  // ignore: unused_field
  final _random = Random();
  double _cloudOffset = 0;

  FlightSimGame({required this.aircraft, required this.scenario}) {
    _initScenario();
  }

  void _initScenario() {
    switch (scenario) {
      case 'Takeoff Training':
        _altitude = 0;
        _airspeed = 0;
        _throttle = 0.0;
        _targetAltitude = 3000;
        break;
      case 'Landing Approach':
        _altitude = 3000;
        _airspeed = 90;
        _targetAltitude = 0;
        _targetAirspeed = 65;
        break;
      case 'Emergency: Engine Failure':
        _altitude = 8000;
        _airspeed = 80;
        _throttle = 0.0;
        _targetAltitude = 0;
        break;
      case 'Drone FPV Flight':
        _altitude = 400;
        _airspeed = 35;
        _targetAltitude = 400;
        _targetAirspeed = 35;
        break;
      default:
        _altitude = 5000;
        _airspeed = 120;
        _targetAltitude = 5000;
    }
  }

  @override
  Future<void> onLoad() async {
    // Sky gradient background
    _sky = RectangleComponent(
      position: Vector2.zero(),
      size: Vector2(size.x, size.y * 0.7),
      paint: Paint()..color = const Color(0xFF1565C0),
    );
    add(_sky);

    // Ground
    _ground = RectangleComponent(
      position: Vector2(0, size.y * 0.7),
      size: Vector2(size.x, size.y * 0.3),
      paint: Paint()..color = const Color(0xFF2E7D32),
    );
    add(_ground);

    // Aircraft representation
    _plane = RectangleComponent(
      position: Vector2(size.x / 2 - 15, size.y * 0.4),
      size: Vector2(30, 20),
      paint: Paint()..color = const Color(0xFFFFB300),
    );
    add(_plane);

    // HUD text components
    _altText = TextComponent(
      text: 'ALT: ${_altitude.round()} ft',
      position: Vector2(16, 16),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF00BCD4),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_altText);

    _spdText = TextComponent(
      text: 'SPD: ${_airspeed.round()} kt',
      position: Vector2(16, 36),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF4CAF50),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_spdText);

    _hdgText = TextComponent(
      text: 'HDG: ${_heading.round()}°',
      position: Vector2(16, 56),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFB300),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_hdgText);

    _vsText = TextComponent(
      text: 'V/S: ${_verticalSpeed.round()} fpm',
      position: Vector2(16, 76),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFF44336),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_vsText);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _runAI(dt);
    _updatePhysics(dt);
    _updateHUD();
    _animateClouds(dt);
  }

  /// Lightweight rule-based AI autopilot
  void _runAI(double dt) {
    if (!_autopilot) return;

    // Altitude hold
    final altError = _targetAltitude - _altitude;
    _pitch = (altError * 0.01).clamp(-15.0, 15.0);

    // Speed hold
    final spdError = _targetAirspeed - _airspeed;
    _throttle = (_throttle + spdError * 0.001 * dt).clamp(0.0, 1.0);

    // Heading hold
    double hdgError = _targetHeading - _heading;
    if (hdgError > 180) hdgError -= 360;
    if (hdgError < -180) hdgError += 360;
    _bank = (hdgError * 0.5).clamp(-30.0, 30.0);
  }

  void _updatePhysics(double dt) {
    // Simple flight physics
    final thrustForce = _throttle * 200.0;
    final dragForce = _airspeed * 0.5;
    final liftForce = _airspeed * 0.8;

    // Update airspeed
    _airspeed += (thrustForce - dragForce) * dt * 0.1;
    _airspeed = _airspeed.clamp(0.0, 600.0);

    // Update vertical speed from pitch and lift
    _verticalSpeed = (_pitch * _airspeed * 0.5) + (liftForce - 9.81 * 10) * dt;
    _verticalSpeed = _verticalSpeed.clamp(-3000.0, 3000.0);

    // Update altitude
    _altitude += _verticalSpeed * dt / 60.0;
    _altitude = _altitude.clamp(0.0, 45000.0);

    // Update heading from bank
    _heading += _bank * dt * 0.5;
    if (_heading >= 360) _heading -= 360;
    if (_heading < 0) _heading += 360;

    // Animate plane vertical position based on altitude ratio
    final altRatio = (_altitude / 45000.0).clamp(0.0, 1.0);
    _plane.position.y = size.y * (0.65 - altRatio * 0.5);

    // Tilt plane based on pitch
    _plane.angle = (-_pitch * pi / 180).clamp(-0.5, 0.5);
  }

  void _updateHUD() {
    _altText.text = 'ALT: ${_altitude.round()} ft';
    _spdText.text = 'SPD: ${_airspeed.round()} kt';
    _hdgText.text = 'HDG: ${_heading.round()}°';
    _vsText.text = 'V/S: ${_verticalSpeed.round()} fpm';
  }

  void _animateClouds(double dt) {
    _cloudOffset += dt * 20;
    if (_cloudOffset > size.x) _cloudOffset = 0;
  }

  // Control inputs
  void pitchUp() { _autopilot = false; _pitch = (_pitch - 5).clamp(-30.0, 30.0); }
  void pitchDown() { _autopilot = false; _pitch = (_pitch + 5).clamp(-30.0, 30.0); }
  void bankLeft() { _autopilot = false; _bank = (_bank - 10).clamp(-45.0, 45.0); }
  void bankRight() { _autopilot = false; _bank = (_bank + 10).clamp(-45.0, 45.0); }
  void increaseThrottle() { _autopilot = false; _throttle = (_throttle + 0.1).clamp(0.0, 1.0); }
  void decreaseThrottle() { _autopilot = false; _throttle = (_throttle - 0.1).clamp(0.0, 1.0); }
}
