import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/flight_tracker_service.dart';

class FlightTrackerScreen extends StatefulWidget {
  const FlightTrackerScreen({super.key});

  @override
  State<FlightTrackerScreen> createState() => _FlightTrackerScreenState();
}

class _FlightTrackerScreenState extends State<FlightTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  final _tailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FlightTrackerService>().fetchNearbyFlights();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _tailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FlightTrackerService>(
      builder: (context, service, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A1628),
          appBar: AppBar(
            title: const Text('FLIGHT TRACKER'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => service.fetchNearbyFlights(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00BCD4),
              labelStyle: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
              tabs: const [
                Tab(text: 'LIVE'),
                Tab(text: 'SEARCH'),
                Tab(text: 'N-NUMBER'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildLiveTab(service),
              _buildSearchTab(service),
              _buildTailNumberTab(service),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveTab(FlightTrackerService service) {
    if (service.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00BCD4)),
            SizedBox(height: 16),
            Text('Fetching live flights...', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (service.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: const Color(0xFFFFB300).withOpacity(0.15),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFFB300), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    service.error!,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFFFB300)),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.radar, color: Color(0xFF00BCD4), size: 16),
              const SizedBox(width: 8),
              Text(
                '${service.nearbyFlights.length} aircraft in range',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  color: const Color(0xFF00BCD4),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: service.nearbyFlights.length,
            itemBuilder: (context, i) {
              final flight = service.nearbyFlights[i];
              return _buildFlightCard(flight);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlightCard(AircraftState flight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Transform.rotate(
              angle: (flight.trueTrack ?? 0) * 3.14159 / 180,
              child: const Icon(Icons.flight, color: Color(0xFF00BCD4), size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flight.callsign?.isNotEmpty == true ? flight.callsign! : flight.icao24.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  flight.originCountry ?? 'Unknown',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                flight.altitudeFt,
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              Text(
                flight.speedKts,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
              ),
              Text(
                flight.headingStr,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab(FlightTrackerService service) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Callsign or ICAO24 (e.g. UAL123)',
                    hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  ),
                  onSubmitted: (v) => service.searchByCallsign(v),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => service.searchByCallsign(_searchCtrl.text),
                child: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (service.isLoading)
            const CircularProgressIndicator(color: Color(0xFF00BCD4))
          else if (service.trackedFlight != null)
            _buildDetailCard(service.trackedFlight!)
          else if (service.error != null)
            Text(service.error!, style: GoogleFonts.inter(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildDetailCard(AircraftState flight) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            flight.callsign?.isNotEmpty == true ? flight.callsign! : flight.icao24.toUpperCase(),
            style: GoogleFonts.orbitron(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00BCD4),
            ),
          ),
          const SizedBox(height: 20),
          _detailRow('ICAO24', flight.icao24.toUpperCase()),
          _detailRow('Country', flight.originCountry ?? 'N/A'),
          _detailRow('Altitude', flight.altitudeFt),
          _detailRow('Speed', flight.speedKts),
          _detailRow('Heading', flight.headingStr),
          _detailRow('Squawk', flight.squawk ?? 'N/A'),
          _detailRow('On Ground', flight.onGround ? 'Yes' : 'No'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: Colors.white38,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTailNumberTab(FlightTrackerService service) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tailCtrl,
                  style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14, letterSpacing: 2),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'N-Number (e.g. N12345)',
                    hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.airplane_ticket, color: Colors.white38),
                  ),
                  onSubmitted: (v) => service.lookupTailNumber(v),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => service.lookupTailNumber(_tailCtrl.text),
                child: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (service.isLoading)
            const CircularProgressIndicator(color: Color(0xFF00BCD4))
          else if (service.tailNumberInfo != null)
            _buildTailCard(service.tailNumberInfo!)
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF112240),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.airplane_ticket, color: Colors.white24, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Enter an FAA N-Number to look up aircraft registration details.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTailCard(TailNumberInfo info) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            info.tailNumber,
            style: GoogleFonts.orbitron(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFB300),
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          if (info.model != null) _detailRow('Model', info.model!),
          if (info.manufacturer != null) _detailRow('Manufacturer', info.manufacturer!),
          if (info.owner != null) _detailRow('Owner', info.owner!),
          if (info.status != null) _detailRow('Status', info.status!),
          if (info.registrationDate != null) _detailRow('Registered', info.registrationDate!),
          if (info.engineType != null) _detailRow('Engine', info.engineType!),
          if (info.seats != null) _detailRow('Seats', info.seats!),
          if (info.weight != null) _detailRow('Weight Class', info.weight!),
        ],
      ),
    );
  }
}
