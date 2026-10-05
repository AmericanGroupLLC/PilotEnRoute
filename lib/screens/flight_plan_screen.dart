import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/flight_plan_service.dart';

class FlightPlanScreen extends StatefulWidget {
  const FlightPlanScreen({super.key});

  @override
  State<FlightPlanScreen> createState() => _FlightPlanScreenState();
}

class _FlightPlanScreenState extends State<FlightPlanScreen> {
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FlightPlanService>().loadPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FlightPlanService>(
      builder: (context, service, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A1628),
          appBar: AppBar(
            title: const Text('FLIGHT PLANS'),
            actions: [
              IconButton(
                tooltip: 'Add',
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _creating = true),
              ),
            ],
          ),
          body: _creating
              ? _buildCreator(service)
              : _buildPlansList(service),
          floatingActionButton: !_creating
              ? FloatingActionButton.extended(
                  onPressed: () => setState(() => _creating = true),
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.black,
                  icon: const Icon(Icons.add),
                  label: Text(
                    'NEW PLAN',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildPlansList(FlightPlanService service) {
    if (service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (service.plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              'No flight plans yet',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first flight plan',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: service.plans.length,
      itemBuilder: (context, i) {
        final plan = service.plans[i];
        return _buildPlanCard(plan, service);
      },
    );
  }

  Widget _buildPlanCard(FlightPlan plan, FlightPlanService service) {
    final flightRuleColor = plan.flightRules == 'IFR'
        ? const Color(0xFF2196F3)
        : plan.flightRules == 'VFR'
            ? const Color(0xFF4CAF50)
            : const Color(0xFFFFB300);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: flightRuleColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: flightRuleColor),
                  ),
                  child: Text(
                    plan.flightRules,
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      color: flightRuleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _airportBadge(plan.departure),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward, color: Color(0xFF00BCD4), size: 18),
                ),
                _airportBadge(plan.destination),
                if (plan.alternate != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('ALT:', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ),
                  _airportBadge(plan.alternate!, isAlternate: true),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _planStat('Aircraft', plan.aircraftType),
                _planStat('Altitude', '${plan.cruiseAltitude} ft'),
                _planStat('Speed', '${plan.cruiseSpeed} kts'),
                if (plan.estimatedTime != null)
                  _planStat('ETE', '${plan.estimatedTime!.toStringAsFixed(1)}h'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  DateFormat('MMM d, yyyy').format(plan.createdAt),
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showPlanDetails(plan, service),
                  icon: const Icon(Icons.visibility, size: 14),
                  label: Text(
                    'VIEW',
                    style: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00BCD4),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => service.deletePlan(plan.id),
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: Text(
                    'DELETE',
                    style: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF44336),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _airportBadge(String icao, {bool isAlternate = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAlternate
            ? const Color(0xFFFFB300).withValues(alpha: 0.1)
            : const Color(0xFF00BCD4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAlternate
              ? const Color(0xFFFFB300).withValues(alpha: 0.5)
              : const Color(0xFF00BCD4).withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        icao,
        style: GoogleFonts.orbitron(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isAlternate ? const Color(0xFFFFB300) : const Color(0xFF00BCD4),
        ),
      ),
    );
  }

  Widget _planStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
        ),
      ],
    );
  }

  void _showPlanDetails(FlightPlan plan, FlightPlanService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF112240),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAA FLIGHT PLAN',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  color: const Color(0xFF00BCD4),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  service.generateFaaFlightPlanString(plan),
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: const Color(0xFF4CAF50),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '📞 File via 1800wxbrief.com or call 1-800-WX-BRIEF',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreator(FlightPlanService service) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final depCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    final altCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'C172');
    final tailCtrl = TextEditingController();
    final altitudeCtrl = TextEditingController(text: '3500');
    final speedCtrl = TextEditingController(text: '110');
    final routeCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String flightRules = 'VFR';

    return StatefulBuilder(
      builder: (context, setModalState) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => setState(() => _creating = false),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Text(
                    'NEW FLIGHT PLAN',
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      color: const Color(0xFF00BCD4),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _formField(nameCtrl, 'Plan Name', 'e.g. Palo Alto to Monterey'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _formField(depCtrl, 'Departure (ICAO)', 'KPAO')),
                  const SizedBox(width: 10),
                  Expanded(child: _formField(destCtrl, 'Destination (ICAO)', 'KMRY')),
                ],
              ),
              const SizedBox(height: 12),
              _formField(altCtrl, 'Alternate Airport (optional)', 'KSNS'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _formField(typeCtrl, 'Aircraft Type', 'C172')),
                  const SizedBox(width: 10),
                  Expanded(child: _formField(tailCtrl, 'Tail Number', 'N12345')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _formField(altitudeCtrl, 'Cruise Altitude (ft)', '3500', isNum: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _formField(speedCtrl, 'TAS (kts)', '110', isNum: true)),
                ],
              ),
              const SizedBox(height: 12),
              // Flight rules selector
              Text(
                'FLIGHT RULES',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  color: Colors.white54,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['VFR', 'IFR', 'SVFR'].map((rule) {
                  final selected = flightRules == rule;
                  return GestureDetector(
                    onTap: () => setModalState(() => flightRules = rule),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF00BCD4).withValues(alpha: 0.2)
                            : const Color(0xFF112240),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? const Color(0xFF00BCD4) : Colors.white24,
                        ),
                      ),
                      child: Text(
                        rule,
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          color: selected ? const Color(0xFF00BCD4) : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              _formField(routeCtrl, 'Route', 'e.g. KPAO V25 SALINAS KMRY'),
              const SizedBox(height: 12),
              _formField(remarksCtrl, 'Remarks', 'Request flight following'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final plan = FlightPlan(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text,
                        departure: depCtrl.text.toUpperCase(),
                        destination: destCtrl.text.toUpperCase(),
                        alternate: altCtrl.text.isNotEmpty ? altCtrl.text.toUpperCase() : null,
                        aircraftType: typeCtrl.text,
                        tailNumber: tailCtrl.text.toUpperCase(),
                        cruiseAltitude: int.tryParse(altitudeCtrl.text) ?? 3500,
                        cruiseSpeed: int.tryParse(speedCtrl.text) ?? 110,
                        flightRules: flightRules,
                        route: routeCtrl.text.isNotEmpty ? routeCtrl.text : null,
                        remarks: remarksCtrl.text,
                        createdAt: DateTime.now(),
                      );
                      service.savePlan(plan);
                      setState(() => _creating = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'SAVE FLIGHT PLAN',
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
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String label, String hint,
      {bool isNum = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
        labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}
