import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/news_service.dart';
import 'package:agl_i18n/agl_i18n.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<NewsService>();
      if (service.articles.isEmpty) {
        service.fetchAllNews();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('AVIATION NEWS'),
        actions: [
          IconButton(
            tooltip: AglL10n.of(context)!.actionRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<NewsService>().fetchAllNews(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSourceFilter(),
          Expanded(child: _buildNewsList()),
        ],
      ),
    );
  }

  Widget _buildSourceFilter() {
    return Consumer<NewsService>(
      builder: (context, service, _) {
        final sources = ['All', ...NewsService.feeds.map((f) => f.name)];
        return Container(
          height: 48,
          color: const Color(0xFF0D1B2A),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: sources.length,
            itemBuilder: (context, i) {
              final source = sources[i];
              final isActive = service.activeSource == source;
              return GestureDetector(
                onTap: () => service.fetchFeedBySource(source),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF00BCD4)
                        : const Color(0xFF112240),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF00BCD4)
                          : Colors.white24,
                    ),
                  ),
                  child: Text(
                    source,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.black : Colors.white70,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNewsList() {
    return Consumer<NewsService>(
      builder: (context, service, _) {
        if (service.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF00BCD4)),
                SizedBox(height: 16),
                Text(
                  'Fetching aviation news...',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          );
        }

        if (service.articles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.newspaper, color: Colors.white38, size: 48),
                const SizedBox(height: 12),
                Text(
                  'No articles loaded',
                  style: GoogleFonts.inter(color: Colors.white54),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => service.fetchAllNews(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF00BCD4),
          backgroundColor: const Color(0xFF112240),
          onRefresh: () => service.fetchAllNews(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: service.articles.length,
            itemBuilder: (context, i) => _buildArticleCard(service.articles[i]),
          ),
        );
      },
    );
  }

  Widget _buildArticleCard(NewsArticle article) {
    final sourceColors = {
      'AVweb': const Color(0xFF1565C0),
      'AOPA': const Color(0xFF00695C),
      'Aviation Week': const Color(0xFF4A148C),
      'FLYING Mag': const Color(0xFFE65100),
      'FAA News': const Color(0xFF1B5E20),
    };
    final color = sourceColors[article.source] ?? const Color(0xFF37474F);

    return GestureDetector(
      onTap: () => _openArticle(article.link),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF112240),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source badge + date
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      article.source,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(article.pubDate),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                article.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Description
            if (article.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  article.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white60,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Read more
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: color.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Read full article',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF00BCD4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.open_in_new,
                    size: 12,
                    color: Color(0xFF00BCD4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String pubDate) {
    if (pubDate.isEmpty) return '';
    try {
      // Try to extract just the date portion
      final parts = pubDate.split(' ');
      if (parts.length >= 4) {
        return '${parts[1]} ${parts[2]} ${parts[3]}';
      }
      return pubDate.substring(0, pubDate.length.clamp(0, 16));
    } catch (_) {
      return pubDate.length > 16 ? pubDate.substring(0, 16) : pubDate;
    }
  }

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Cannot open URL: $e');
    }
  }
}
