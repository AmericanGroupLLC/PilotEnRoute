import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/aviation_api_service.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  final _controller = TextEditingController();
  GlossaryTerm? _term;
  bool _loading = false;
  String? _error;

  static const List<String> _popularTerms = [
    'tcas', 'metar', 'taf', 'notam', 'pirep', 'sigmet',
    'ils', 'vor', 'ndb', 'adf', 'atis', 'ctaf',
    'angle-of-attack', 'stall', 'vfr', 'ifr', 'atp',
  ];

  Future<void> _lookup(String term) async {
    if (term.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _term = null;
    });

    final service = context.read<AviationApiService>();
    final result = await service.fetchGlossaryTerm(
      term.toLowerCase().replaceAll(' ', '-'),
    );

    setState(() {
      _term = result;
      _loading = false;
      _error = result == null ? 'Term not found: $term' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text('AVIATION GLOSSARY')),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildPopularTerms(),
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
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search term (e.g. TCAS, angle-of-attack)',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00BCD4)),
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

  Widget _buildPopularTerms() {
    return Container(
      height: 44,
      color: const Color(0xFF0D1B2A),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _popularTerms.length,
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () {
              _controller.text = _popularTerms[i];
              _lookup(_popularTerms[i]);
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
                _popularTerms[i].toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
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
            const Icon(Icons.search_off, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.inter(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_term == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            Text(
              'Aviation Glossary',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '500+ aviation terms\nPowered by Rotate Pilot API',
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
          _buildTermCard(),
          if (_term!.related.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildRelatedTerms(),
          ],
        ],
      ),
    );
  }

  Widget _buildTermCard() {
    final term = _term!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF37474F), Color(0xFF112240)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      term.term,
                      style: GoogleFonts.orbitron(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    if (term.abbreviation.isNotEmpty &&
                        term.abbreviation != term.term) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Abbreviation: ${term.abbreviation}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFFFFB300),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00BCD4)),
                ),
                child: Text(
                  term.category.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    color: const Color(0xFF00BCD4),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Text(
            term.definition,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedTerms() {
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
            'RELATED TERMS',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: const Color(0xFF00BCD4),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _term!.related.map((r) {
              return GestureDetector(
                onTap: () {
                  _controller.text = r;
                  _lookup(r);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    r.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF00BCD4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
