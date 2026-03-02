// FILE: lib/screens/iptv/movie_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/xtream_service.dart';
import 'video_player_screen.dart';

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
  List<dynamic> _episodes = [];
  List<VodItem> _similarMovies = [];

  @override
  void initState() {
    super.initState();
    _loadMovieInfo();
    _loadSimilarMovies();
  }

  Future<void> _loadMovieInfo() async {
    try {
      final info = await widget.xtreamService.getMovieInfo(widget.movie.streamId);
      List<dynamic> episodes = [];
      // إذا فيه مواسم/حلقات
      if (info != null && info['movie_data'] != null) {
        if (info['movie_data']['episodes'] != null) {
          episodes = info['movie_data']['episodes'];
        }
      }

      setState(() {
        _movieInfo = info;
        _episodes = episodes;
        _loading = false;
      });
    } catch (e) {
      print('❌ خطأ في تحميل معلومات الفيلم: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSimilarMovies() async {
    try {
      final allMovies = await widget.xtreamService.getMovies();
      setState(() {
        _similarMovies = allMovies
            .where((m) => m.categoryId == widget.movie.categoryId && m.streamId != widget.movie.streamId)
            .take(10)
            .toList();
      });
    } catch (e) {
      print('⚠️ خطأ في تحميل أفلام مشابهة: $e');
    }
  }

  void _playEpisode(dynamic episode) async {
    try {
      final url = await widget.xtreamService.getMovieUrl(
        episode['stream_id'] ?? widget.movie.streamId,
        episode['container_extension'] ?? 'mp4',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            title: episode['name'] ?? widget.movie.name,
            url: url,
            xtreamService: widget.xtreamService,
          ),
        ),
      );
    } catch (e) {
      print('❌ خطأ في تشغيل الحلقة: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تشغيل الحلقة: $e')),
      );
    }
  }

  // دالة لعرض التقييم على شكل نجوم
  Widget _buildRating(double rating) {
    int fullStars = rating.floor();
    bool hasHalf = (rating - fullStars) >= 0.5;
    return Row(
      children: List.generate(5, (index) {
        if (index < fullStars) return const Icon(Icons.star, color: Colors.amber, size: 16);
        if (index == fullStars && hasHalf) return const Icon(Icons.star_half, color: Colors.amber, size: 16);
        return const Icon(Icons.star_border, color: Colors.amber, size: 16);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3),
                  ],
                ),
              ),
              background: Hero(
                tag: 'movie_${widget.movie.streamId}',
                child: Stack(
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
                    // زر تشغيل كبير في الصورة
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton(
                        onPressed: _episodes.isEmpty
                            ? () => _playEpisode({'stream_id': widget.movie.streamId, 'container_extension': 'mp4'})
                            : null,
                        child: const Icon(Icons.play_arrow),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.play_circle_fill, size: 40),
                onPressed: _episodes.isEmpty
                    ? () => _playEpisode({'stream_id': widget.movie.streamId, 'container_extension': 'mp4'})
                    : null,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_movieInfo != null && _movieInfo!['info'] != null) ...[
                          _buildInfoSection(
                              'عن الفيلم', _movieInfo!['info']['description'] ?? 'لا يوجد وصف'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildInfoChip(Icons.timer, 'المدة',
                                  _movieInfo!['info']['duration'] ?? 'غير معروف'),
                              const SizedBox(width: 8),
                              _buildInfoChip(Icons.calendar_today, 'السنة',
                                  _movieInfo!['info']['releasedate']?.toString().split('-')[0] ?? 'غير معروف'),
                              const SizedBox(width: 8),
                              _buildInfoChip(Icons.star, 'التقييم',
                                  _movieInfo!['info']['rating']?.toString() ?? '0'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // عرض التقييم بالنجوم
                          if (_movieInfo!['info']['rating'] != null)
                            _buildRating(double.tryParse(_movieInfo!['info']['rating'].toString()) ?? 0),
                          const SizedBox(height: 8),
                          const Divider(),
                          if (_movieInfo!['info']['cast'] != null &&
                              _movieInfo!['info']['cast'].toString().isNotEmpty)
                            _buildInfoSection('الممثلين', _movieInfo!['info']['cast']),
                          if (_movieInfo!['info']['director'] != null &&
                              _movieInfo!['info']['director'].toString().isNotEmpty)
                            _buildInfoSection('إخراج', _movieInfo!['info']['director']),
                          const SizedBox(height: 16),
                        ],
                        if (_episodes.isNotEmpty) ...[
                          const Text(
                            'الحلقات',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _episodes.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final episode = _episodes[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: episode['stream_icon'] != null
                                      ? CachedNetworkImageProvider(episode['stream_icon'])
                                      : null,
                                  child: episode['stream_icon'] == null
                                      ? const Icon(Icons.tv, color: Colors.white)
                                      : null,
                                  backgroundColor: Colors.deepPurple.shade300,
                                ),
                                title: Text(episode['name'] ?? 'حلقة ${index + 1}'),
                                subtitle: episode['releasedate'] != null
                                    ? Text('تاريخ الإصدار: ${episode['releasedate']}')
                                    : null,
                                trailing: const Icon(Icons.play_arrow, color: Colors.redAccent),
                                onTap: () => _playEpisode(episode),
                              );
                            },
                          ),
                        ],
                        if (_similarMovies.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'أفلام مشابهة',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 150,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _similarMovies.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final movie = _similarMovies[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MovieDetailsScreen(
                                          movie: movie,
                                          xtreamService: widget.xtreamService,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: movie.streamIcon,
                                      width: 100,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.deepPurple.shade200,
                                        child: const Icon(Icons.movie, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
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
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(content, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
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