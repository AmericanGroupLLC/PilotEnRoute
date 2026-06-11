import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/aviation_api_service.dart';
import '../services/weather_service.dart';

class AirportScreen extends StatefulWidget {
  const AirportScreen({super.key});

  @override
  State<AirportScreen> createState() => _AirportScreenState();
}

class _AirportScreenState extends State<AirportScreen> {
  final _controller = TextEditingController();
  AirportInfo? _airport;
  MetarData? _metar;
  bool _loading = false;
  String? _error;

  static const List<String> _popularAirports = [
    'KJFK', 'KLAX', 'KORD', 'KATL', 'KDFW',
    'KSFO', 'KDEN', 'KLAS', 'KMIA', 'KBOS',
    'EGLL', 'LFPG', 'EDDF', 'RJTT', 'YSSY',
  ];

  Future<void> _lookup(String code) async {
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _airport = null;
      _metar = null;
    });

    final apiService = context.read<AviationApiService>();
    final weatherService = context.read<WeatherService>();

    final airport = await apiService.fetchAirport(code.toUpperCase());
    MetarData? metar;
    if (airport != null) {
      metar = await weatherService.fetchMetar(airport.icao);
    }

    setState(() {
      _airport = airport;
      _metar = metar;
      _loading = false;
      _error = airport == null ? 'Airport not found: $code' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text('AIRPORT LOOKUP')),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildPopularAirports(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0D1B2A),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 3,
              ),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'ICAO or IATA code (e.g. KJFK)',
                prefixIcon: const Icon(Icons.local_airport, color: Color(0xFF00BCD4)),
                hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
              ),
              onSubmitted: _lookup,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _lookup(_controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: const Icon(Icons.search, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularAirports() {
    return Container(
      height: 44,
      color: const Color(0xFF0D1B2A),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _popularAirports.length,
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () {
              _controller.text = _popularAirports[i];
              _lookup(_popularAirports[i]);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF112240),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _popularAirports[i],
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.inter(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_airport == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_airport, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            Text(
              'Search for any airport',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter ICAO (KJFK) or IATA (JFK) code\nPowered by Rotate Pilot API',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white30,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAirportHeader(),
          const SizedBox(height: 16),
          if (_metar != null) _buildWeatherCard(),
          const SizedBox(height: 16),
          _buildInfoGrid(),
          const SizedBox(height: 16),
          if (_airport!.description.isNotEmpty) _buildDescriptionCard(),
        ],
      ),
    );
  }

  Widget _buildAirportHeader() {
    final airport = _airport!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
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
              Text(
                airport.icao,
                style: GoogleFonts.orbitron(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              if (airport.iata.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    airport.iata,
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            airport.name,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white60, size: 14),
              const SizedBox(width: 4),
              Text(
                '${airport.city}, ${airport.country}',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          if (airport.hasTraining) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4CAF50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school, color: Color(0xFF4CAF50), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Flight Training Available',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    final metar = _metar!;
    final colors = {
      'VFR': const Color(0xFF4CAF50),
      'MVFR': const Color(0xFF2196F3),
      'IFR': const Color(0xFFF44336),
      'LIFR': const Color(0xFF9C27B0),
    };
    final color = colors[metar.category] ?? Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'CURRENT WEATHER',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  metar.category,
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            metar.raw,
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    final airport = _airport!;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.0,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _buildInfoTile('ELEVATION', '${airport.elevation} ft MSL', Icons.height),
        _buildInfoTile('RUNWAYS', '${airport.runways}', Icons.airplanemode_active),
        _buildInfoTile('LATITUDE', airport.lat.toStringAsFixed(4), Icons.my_location),
        _buildInfoTile('LONGITUDE', airport.lon.toStringAsFixed(4), Icons.explore),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00BCD4), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.orbitron(
                    fontSize: 8,
                    color: Colors.white54,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABOUT',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: const Color(0xFF00BCD4),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _airport!.description,
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
}
