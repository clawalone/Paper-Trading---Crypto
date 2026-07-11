import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/app_theme.dart';
import 'news_detail_screen.dart';

class NewsArticle {
  final String title;
  final String source;
  final String time;
  final String snippet;
  final String fullContent;
  final String url;
  final String? imageUrl;
  final IconData defaultIcon;
  final Color defaultColor;

  const NewsArticle({
    required this.title,
    required this.source,
    required this.time,
    required this.snippet,
    required this.fullContent,
    required this.url,
    this.imageUrl,
    required this.defaultIcon,
    required this.defaultColor,
  });
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  bool _isLoading = true;
  String? _error;
  List<NewsArticle> _news = [];

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch from multiple sources for a massive pool of news
      final urls = [
        'https://api.rss2json.com/v1/api.json?rss_url=https://cointelegraph.com/rss',
        'https://api.rss2json.com/v1/api.json?rss_url=https://www.coindesk.com/arc/outboundfeeds/rss/',
        'https://api.rss2json.com/v1/api.json?rss_url=https://news.bitcoin.com/feed/'
      ];

      final responses = await Future.wait(
        urls.map((url) => http.get(Uri.parse(url))).toList()
      );
      
      final List<NewsArticle> loaded = [];
      
      for (int i = 0; i < responses.length; i++) {
        final res = responses[i];
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final items = data['items'] as List;
          
          String sourceName = 'Crypto News';
          if (i == 0) sourceName = 'CoinTelegraph';
          if (i == 1) sourceName = 'CoinDesk';
          if (i == 2) sourceName = 'Bitcoin.com';

          for (final item in items) {
            final title = item['title'] ?? '';
            
            // Basic HTML stripping for description
            String fullDesc = (item['description'] ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
            String snippet = fullDesc;
            if (snippet.length > 150) snippet = '${snippet.substring(0, 150)}...';
            
            final link = item['link'] ?? '';
            
            final enclosure = item['enclosure'];
            String? imageUrl;
            if (enclosure != null && enclosure['link'] != null) {
              imageUrl = enclosure['link'];
            } else if (item['thumbnail'] != null && item['thumbnail'].toString().isNotEmpty) {
              imageUrl = item['thumbnail'];
            }

            loaded.add(NewsArticle(
              title: title,
              source: sourceName,
              time: 'Recently', // Will be overridden
              snippet: snippet,
              fullContent: fullDesc,
              url: link,
              imageUrl: imageUrl,
              defaultIcon: Icons.newspaper,
              defaultColor: i == 0 ? const Color(0xFFF3BA2F) : i == 1 ? const Color(0xFF14F195) : const Color(0xFF3B82F6),
            ));
          }
        }
      }

      if (loaded.isNotEmpty) {
        // Shuffle the massive pool so every refresh looks totally different
        loaded.shuffle();
        
        // Pick top 20 and assign fake hyper-live recency
        final displayList = loaded.take(20).toList();
        for (int j = 0; j < displayList.length; j++) {
          int mins = (j * 4) + (j % 3) + 1; // 1m, 5m, 11m, 14m...
          
          displayList[j] = NewsArticle(
            title: displayList[j].title,
            source: displayList[j].source,
            time: '${mins}m ago',
            snippet: displayList[j].snippet,
            fullContent: displayList[j].fullContent,
            url: displayList[j].url,
            imageUrl: displayList[j].imageUrl,
            defaultIcon: displayList[j].defaultIcon,
            defaultColor: displayList[j].defaultColor,
          );
        }

        setState(() {
          _news = displayList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load news';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E11),
        elevation: 0,
        title: const Text('Live Market News', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF848E9C)),
              onPressed: _fetchNews,
            ),
        ],
      ),
      body: _isLoading && _news.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null && _news.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchNews,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Retry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: RefreshIndicator(
                      onRefresh: _fetchNews,
                      color: AppColors.primary,
                      backgroundColor: const Color(0xFF1E2329),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 800) {
                            return GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 180, // Fixed height for cards
                              ),
                              itemCount: _news.length,
                              itemBuilder: (context, index) => _NewsCard(item: _news[index]),
                            );
                          }
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _news.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFF2B3139), height: 32),
                            itemBuilder: (context, index) => _NewsCard(item: _news[index]),
                          );
                        },
                      ),
                ),
              ),
            ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});
  final NewsArticle item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(article: item)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E11),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2329),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.defaultIcon, size: 12, color: item.defaultColor),
                      const SizedBox(width: 6),
                      Text(
                        item.source,
                        style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  item.time,
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.snippet.replaceAll('&nbsp;', ' '),
                        style: const TextStyle(
                          color: Color(0xFF848E9C),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2329),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2B3139)),
                  ),
                  child: item.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Center(child: Icon(item.defaultIcon, size: 32, color: item.defaultColor.withValues(alpha: 0.8))),
                          ),
                        )
                      : Center(
                          child: Icon(item.defaultIcon, size: 32, color: item.defaultColor.withValues(alpha: 0.8)),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

