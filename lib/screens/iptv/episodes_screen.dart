import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../services/xtream_service.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EpisodesScreen extends StatefulWidget {
  final XtreamService xtreamService;
  final SeriesItem series;
  
  const EpisodesScreen({
    super.key, 
    required this.xtreamService,
    required this.series,
  });

  @override
  State<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends State<EpisodesScreen> {
  Map<int, List<dynamic>> _episodesBySeason = {};
  bool _loading = true;
  String? _error;
  
  List<SeriesItem> _suggestedSeries = [];
  bool _loadingSuggested = false;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
    _loadSuggestedSeries();
  }

  Future<void> _loadEpisodes() async {
    try {
      print('🔄 جلب حلقات المسلسل: ${widget.series.name} (ID: ${widget.series.streamId})');
      
      final info = await widget.xtreamService.getSeriesInfo(widget.series.streamId);
      
      if (info == null) {
        setState(() {
          _error = 'فشل تحميل الحلقات - البروكسي غير متاح';
          _loading = false;
        });
        return;
      }
      
      print('=' * 60);
      print('📦 نوع البيانات المرتجعة: ${info.runtimeType}');
      
      if (info.containsKey('episodes')) {
        print('📺 نوع episodes: ${info['episodes'].runtimeType}');
        
        final episodesData = info['episodes'];
        
        if (episodesData is Map) {
          print('📊 البيانات على شكل Map (مقسمة حسب المواسم)');
          final Map<int, List<dynamic>> tempMap = {};
          int totalSeasons = 0;
          
          episodesData.forEach((season, episodes) {
            totalSeasons++;
            if (episodes is List) {
              final seasonNumber = int.tryParse(season.toString()) ?? 0;
              tempMap[seasonNumber] = episodes.cast<dynamic>().toList();
              print('   موسم $seasonNumber: ${episodes.length} حلقة');
            }
          });
          
          print('📊 إجمالي المواسم: $totalSeasons');
          
          setState(() {
            _episodesBySeason = tempMap;
            _loading = false;
          });
          
        } else if (episodesData is List) {
          print('📊 البيانات على شكل List (بدون مواسم)');
          print('📊 عدد الحلقات: ${episodesData.length}');
          
          setState(() {
            _episodesBySeason = {1: episodesData.cast<dynamic>().toList()};
            _loading = false;
          });
          
        } else {
          print('⚠️ episodesData ليس Map ولا List');
          setState(() {
            _error = 'تنسيق البيانات غير معروف';
            _loading = false;
          });
        }
      } else {
        print('❌ لا يوجد مفتاح "episodes" في البيانات');
        setState(() {
          _error = 'لا توجد حلقات لهذا المسلسل';
          _loading = false;
        });
      }
      
      print('=' * 60);
      
    } catch (e) {
      print('❌ خطأ عام في تحميل الحلقات: $e');
      setState(() {
        _error = 'فشل تحميل الحلقات: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadSuggestedSeries() async {
    setState(() => _loadingSuggested = true);
    try {
      final allSeries = await widget.xtreamService.getSeries();
      setState(() {
        _suggestedSeries = allSeries
            .where((s) => 
                s.categoryId == widget.series.categoryId && 
                s.streamId != widget.series.streamId)
            .take(15)
            .toList();
        _loadingSuggested = false;
      });
    } catch (e) {
      print('⚠️ خطأ في تحميل المسلسلات المقترحة: $e');
      setState(() => _loadingSuggested = false);
    }
  }

  Widget _buildEpisodeTile(dynamic episode) {
    String episodeTitle = episode['title']?.toString() ?? 
                         episode['show_episode_name']?.toString() ?? 
                         'حلقة';
    
    String episodeNum = '';
    if (episode['episode_num'] != null) {
      episodeNum = 'حلقة ${episode['episode_num']}';
    } else if (episode['season'] != null && episode['episode'] != null) {
      episodeNum = 'م${episode['season']} - ح${episode['episode']}';
    }

    String? duration;
    String? plot;
    String? imageUrl;
    if (episode['info'] != null && episode['info'] is Map) {
      duration = episode['info']['duration']?.toString();
      plot = episode['info']['plot']?.toString();
      if (plot != null && plot.length > 100) plot = plot.substring(0, 100) + '...';
      imageUrl = episode['info']['movie_image']?.toString();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.orange.shade100,
                    child: const Icon(Icons.movie, color: Colors.orange),
                  ),
                )
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.orange.shade100,
                  child: const Icon(Icons.movie, color: Colors.orange),
                ),
        ),
        title: Text(
          episodeTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (episodeNum.isNotEmpty)
              Text(episodeNum, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            if (duration != null)
              Text('المدة: $duration', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            if (plot != null && plot.isNotEmpty)
              Text(plot, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_circle_fill, color: Colors.orange, size: 35),
        ),
        onTap: () => _playEpisode(episode),
      ),
    );
  }

  void _playEpisode(dynamic episode) async {
    try {
      WakelockPlus.enable();
      
      String extension = 'mp4';
      if (episode['container_extension'] != null) {
        extension = episode['container_extension'].toString();
      }
      
      int episodeId = 0;
      if (episode['id'] != null) {
        if (episode['id'] is String) {
          episodeId = int.tryParse(episode['id']) ?? 0;
        } else if (episode['id'] is int) {
          episodeId = episode['id'];
        } else if (episode['id'] is double) {
          episodeId = (episode['id'] as double).toInt();
        }
      }
      
      if (episodeId == 0 && episode['episode_id'] != null) {
        if (episode['episode_id'] is String) {
          episodeId = int.tryParse(episode['episode_id']) ?? 0;
        } else if (episode['episode_id'] is int) {
          episodeId = episode['episode_id'];
        } else if (episode['episode_id'] is double) {
          episodeId = (episode['episode_id'] as double).toInt();
        }
      }
      
      if (episodeId == 0) {
        throw Exception('معرف الحلقة غير صالح');
      }
      
      final url = await widget.xtreamService.getEpisodeUrl(episodeId, extension);
      print('🎬 تشغيل الحلقة: $url');
      
      String episodeTitle = episode['title']?.toString() ?? 
                           episode['show_episode_name']?.toString() ?? 
                           'حلقة';
      
      String episodeNum = '';
      if (episode['episode_num'] != null) {
        episodeNum = 'حلقة ${episode['episode_num']}';
      } else if (episode['season'] != null && episode['episode'] != null) {
        episodeNum = 'م${episode['season']} - ح${episode['episode']}';
      }
      
      String fullTitle = '$episodeTitle ${episodeNum.isNotEmpty ? "($episodeNum)" : ""}';
      
      VideoPlayerController controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
      await controller.initialize();
      
      if (!mounted) return;
      
      ChewieController chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                Text('خطأ في تشغيل الفيديو: $errorMessage'),
              ],
            ),
          );
        },
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _EpisodePlayerScreen(
            episodeTitle: fullTitle,
            chewieController: chewieController,
            xtreamService: widget.xtreamService,
            seriesId: widget.series.streamId,
            currentEpisodeId: episodeId,
            allEpisodes: _episodesBySeason.values.expand((e) => e).toList(),
          ),
        ),
      ).then((_) {
        controller.dispose();
        chewieController.dispose();
        WakelockPlus.disable();
      });
      
    } catch (e) {
      WakelockPlus.disable();
      print('❌ خطأ في تشغيل الحلقة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تشغيل الحلقة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openSeriesDetails(SeriesItem series) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EpisodesScreen(
          xtreamService: widget.xtreamService,
          series: series,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.series.name,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
      drawer: _buildSuggestedSeriesDrawer(),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 20),
                  Text('جاري تحميل الحلقات...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 80),
                      const SizedBox(height: 20),
                      Text(_error!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadEpisodes,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _episodesBySeason.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.movie, size: 80, color: Colors.grey),
                          const SizedBox(height: 20),
                          Text('لا توجد حلقات', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _episodesBySeason.keys.length,
                      itemBuilder: (context, index) {
                        final season = _episodesBySeason.keys.elementAt(index);
                        final episodes = _episodesBySeason[season]!;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ExpansionTile(
                            title: Text('الموسم $season', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${episodes.length} حلقة'),
                            children: episodes.map((ep) => _buildEpisodeTile(ep)).toList(),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildSuggestedSeriesDrawer() {
    return Drawer(
      width: 300,
      child: Container(
        color: Colors.orange.shade50,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade700, Colors.orange.shade500],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'مسلسلات مقترحة',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'من نفس التصنيف',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loadingSuggested
                  ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                  : _suggestedSeries.isEmpty
                      ? const Center(child: Text('لا توجد مسلسلات مقترحة'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _suggestedSeries.length,
                          itemBuilder: (context, index) {
                            final series = _suggestedSeries[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: series.streamIcon.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: series.streamIcon,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            color: Colors.orange.shade100,
                                            child: const Icon(Icons.tv, color: Colors.orange),
                                          ),
                                        )
                                      : Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.orange.shade100,
                                          child: const Icon(Icons.tv, color: Colors.orange),
                                        ),
                                ),
                                title: Text(
                                  series.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  widget.xtreamService.getSeriesCategoryName(series.categoryId),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                trailing: Icon(Icons.arrow_forward, color: Colors.orange.shade300),
                                onTap: () {
                                  Navigator.pop(context);
                                  _openSeriesDetails(series);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
}

// شاشة تشغيل الحلقة (محسنة لعناصر التحكم)
class _EpisodePlayerScreen extends StatefulWidget {
  final String episodeTitle;
  final ChewieController chewieController;
  final XtreamService xtreamService;
  final int seriesId;
  final int currentEpisodeId;
  final List<dynamic> allEpisodes;

  const _EpisodePlayerScreen({
    required this.episodeTitle,
    required this.chewieController,
    required this.xtreamService,
    required this.seriesId,
    required this.currentEpisodeId,
    required this.allEpisodes,
  });

  @override
  State<_EpisodePlayerScreen> createState() => _EpisodePlayerScreenState();
}

class _EpisodePlayerScreenState extends State<_EpisodePlayerScreen> {
  bool _isFullScreen = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime _lastTapTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleOrientation() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      }
    });
  }

  void _adjustBrightness(bool increase) async {
    try {
      double brightness = await ScreenBrightness.instance.current;
      if (increase && brightness < 1.0) {
        await ScreenBrightness.instance.setScreenBrightness(brightness + 0.1);
      } else if (!increase && brightness > 0.0) {
        await ScreenBrightness.instance.setScreenBrightness(brightness - 0.1);
      }
    } catch (e) {
      print('خطأ في تعديل السطوع: $e');
    }
  }

  void _playEpisode(dynamic episode) async {
    try {
      String extension = episode['container_extension']?.toString() ?? 'mp4';
      int episodeId = int.tryParse(episode['id']?.toString() ?? episode['episode_id']?.toString() ?? '0') ?? 0;
      if (episodeId == 0) return;
      
      final url = await widget.xtreamService.getEpisodeUrl(episodeId, extension);
      String episodeTitle = episode['title']?.toString() ?? episode['show_episode_name']?.toString() ?? 'حلقة';
      
      Navigator.pop(context);
      
      VideoPlayerController controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      
      ChewieController newChewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => _EpisodePlayerScreen(
            episodeTitle: episodeTitle,
            chewieController: newChewieController,
            xtreamService: widget.xtreamService,
            seriesId: widget.seriesId,
            currentEpisodeId: episodeId,
            allEpisodes: widget.allEpisodes,
          ),
        ),
      );
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _toggleOrientation();
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildEpisodesDrawer(),
        body: Stack(
          children: [
            // مشغل الفيديو
            Chewie(controller: widget.chewieController),

            // طبقة شفافة لالتقاط اللمسات (تغطي كامل الشاشة)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final now = DateTime.now();
                  if (now.difference(_lastTapTime) < const Duration(milliseconds: 300)) return;
                  _lastTapTime = now;

                  if (mounted) {
                    setState(() {
                      _showControls = true;
                    });
                    _startControlsTimer(); // إعادة تشغيل التايمر
                  }
                  print('👆 تم الضغط على الشاشة - إظهار التحكمات');
                },
              ),
            ),

            // طبقة التحكمات
            if (_showControls) ...[
              Container(color: Colors.black.withOpacity(0.3)),
              
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                        ),
                      ),
                      const Spacer(),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            widget.episodeTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                          onPressed: _toggleOrientation,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              Positioned(
                right: 16,
                top: 150,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.brightness_7, color: Colors.white),
                        onPressed: () => _adjustBrightness(true),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.brightness_4, color: Colors.white),
                        onPressed: () => _adjustBrightness(false),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (!_isFullScreen)
                Positioned(
                  top: 100,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesDrawer() {
    final otherEpisodes = widget.allEpisodes.where((e) {
      int eId = int.tryParse(e['id']?.toString() ?? '0') ?? 0;
      return eId != widget.currentEpisodeId;
    }).toList();

    return Drawer(
      width: 300,
      child: Container(
        color: Colors.orange.shade50,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.orange.shade500]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('حلقات أخرى', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('اختر حلقة أخرى', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
            Expanded(
              child: otherEpisodes.isEmpty
                  ? const Center(child: Text('لا توجد حلقات أخرى'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: otherEpisodes.length,
                      itemBuilder: (context, index) {
                        final episode = otherEpisodes[index];
                        String title = episode['title']?.toString() ?? episode['show_episode_name']?.toString() ?? 'حلقة';
                        String? imageUrl;
                        if (episode['info'] != null && episode['info']['movie_image'] != null) {
                          imageUrl = episode['info']['movie_image'];
                        }
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => const CircleAvatar(
                                        backgroundColor: Colors.orange,
                                        child: Icon(Icons.movie, color: Colors.white),
                                      ),
                                    )
                                  : const CircleAvatar(
                                      backgroundColor: Colors.orange,
                                      child: Icon(Icons.movie, color: Colors.white),
                                    ),
                            ),
                            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => _playEpisode(episode),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    try {
      if (widget.chewieController.videoPlayerController.value.isInitialized) {
        widget.chewieController.videoPlayerController.pause();
      }
    } catch (e) {
      print('⚠️ خطأ في إيقاف المشغل مؤقتاً: $e');
    }
    try {
      widget.chewieController.videoPlayerController.dispose();
    } catch (e) {
      print('⚠️ خطأ في التخلص من VideoPlayerController: $e');
    }
    try {
      widget.chewieController.dispose();
    } catch (e) {
      print('⚠️ خطأ في التخلص من ChewieController: $e');
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}