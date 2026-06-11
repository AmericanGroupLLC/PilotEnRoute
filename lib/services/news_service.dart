import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// Aviation News Service — uses public RSS feeds (no API key required)
/// Sources:
///   - Aviation Week Network RSS
///   - FLYING Magazine RSS
///   - FAA News RSS
///   - AOPA News RSS
///   - AVweb RSS
class NewsArticle {
  final String title;
  final String description;
  final String link;
  final String pubDate;
  final String source;
  final String? imageUrl;

  NewsArticle({
    required this.title,
    required this.description,
    required this.link,
    required this.pubDate,
    required this.source,
    this.imageUrl,
  });
}

class RssFeed {
  final String name;
  final String url;
  final String icon;

  const RssFeed({required this.name, required this.url, required this.icon});
}

class NewsService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  List<NewsArticle> _articles = [];
  String _activeSource = 'All';

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<NewsArticle> get articles => _articles;
  String get activeSource => _activeSource;

  // Public aviation RSS feeds — no auth required
  static const List<RssFeed> feeds = [
    RssFeed(
      name: 'AVweb',
      url: 'https://www.avweb.com/feed/',
      icon: '✈️',
    ),
    RssFeed(
      name: 'AOPA',
      url: 'https://www.aopa.org/news-and-media/all-news/rss',
      icon: '🛩️',
    ),
    RssFeed(
      name: 'Aviation Week',
      url: 'https://aviationweek.com/awn-rss/feed',
      icon: '📰',
    ),
    RssFeed(
      name: 'FLYING Mag',
      url: 'https://www.flyingmag.com/feed/',
      icon: '🌐',
    ),
    RssFeed(
      name: 'FAA News',
      url: 'https://www.faa.gov/rss/news_update.xml',
      icon: '🏛️',
    ),
  ];

  Future<void> fetchAllNews() async {
    _isLoading = true;
    _error = null;
    _articles = [];
    notifyListeners();

    final allArticles = <NewsArticle>[];

    for (final feed in feeds) {
      try {
        final articles = await _fetchFeed(feed);
        allArticles.addAll(articles);
      } catch (e) {
        debugPrint('Failed to fetch ${feed.name}: $e');
      }
    }

    // Sort by date (newest first) — best effort
    allArticles.sort((a, b) => b.pubDate.compareTo(a.pubDate));
    _articles = allArticles.take(50).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchFeedBySource(String sourceName) async {
    _isLoading = true;
    _activeSource = sourceName;
    _error = null;
    notifyListeners();

    if (sourceName == 'All') {
      await fetchAllNews();
      return;
    }

    final feed = feeds.firstWhere(
      (f) => f.name == sourceName,
      orElse: () => feeds.first,
    );

    try {
      final articles = await _fetchFeed(feed);
      _articles = articles;
    } catch (e) {
      _error = 'Failed to load $sourceName news';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<NewsArticle>> _fetchFeed(RssFeed feed) async {
    final articles = <NewsArticle>[];
    try {
      final response = await http.get(
        Uri.parse(feed.url),
        headers: {
          'User-Agent': 'PilotEnRoute/1.0 (Aviation Training App)',
          'Accept': 'application/rss+xml, application/xml, text/xml',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');

        for (final item in items.take(10)) {
          final title = item.findElements('title').firstOrNull?.innerText ?? '';
          final description = _stripHtml(
            item.findElements('description').firstOrNull?.innerText ?? '',
          );
          final link = item.findElements('link').firstOrNull?.innerText ??
              item.findElements('guid').firstOrNull?.innerText ??
              '';
          final pubDate =
              item.findElements('pubDate').firstOrNull?.innerText ?? '';
          final imageUrl = _extractImageUrl(item);

          if (title.isNotEmpty) {
            articles.add(NewsArticle(
              title: title,
              description: description.length > 200
                  ? '${description.substring(0, 200)}...'
                  : description,
              link: link,
              pubDate: pubDate,
              source: feed.name,
              imageUrl: imageUrl,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('RSS parse error for ${feed.name}: $e');
    }
    return articles;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String? _extractImageUrl(XmlElement item) {
    // Try media:content
    final media = item.findElements('media:content').firstOrNull;
    if (media != null) {
      return media.getAttribute('url');
    }
    // Try enclosure
    final enclosure = item.findElements('enclosure').firstOrNull;
    if (enclosure != null) {
      final type = enclosure.getAttribute('type') ?? '';
      if (type.startsWith('image/')) {
        return enclosure.getAttribute('url');
      }
    }
    // Try image in description
    final desc = item.findElements('description').firstOrNull?.innerText ?? '';
    final imgMatch = RegExp(r'src="([^"]+\.(jpg|jpeg|png|webp))"').firstMatch(desc);
    return imgMatch?.group(1);
  }
}
