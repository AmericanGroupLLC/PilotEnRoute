import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/aviation_api_service.dart';

class DailyQuoteCard extends StatelessWidget {
  const DailyQuoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AviationApiService>(
      builder: (context, service, _) {
        final quote = service.dailyQuote;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFB300).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.format_quote,
                color: Color(0xFFFFB300),
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote?.text ?? 'Aviate, Navigate, Communicate.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    if (quote?.author != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '— ${quote!.author}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFFFFB300),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
