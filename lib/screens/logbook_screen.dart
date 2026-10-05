import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../services/logbook_service.dart';

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LogbookService>().init();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf(LogbookService service) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await service.buildLogbookPdf();
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'pilot_logbook.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export logbook PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LogbookService>(
      builder: (context, service, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A1628),
          appBar: AppBar(
            title: const Text('PILOT LOGBOOK'),
            actions: [
              IconButton(
                tooltip: 'Export logbook as PDF',
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                onPressed: _isExporting ? null : () => _exportPdf(service),
              ),
              IconButton(
                tooltip: 'ADD',
                icon: const Icon(Icons.add),
                onPressed: () => _showAddEntryDialog(context, service),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00BCD4),
              labelStyle: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
              tabs: const [
                Tab(text: 'ENTRIES'),
                Tab(text: 'TOTALS'),
                Tab(text: 'CURRENCY'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildEntriesTab(service),
              _buildTotalsTab(service),
              _buildCurrencyTab(service),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddEntryDialog(context, service),
            backgroundColor: const Color(0xFF00BCD4),
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add),
            label: Text(
              'LOG FLIGHT',
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEntriesTab(LogbookService service) {
    if (service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (service.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.book, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              'No logbook entries yet',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to log your first flight',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: service.entries.length,
      itemBuilder: (context, i) {
        final entry = service.entries[i];
        return _buildEntryCard(entry, service);
      },
    );
  }

  Widget _buildEntryCard(LogbookEntry entry, LogbookService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    entry.aircraftType,
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      color: const Color(0xFF00BCD4),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.tailNumber,
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy').format(entry.date),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.from,
                  style: GoogleFonts.orbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.flight, color: Color(0xFF00BCD4), size: 20),
                ),
                Text(
                  entry.to,
                  style: GoogleFonts.orbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('Total', '${entry.totalTime.toStringAsFixed(1)}h'),
                if (entry.picTime > 0) _miniStat('PIC', '${entry.picTime.toStringAsFixed(1)}h'),
                if (entry.dualReceived > 0) _miniStat('Dual', '${entry.dualReceived.toStringAsFixed(1)}h'),
                if (entry.crossCountry > 0) _miniStat('XC', '${entry.crossCountry.toStringAsFixed(1)}h'),
                if (entry.night > 0) _miniStat('Night', '${entry.night.toStringAsFixed(1)}h'),
                _miniStat('Ldgs', '${entry.dayLandings + entry.nightLandings}'),
              ],
            ),
            if (entry.remarks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.remarks,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 12,
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

  Widget _buildTotalsTab(LogbookService service) {
    final t = service.totals;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Hero total
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  t.totalTime.toStringAsFixed(1),
                  style: GoogleFonts.orbitron(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'TOTAL FLIGHT HOURS',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    color: Colors.white70,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${t.totalFlights} flights logged',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildTotalsGrid(t),
          const SizedBox(height: 20),
          _buildLandingsCard(t),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isExporting ? null : () => _exportPdf(service),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00BCD4),
                side: const BorderSide(color: Color(0xFF00BCD4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(
                _isExporting ? 'GENERATING…' : 'EXPORT LOGBOOK PDF',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsGrid(LogbookTotals t) {
    final items = [
      {'label': 'PIC', 'value': t.picTime.toStringAsFixed(1), 'unit': 'hrs', 'color': const Color(0xFF4CAF50)},
      {'label': 'SIC', 'value': t.sicTime.toStringAsFixed(1), 'unit': 'hrs', 'color': const Color(0xFF2196F3)},
      {'label': 'Dual Received', 'value': t.dualReceived.toStringAsFixed(1), 'unit': 'hrs', 'color': const Color(0xFFFFB300)},
      {'label': 'CFI Given', 'value': t.cfiGiven.toStringAsFixed(1), 'unit': 'hrs', 'color': const Color(0xFFFF9800)},
      {'label': 'Cross Country', 'value': t.crossCountry.toStringAsFixed(1), 'unit': 'hrs', 'color': const Color(0xFF00BCD4)},
      {'label': 'Night', 'value': t.night.toStringAsFixed(1), 'unit': 'hrs', 'color': const Color(0xFF9C27B0)},
      {'label': 'Actual IMC', 'value': t.actualInstrument.toStringAsFixed(1), 'unit': 'hrs', 'color': const Color(0xFF607D8B)},
      {'label': 'Sim Instrument', 'value': t.simulatedInstrument.toStringAsFixed(1), 'unit': 'hrs', 'color': const Color(0xFF546E7A)},
      {'label': 'Approaches', 'value': t.approaches.toString(), 'unit': '', 'color': const Color(0xFFF44336)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final color = item['color'] as Color;
        return Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item['value'] as String,
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if ((item['unit'] as String).isNotEmpty)
                Text(
                  item['unit'] as String,
                  style: GoogleFonts.orbitron(fontSize: 9, color: color.withValues(alpha: 0.7)),
                ),
              const SizedBox(height: 4),
              Text(
                item['label'] as String,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLandingsCard(LogbookTotals t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAKEOFFS & LANDINGS',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: const Color(0xFF00BCD4),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _landingsStat('Day T/O', t.dayTakeoffs.toString(), const Color(0xFFFFB300)),
              _landingsStat('Day Ldg', t.dayLandings.toString(), const Color(0xFFFFB300)),
              _landingsStat('Night T/O', t.nightTakeoffs.toString(), const Color(0xFF9C27B0)),
              _landingsStat('Night Ldg', t.nightLandings.toString(), const Color(0xFF9C27B0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _landingsStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildCurrencyTab(LogbookService service) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PILOT CURRENCY STATUS',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              color: const Color(0xFF00BCD4),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          _currencyCard(
            title: 'Day Passenger Currency',
            subtitle: '3 takeoffs & landings in last 90 days',
            isCurrent: service.isPassengerCurrent,
            regulation: '14 CFR 61.57(a)',
          ),
          _currencyCard(
            title: 'Night Passenger Currency',
            subtitle: '3 night T/O & landings in last 90 days',
            isCurrent: service.isNightPassengerCurrent,
            regulation: '14 CFR 61.57(b)',
          ),
          _currencyCard(
            title: 'IFR Currency',
            subtitle: '6 approaches + holds in last 6 months',
            isCurrent: service.isIfrCurrent,
            regulation: '14 CFR 61.57(c)',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF112240),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENCY REQUIREMENTS SUMMARY',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    color: const Color(0xFFFFB300),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _reqItem('Day passengers', '3 T/O & landings in 90 days (same category/class)'),
                _reqItem('Night passengers', '3 night T/O & full-stop landings in 90 days'),
                _reqItem('IFR flight', '6 approaches + holds in 6 months (or IPC)'),
                _reqItem('Flight Review', 'Every 24 calendar months with CFI'),
                _reqItem('Complex aircraft', 'Logbook endorsement required'),
                _reqItem('High-performance', 'Logbook endorsement required'),
                _reqItem('Tailwheel', 'Logbook endorsement required'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyCard({
    required String title,
    required String subtitle,
    required bool isCurrent,
    required String regulation,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
              : const Color(0xFFF44336).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isCurrent ? const Color(0xFF4CAF50) : const Color(0xFFF44336))
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCurrent ? Icons.check_circle : Icons.warning,
              color: isCurrent ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
                Text(
                  regulation,
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    color: Colors.white24,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isCurrent ? const Color(0xFF4CAF50) : const Color(0xFFF44336))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isCurrent ? 'CURRENT' : 'LAPSED',
              style: GoogleFonts.orbitron(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isCurrent ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reqItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, color: Color(0xFF00BCD4), size: 6),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: desc,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context, LogbookService service) {
    final formKey = GlobalKey<FormState>();
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final tailCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'C172');
    final totalCtrl = TextEditingController();
    final picCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    int dayLandings = 1;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF112240),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOG NEW FLIGHT',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    color: const Color(0xFF00BCD4),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _field(fromCtrl, 'From (ICAO)', 'KPAO')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(toCtrl, 'To (ICAO)', 'KSQL')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _field(typeCtrl, 'Aircraft Type', 'C172')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(tailCtrl, 'Tail Number', 'N12345')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _field(totalCtrl, 'Total Time', '1.5', isNum: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(picCtrl, 'PIC Time', '1.5', isNum: true)),
                  ],
                ),
                const SizedBox(height: 10),
                _field(remarksCtrl, 'Remarks', 'Pattern work, touch and goes'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        service.addEntry(LogbookEntry(
                          date: selectedDate,
                          aircraftType: typeCtrl.text,
                          tailNumber: tailCtrl.text,
                          from: fromCtrl.text.toUpperCase(),
                          to: toCtrl.text.toUpperCase(),
                          totalTime: double.tryParse(totalCtrl.text) ?? 0,
                          picTime: double.tryParse(picCtrl.text) ?? 0,
                          dayLandings: dayLandings,
                          remarks: remarksCtrl.text,
                        ));
                        Navigator.pop(ctx);
                      }
                    },
                    child: Text(
                      'SAVE ENTRY',
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
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
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
        filled: true,
        fillColor: const Color(0xFF0A1628),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
