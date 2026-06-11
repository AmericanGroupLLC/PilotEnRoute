import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/news_service.dart';

class NewsTicker extends StatelessWidget {
  const NewsTicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NewsService>(
      builder: (context, service, _) {
        if (service.isLoading) {
          return _buildShimmer();
        }
        if (service.articles.isEmpty) {
          return _buildEmpty();
        }
        final articles = service.articles.take(5).toList();
        return Column(
          children: articles
              .map((article) => _buildNewsItem(context, article))
              .toList(),
        );
      },
    );
  }

  Widget _buildNewsItem(BuildContext context, NewsArticle article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1565C0).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              article.source,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: const Color(0xFF00BCD4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: Colors.white38,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Loading aviation news...',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
        ),
      ),
    );
  }
}
