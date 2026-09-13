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
  List<Map<String, dynamic>> _airmets = [];
  List<Map<String, dynamic>> _windsAloft = [];
  bool _advisoriesLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
    if (mounted) setState(() => _advisoriesLoading = true);
    await service.fetchMetar(_icaoController.text.trim());
    final pireps = await service.fetchPireps();
    final sigmets = await service.fetchSigmets();
    final airmets = await service.fetchAirmets();
    final windsAloft = await service.fetchWindsAloft();
    if (mounted) {
      setState(() {
        _pireps = pireps;
        _sigmets = sigmets;
        _airmets = airmets;
        _windsAloft = windsAloft;
        _advisoriesLoading = false;
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
            Tab(text: 'AIRMET'),
            Tab(text: 'WINDS ALOFT'),
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
                _buildAirmetTab(),
                _buildWindsAloftTab(),
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
          Semantics(
            container: true,
            button: true,
            label: 'Fetch weather for the entered airport',
            excludeSemantics: true,
            child: ElevatedButton(
              onPressed: _fetchWeather,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: const Icon(Icons.search, color: Colors.black),
            ),
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
    const categoryNames = {
      'VFR': 'visual flight rules',
      'MVFR': 'marginal visual flight rules',
      'IFR': 'instrument flight rules',
      'LIFR': 'low instrument flight rules',
    };
    final spokenCategory =
        categoryNames[metar.category] ?? metar.category.toLowerCase();

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${_spellIcao(metar.icao)}, flight category '
          '${metar.category}, $spokenCategory',
      excludeSemantics: true,
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
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
      ),
    );
  }

  /// A four-letter ICAO identifier is read letter by letter, not as a word.
  static String _spellIcao(String icao) => icao.trim().split('').join(' ');

  Widget _buildRawMetar(MetarData metar) {
    return Semantics(
      container: true,
      label: 'Raw METAR. ${metar.raw}',
      excludeSemantics: true,
      child: Container(
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
        _buildWeatherTile('VISIBILITY', metar.visibilitySm != null ? '${metar.visibilitySm!.toStringAsFixed(metar.visibilitySm! % 1 == 0 ? 0 : 1)} sm' : '--', Icons.visibility),
      ],
    );
  }

  Widget _buildWeatherTile(String label, String value, IconData icon) {
    return Semantics(
      container: true,
      label: '$label: ${value.replaceAll('--', 'not available')}',
      excludeSemantics: true,
      child: Container(
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
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.5)),
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
                  : const Color(0xFF1565C0).withValues(alpha: 0.3),
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
            border: Border.all(color: const Color(0xFFF44336).withValues(alpha: 0.3)),
          ),
          child: Text(
            s.toString(),
            style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.white70),
          ),
        );
      },
    );
  }

  Widget _buildSourceCaption() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Source: aviationweather.gov (free)',
        style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
      ),
    );
  }

  Widget _buildAirmetTab() {
    if (_advisoriesLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
      );
    }
    if (_airmets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(
              'No active AIRMETs',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
            const SizedBox(height: 4),
            Text(
              'Graphical AIRMETs (G-AIRMET) from Aviation Weather Center',
              style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _airmets.length + 1,
      itemBuilder: (context, i) {
        if (i == _airmets.length) {
          return Center(child: _buildSourceCaption());
        }
        final a = _airmets[i];
        final hazard = (a['hazard'] ?? a['product'] ?? a['type'] ?? 'AIRMET')
            .toString();
        final area = (a['area'] ?? a['region'] ?? a['fir'] ?? '').toString();
        final validFrom = a['validTimeFrom'] ?? a['validTime'];
        final validTo = a['validTimeTo'];
        final valid = [validFrom, validTo]
            .where((e) => e != null && e.toString().isNotEmpty)
            .map((e) => e.toString())
            .join(' → ');
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: Color(0xFFFFB300), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hazard.toUpperCase(),
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFB300),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              if (area.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'AREA: $area',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
              ],
              if (valid.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'VALID: $valid',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                a.toString(),
                style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white38),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWindsAloftTab() {
    if (_advisoriesLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
      );
    }
    if (_windsAloft.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.air, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(
              'No winds/temps aloft available',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
            const SizedBox(height: 4),
            Text(
              'Winds & temperatures aloft from Aviation Weather Center',
              style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      );
    }
    // Raw FB text fallback: single monospace block.
    if (_windsAloft.length == 1 && _windsAloft.first.containsKey('raw')) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF112240),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FB WINDS/TEMPS ALOFT',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      color: const Color(0xFF00BCD4),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _windsAloft.first['raw']?.toString() ?? '',
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            _buildSourceCaption(),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _windsAloft.length + 1,
      itemBuilder: (context, i) {
        if (i == _windsAloft.length) {
          return Center(child: _buildSourceCaption());
        }
        final w = _windsAloft[i];
        final station =
            (w['stationId'] ?? w['icaoId'] ?? w['id'] ?? w['station'] ?? '')
                .toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (station.isNotEmpty)
                Text(
                  station.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00BCD4),
                    letterSpacing: 1,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                w.toString(),
                style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }
}
