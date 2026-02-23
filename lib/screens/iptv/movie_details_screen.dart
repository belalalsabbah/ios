import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/xtream_service.dart';

class MovieDetailsScreen extends StatefulWidget {
  final VodItem movie;
  final XtreamService xtreamService;

  const MovieDetailsScreen({
    super.key,
    required this.movie,
    required this.xtreamService,
  });

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  Map<String, dynamic>? _movieInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMovieInfo();
  }

  Future<void> _loadMovieInfo() async {
    final info = await widget.xtreamService.getMovieInfo(widget.movie.streamId);
    setState(() {
      _movieInfo = info;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.movie.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.movie.streamIcon,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade900,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.deepPurple,
                      child: const Icon(Icons.movie, size: 100, color: Colors.white),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.play_circle_fill, size: 40),
                onPressed: () {
                  // تشغيل الفيلم
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_movieInfo != null) ...[
                    // معلومات الفيلم
                    if (_movieInfo!['info'] != null) ...[
                      _buildInfoSection('عن الفيلم', _movieInfo!['info']['description'] ?? 'لا يوجد وصف'),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          _buildInfoChip(Icons.timer, 'المدة', _movieInfo!['info']['duration'] ?? 'غير معروف'),
                          const SizedBox(width: 8),
                          _buildInfoChip(Icons.calendar_today, 'السنة', _movieInfo!['info']['releasedate']?.toString().split('-')[0] ?? 'غير معروف'),
                          const SizedBox(width: 8),
                          _buildInfoChip(Icons.star, 'التقييم', _movieInfo!['info']['rating']?.toString() ?? '0'),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      const Divider(),
                      
                      // الممثلين
                      if (_movieInfo!['info']['cast'] != null && _movieInfo!['info']['cast'].toString().isNotEmpty)
                        _buildInfoSection('الممثلين', _movieInfo!['info']['cast']),
                      
                      // المخرج
                      if (_movieInfo!['info']['director'] != null && _movieInfo!['info']['director'].toString().isNotEmpty)
                        _buildInfoSection('إخراج', _movieInfo!['info']['director']),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.deepPurple),
          const SizedBox(width: 4),
          Text('$label: $value'),
        ],
      ),
    );
  }
}