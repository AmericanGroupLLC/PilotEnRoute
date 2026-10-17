import 'package:flutter/material.dart';
import '../ui/theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/chart_service.dart';

// Charts & Plates — opens the FAA's official d-TPP search for an airport in
// the browser (US only). See chart_service.dart for why it is a link-out.
//
// A geo-referenced moving-map overlay would need a licensed chart provider.

const _kBg = Sky.canvas;
const _kCard = Sky.card;
const _kCyan = Sky.teal;
const _kAmber = Sky.caution;

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  final ChartService _service = ChartService();
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _service.loadRecent();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _search([String? icao]) async {
    final code = (icao ?? _controller.text).trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    _controller.text = code;
    final uri = _service.linkFor(code);
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open faa.gov.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open faa.gov.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('CHARTS'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildRecentChips(),
          Expanded(child: _buildBody()),
          _buildCaption(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              style: AppType.sans(color: Sky.ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Airport ICAO (e.g. KLAX)',
                hintStyle: AppType.sans(color: Sky.muted),
                prefixIcon: const Icon(Icons.search, color: Sky.faint),
                filled: true,
                fillColor: _kCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Sky.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kCyan),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => _search(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCyan,
                foregroundColor: Sky.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'OPEN',
                style: AppType.condensed(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChips() {
    final recent = _service.recent;
    if (recent.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: recent.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Center(
              child: Text(
                'RECENT',
                style: AppType.condensed(
                  fontSize: 9,
                  color: Sky.muted,
                  letterSpacing: 1.5,
                ),
              ),
            );
          }
          final code = recent[i - 1];
          return Center(
            child: ActionChip(
              backgroundColor: _kCard,
              side: const BorderSide(color: Sky.line),
              label: Text(
                code,
                style: AppType.condensed(
                  fontSize: 10,
                  color: _kCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _search(code),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final error = _service.error;
    if (error != null) {
      return _buildMessage(Icons.error_outline, error, _kAmber);
    }

    return _buildMessage(
      Icons.map_outlined,
      'Enter an airport to open its charts and plates — airport diagram, '
      'approaches, departures, arrivals and minimums — on the FAA\'s official '
      'd-TPP search (cycle ${dtppCycleFor(DateTime.now())}). Opens in your '
      'browser.',
      Sky.muted,
    );
  }

  Widget _buildMessage(IconData icon, String message, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.sans(
                fontSize: 13,
                color: Sky.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaption() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _kBg,
      child: Text(
        'Official FAA d-TPP charts on faa.gov — US airports only.',
        textAlign: TextAlign.center,
        style: AppType.sans(fontSize: 10, color: Sky.muted),
      ),
    );
  }
}
