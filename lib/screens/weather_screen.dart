import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  final _icaoController = TextEditingController(text: 'KJFK');
  late TabController _tabController;
  List<Map<String, dynamic>> _pireps = [];
  List<Map<String, dynamic>> _sigmets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchWeather();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _icaoController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    final service = context.read<WeatherService>();
    await service.fetchMetar(_icaoController.text.trim());
    final pireps = await service.fetchPireps();
    final sigmets = await service.fetchSigmets();
    if (mounted) {
      setState(() {
        _pireps = pireps;
        _sigmets = sigmets;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('LIVE WEATHER'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BCD4),
          labelStyle: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
          unselectedLabelStyle: GoogleFonts.orbitron(fontSize: 9),
          tabs: const [
            Tab(text: 'METAR'),
            Tab(text: 'TRAFFIC'),
            Tab(text: 'PIREPs'),
            Tab(text: 'SIGMETs'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMetarTab(),
                _buildTrafficTab(),
                _buildPirepTab(),
                _buildSigmetTab(),
              ],
            ),
          ),
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
              controller: _icaoController,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 2,
              ),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter ICAO (e.g. KJFK)',
                prefixIcon: const Icon(Icons.local_airport, color: Color(0xFF00BCD4)),
                hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _fetchWeather,
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

  Widget _buildMetarTab() {
    return Consumer<WeatherService>(
      builder: (context, service, _) {
        if (service.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
          );
        }
        final metar = service.currentMetar;
        if (metar == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, color: Colors.white38, size: 48),
                const SizedBox(height: 12),
                Text(
                  service.error ?? 'Enter an ICAO code to get weather',
                  style: GoogleFonts.inter(color: Colors.white54),
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
              _buildFlightCategoryBanner(metar),
              const SizedBox(height: 16),
              _buildRawMetar(metar),
              const SizedBox(height: 16),
              _buildWeatherGrid(metar),
              if (metar.tafRaw != null) ...[
                const SizedBox(height: 16),
                _buildTafCard(metar.tafRaw!),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlightCategoryBanner(MetarData metar) {
    final colors = {
      'VFR': const Color(0xFF4CAF50),
      'MVFR': const Color(0xFF2196F3),
      'IFR': const Color(0xFFF44336),
      'LIFR': const Color(0xFF9C27B0),
    };
    final color = colors[metar.category] ?? Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(
            metar.icao,
            style: GoogleFonts.orbitron(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              metar.category,
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawMetar(MetarData metar) {
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
            'RAW METAR',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: const Color(0xFF00BCD4),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metar.raw,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherGrid(MetarData metar) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _buildWeatherTile('WIND', '${metar.windDir ?? '--'}° @ ${metar.windSpeedKt ?? '--'}kt', Icons.air),
        _buildWeatherTile('GUSTS', metar.windGustKt != null ? '${metar.windGustKt}kt' : 'None', Icons.storm),
        _buildWeatherTile('TEMP', metar.temperatureC != null ? '${metar.temperatureC!.toStringAsFixed(1)}°C' : '--', Icons.thermostat),
        _buildWeatherTile('DEWPOINT', metar.dewpointC != null ? '${metar.dewpointC!.toStringAsFixed(1)}°C' : '--', Icons.water_drop),
        _buildWeatherTile('ALTIMETER', metar.altimeterInHg != null ? '${metar.altimeterInHg!.toStringAsFixed(2)} inHg' : '--', Icons.speed),
        _buildWeatherTile('CEILING', metar.ceilingFt != null ? '${metar.ceilingFt} ft' : 'Unlimited', Icons.cloud),
      ],
    );
  }

  Widget _buildWeatherTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildTafCard(String tafRaw) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAF FORECAST',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: const Color(0xFF00BCD4),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tafRaw,
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficTab() {
    return Consumer<WeatherService>(
      builder: (context, service, _) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF0D1B2A),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Live aircraft over continental US (OpenSky Network)',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.read<WeatherService>().fetchLiveFlights(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text('Load', style: GoogleFonts.inter(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BCD4),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            if (service.flightsLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
                ),
              )
            else if (service.liveFlights.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.radar, color: Colors.white38, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Tap "Load" to fetch live aircraft',
                        style: GoogleFonts.inter(color: Colors.white54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Data from OpenSky Network (free, anonymous)',
                        style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: service.liveFlights.length,
                  itemBuilder: (context, i) {
                    final f = service.liveFlights[i];
                    return _buildFlightTile(f);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFlightTile(LiveFlight f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: f.onGround
                  ? const Color(0xFF37474F)
                  : const Color(0xFF1565C0).withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              f.onGround ? Icons.flight_land : Icons.flight,
              color: f.onGround ? Colors.white54 : const Color(0xFF00BCD4),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.callsign?.isNotEmpty == true ? f.callsign! : f.icao24.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  f.country ?? 'Unknown',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                f.altitude != null
                    ? '${(f.altitude! * 3.28084).round()} ft'
                    : 'Ground',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  color: const Color(0xFFFFB300),
                ),
              ),
              Text(
                f.velocity != null
                    ? '${(f.velocity! * 1.944).round()} kt'
                    : '--',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPirepTab() {
    if (_pireps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flight_class, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(
              'No recent PIREPs available',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilot Reports from Aviation Weather Center',
              style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pireps.length,
      itemBuilder: (context, i) {
        final p = _pireps[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            p.toString(),
            style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.white70),
          ),
        );
      },
    );
  }

  Widget _buildSigmetTab() {
    if (_sigmets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(
              'No active SIGMETs',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
            const SizedBox(height: 4),
            Text(
              'International SIGMETs from Aviation Weather Center',
              style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _sigmets.length,
      itemBuilder: (context, i) {
        final s = _sigmets[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF44336).withOpacity(0.3)),
          ),
          child: Text(
            s.toString(),
            style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.white70),
          ),
        );
      },
    );
  }
}
