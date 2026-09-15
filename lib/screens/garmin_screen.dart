import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class GarminScreen extends StatefulWidget {
  const GarminScreen({super.key});

  @override
  State<GarminScreen> createState() => _GarminScreenState();
}

class _GarminScreenState extends State<GarminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('GARMIN & SERVICES'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BCD4),
          labelStyle: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
          tabs: const [
            Tab(text: 'GARMIN'),
            Tab(text: 'SERVICES'),
            Tab(text: 'APPS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGarminTab(),
          _buildServicesTab(),
          _buildAppsTab(),
        ],
      ),
    );
  }

  Widget _buildGarminTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGarminHeader(),
          const SizedBox(height: 20),
          _buildGarminProducts(),
          const SizedBox(height: 20),
          _buildConnectIQSection(),
          const SizedBox(height: 20),
          _buildGarminPilotSection(),
        ],
      ),
    );
  }

  Widget _buildGarminHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
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
              const Icon(Icons.watch, color: Colors.white, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GARMIN AVIATION',
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Connect IQ • Pilot • avionics',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Integrate PilotEnRoute with your Garmin devices. '
            'Access Garmin Pilot, Connect IQ apps, and Garmin avionics '
            'data directly from your wearable.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _launch('https://www.garmin.com/en-US/c/aviation/'),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(
              'Visit Garmin Aviation',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A237E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGarminProducts() {
    final products = [
      {
        'name': 'Garmin Pilot',
        'desc': 'Full-featured aviation app with charts, weather, and flight planning',
        'icon': Icons.flight,
        'url': 'https://www.garmin.com/en-US/p/115856',
        'badge': 'APP',
      },
      {
        'name': 'G1000 NXi',
        'desc': 'Integrated flight deck with synthetic vision and weather',
        'icon': Icons.dashboard,
        'url': 'https://www.garmin.com/en-US/p/621398',
        'badge': 'AVIONICS',
      },
      {
        'name': 'GTN 750Xi',
        'desc': 'Touchscreen navigator with IFR approach capability',
        'icon': Icons.navigation,
        'url': 'https://www.garmin.com/en-US/p/621398',
        'badge': 'NAV',
      },
      {
        'name': 'D2 Mach 1',
        'desc': 'Aviation smartwatch with pulse oximeter and flight data',
        'icon': Icons.watch,
        'url': 'https://www.garmin.com/en-US/p/707174',
        'badge': 'WATCH',
      },
      {
        'name': 'GDL 52',
        'desc': 'Portable ADS-B receiver with SiriusXM weather',
        'icon': Icons.radar,
        'url': 'https://www.garmin.com/en-US/p/621398',
        'badge': 'ADS-B',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GARMIN PRODUCTS',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: const Color(0xFF00BCD4),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        ...products.map((p) => GestureDetector(
              onTap: () => _launch(p['url'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF112240),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1A237E).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        p['icon'] as IconData,
                        color: const Color(0xFF00BCD4),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p['name'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A237E),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  p['badge'] as String,
                                  style: GoogleFonts.orbitron(
                                    fontSize: 7,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            p['desc'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white54,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildConnectIQSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.watch, color: Color(0xFF00BCD4), size: 20),
              const SizedBox(width: 8),
              Text(
                'GARMIN CONNECT IQ',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  color: const Color(0xFF00BCD4),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'PilotEnRoute is designed to work alongside Garmin Connect IQ apps '
            'on your D2 Mach 1, D2 Delta, or Fenix aviation watch. '
            'The Connect IQ SDK allows data exchange between your phone and wearable.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          _buildConnectIQFeature('Flight data display on wrist', true),
          _buildConnectIQFeature('METAR weather at a glance', true),
          _buildConnectIQFeature('Altitude and airspeed readout', true),
          _buildConnectIQFeature('Checklist notifications', true),
          _buildConnectIQFeature('Emergency alert vibration', true),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _launch('https://developer.garmin.com/connect-iq/overview/'),
            icon: const Icon(Icons.code, size: 16),
            label: Text(
              'Connect IQ Developer Docs',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00BCD4),
              side: const BorderSide(color: Color(0xFF00BCD4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectIQFeature(String text, bool available) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            available ? Icons.check_circle : Icons.radio_button_unchecked,
            color: available ? const Color(0xFF4CAF50) : Colors.white38,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: available ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGarminPilotSection() {
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
              const Icon(Icons.flight, color: Color(0xFFFFB300), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GARMIN PILOT INTEGRATION',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    color: const Color(0xFFFFB300),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Garmin Pilot is the industry-leading aviation app. '
            'PilotEnRoute complements Garmin Pilot with education, '
            'simulation, and training tools.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _launch(
                    'https://apps.apple.com/us/app/garmin-pilot/id394378702',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'App Store',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _launch(
                    'https://play.google.com/store/apps/details?id=com.garmin.android.apps.pilot',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Google Play',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    final services = [
      {
        'name': 'ForeFlight',
        'desc': 'Integrated flight app — charts, weather, filing, logbook',
        'url': 'https://foreflight.com',
        'color': const Color(0xFF1565C0),
        'badge': 'PREMIUM',
      },
      {
        'name': 'SkyVector',
        'desc': 'Free aeronautical charts and flight planning',
        'url': 'https://skyvector.com',
        'color': const Color(0xFF00695C),
        'badge': 'FREE',
      },
      {
        'name': 'AviationWeather.gov',
        'desc': 'Official FAA/NWS aviation weather products',
        'url': 'https://aviationweather.gov',
        'color': const Color(0xFF1B5E20),
        'badge': 'FREE',
      },
      {
        'name': 'FlightAware',
        'desc': 'Live flight tracking, delays, and airport status',
        'url': 'https://flightaware.com',
        'color': const Color(0xFFE65100),
        'badge': 'FREE',
      },
      {
        'name': 'PilotEdge',
        'desc': 'Live ATC network for flight simulator training',
        'url': 'https://www.pilotedge.net',
        'color': const Color(0xFF6A1B9A),
        'badge': 'PAID',
      },
      {
        'name': 'VATSIM',
        'desc': 'Free online ATC and pilot network for simulators',
        'url': 'https://www.vatsim.net',
        'color': const Color(0xFF37474F),
        'badge': 'FREE',
      },
      {
        'name': 'FAA WINGS Program',
        'desc': 'Pilot proficiency program — earn credits online',
        'url': 'https://www.faasafety.gov/WINGS/pub/learn_more.aspx',
        'color': const Color(0xFF1A237E),
        'badge': 'FREE',
      },
      {
        'name': 'OpenSky Network',
        'desc': 'Free live ADS-B flight tracking API',
        'url': 'https://opensky-network.org',
        'color': const Color(0xFF004D40),
        'badge': 'API',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      itemBuilder: (context, i) {
        final s = services[i];
        final badgeColors = {
          'FREE': const Color(0xFF4CAF50),
          'PREMIUM': const Color(0xFFFFB300),
          'PAID': const Color(0xFFF44336),
          'API': const Color(0xFF00BCD4),
        };
        final badgeColor =
            badgeColors[s['badge'] as String] ?? const Color(0xFF37474F);

        return GestureDetector(
          onTap: () => _launch(s['url'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF112240),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (s['color'] as Color).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (s['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.public,
                    color: s['color'] as Color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: badgeColor),
                            ),
                            child: Text(
                              s['badge'] as String,
                              style: GoogleFonts.orbitron(
                                fontSize: 7,
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        s['desc'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppsTab() {
    final apps = [
      {
        'name': 'Garmin Pilot',
        'platform': 'iOS & Android',
        'desc': 'Full-featured aviation app with IFR charts',
        'url': 'https://www.garmin.com/en-US/p/115856',
        'color': const Color(0xFF1A237E),
      },
      {
        'name': 'ForeFlight Mobile',
        'platform': 'iOS & Android',
        'desc': 'Industry standard EFB for professional pilots',
        'url': 'https://foreflight.com/products/foreflight-mobile/',
        'color': const Color(0xFF1565C0),
      },
      {
        'name': 'CloudAhoy',
        'platform': 'iOS & Android',
        'desc': 'Debriefing tool for flight analysis and training',
        'url': 'https://www.cloudahoy.com',
        'color': const Color(0xFF00695C),
      },
      {
        'name': 'Sporty\'s E6B',
        'platform': 'iOS & Android',
        'desc': 'Electronic flight computer for pilots',
        'url': 'https://www.sportys.com/e6b-flight-computer-app.html',
        'color': const Color(0xFFE65100),
      },
      {
        'name': 'DJI Fly',
        'platform': 'iOS & Android',
        'desc': 'Official DJI drone control and flight planning app',
        'url': 'https://www.dji.com/downloads/djiapp/dji-fly',
        'color': const Color(0xFF37474F),
      },
      {
        'name': 'AirMap',
        'platform': 'iOS & Android',
        'desc': 'Drone airspace intelligence and LAANC authorization',
        'url': 'https://www.airmap.com',
        'color': const Color(0xFF6A1B9A),
      },
      {
        'name': 'Infinite Flight',
        'platform': 'iOS & Android',
        'desc': 'Mobile flight simulator with live ATC',
        'url': 'https://infiniteflight.com',
        'color': const Color(0xFF004D40),
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: apps.length,
      itemBuilder: (context, i) {
        final app = apps[i];
        return GestureDetector(
          onTap: () => _launch(app['url'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF112240),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (app['color'] as Color).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (app['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.phone_android,
                    color: app['color'] as Color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app['name'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        app['platform'] as String,
                        style: GoogleFonts.orbitron(
                          fontSize: 9,
                          color: const Color(0xFF00BCD4),
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        app['desc'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
