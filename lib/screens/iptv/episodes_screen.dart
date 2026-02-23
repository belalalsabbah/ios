import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../services/xtream_service.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async'; // ✅ أضف هذا

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
  List<dynamic> _episodes = [];
  bool _loading = true;
  String? _error;
  
  // ✅ قائمة جانبية للمسلسلات المقترحة
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
      print('🔄 جلب حلقات المسلسل: ${widget.series.name}');
      
      final info = await widget.xtreamService.getSeriesInfo(widget.series.streamId);
      
      if (info != null && info['episodes'] != null) {
        final episodesData = info['episodes'];
        
        if (episodesData is Map) {
          List<dynamic> allEpisodes = [];
          episodesData.forEach((season, episodes) {
            if (episodes is List) {
              allEpisodes.addAll(episodes);
            }
          });
          setState(() {
            _episodes = allEpisodes;
            _loading = false;
          });
          print('✅ تم تحميل ${allEpisodes.length} حلقة');
        } else if (episodesData is List) {
          setState(() {
            _episodes = episodesData;
            _loading = false;
          });
          print('✅ تم تحميل ${episodesData.length} حلقة');
        } else {
          setState(() {
            _error = 'لا توجد حلقات لهذا المسلسل';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = 'لا توجد حلقات لهذا المسلسل';
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل الحلقات: $e');
      setState(() {
        _error = 'فشل تحميل الحلقات: $e';
        _loading = false;
      });
    }
  }

  // ✅ تحميل مسلسلات مقترحة من نفس التصنيف
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

  // في كلاس _EpisodesScreenState
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
    
    String url = widget.xtreamService.getEpisodeUrl(episodeId, extension);
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
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
      ),
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
        child: const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
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
          seriesId: widget.series.streamId, // ✅ هذا هو seriesId الصحيح
          currentEpisodeId: episodeId,
          allEpisodes: _episodes, // ✅ هذا هو allEpisodes
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
          // ✅ زر القائمة الجانبية في AppBar
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ],
      ),
      drawer: _buildSuggestedSeriesDrawer(), // ✅ القائمة الجانبية
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
                      Text(
                        _error!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
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
              : _episodes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.movie, size: 80, color: Colors.grey),
                          const SizedBox(height: 20),
                          Text(
                            'لا توجد حلقات',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _episodes.length,
                      itemBuilder: (context, index) {
                        final episode = _episodes[index];
                        
                        String episodeTitle = episode['title']?.toString() ?? 
                                             episode['show_episode_name']?.toString() ?? 
                                             'حلقة ${index + 1}';
                        
                        String episodeNum = '';
                        if (episode['episode_num'] != null) {
                          episodeNum = 'حلقة ${episode['episode_num']}';
                        } else if (episode['season'] != null && episode['episode'] != null) {
                          episodeNum = 'م${episode['season']} - ح${episode['episode']}';
                        }
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.movie,
                                color: Colors.orange,
                                size: 25,
                              ),
                            ),
                            title: Text(
                              episodeTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: episodeNum.isNotEmpty 
                                ? Text(episodeNum, style: TextStyle(color: Colors.grey.shade600))
                                : null,
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_circle_fill,
                                color: Colors.orange,
                                size: 35,
                              ),
                            ),
                            onTap: () => _playEpisode(episode),
                          ),
                        );
                      },
                    ),
    );
  }

  // ✅ بناء القائمة الجانبية للمسلسلات المقترحة
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
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
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  backgroundImage: series.streamIcon.isNotEmpty
                                      ? CachedNetworkImageProvider(series.streamIcon)
                                      : null,
                                  child: series.streamIcon.isEmpty
                                      ? const Icon(Icons.tv, color: Colors.orange)
                                      : null,
                                ),
                                title: Text(
                                  series.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  widget.xtreamService.getSeriesCategoryName(series.categoryId),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward,
                                  color: Colors.orange.shade300,
                                ),
                                onTap: () {
                                  Navigator.pop(context); // إغلاق القائمة
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

// ✅ شاشة منفصلة لتشغيل الحلقة مع قائمة جانبية
// ✅ شاشة منفصلة لتشغيل الحلقة مع قائمة جانبية
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
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, 
          overlays: [SystemUiOverlay.bottom]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, 
          overlays: SystemUiOverlay.values);
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
      String extension = 'mp4';
      if (episode['container_extension'] != null) {
        extension = episode['container_extension'].toString();
      }
      
      int episodeId = 0;
      if (episode['id'] != null) {
        episodeId = int.tryParse(episode['id'].toString()) ?? 0;
      }
      
      if (episodeId == 0 && episode['episode_id'] != null) {
        episodeId = int.tryParse(episode['episode_id'].toString()) ?? 0;
      }
      
      if (episodeId == 0) return;
      
      final url = widget.xtreamService.getEpisodeUrl(episodeId, extension);
      
      String episodeTitle = episode['title']?.toString() ?? 
                           episode['show_episode_name']?.toString() ?? 
                           'حلقة';
      
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
        body: GestureDetector(
          onTap: () {
            setState(() {
              _showControls = true;
            });
            _controlsTimer?.cancel();
            _controlsTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _showControls = false;
                });
              }
            });
          },
          child: Stack(
            children: [
              Chewie(controller: widget.chewieController),
              
              if (_showControls) ...[
                Container(color: Colors.black.withOpacity(0.3)),
              ],
              
              // الأزرار العلوية
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // ✅ زر القائمة الجانبية - ثابت دائماً
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // ✅ عنوان الحلقة - يظهر مع التحكمات
                      if (_showControls)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.episodeTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      
                      const Spacer(),
                      
                      // ✅ زر ملء الشاشة - ثابت دائماً
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                            color: Colors.white,
                          ),
                          onPressed: _toggleOrientation,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // أزرار السطوع - تظهر مع التحكمات فقط
              if (_showControls)
                Positioned(
                  right: 16,
                  top: 150,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.brightness_7, color: Colors.white),
                          onPressed: () => _adjustBrightness(true),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.brightness_4, color: Colors.white),
                          onPressed: () => _adjustBrightness(false),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // زر الرجوع - يظهر مع التحكمات فقط في الوضع العمودي
              if (_showControls && !_isFullScreen)
                Positioned(
                  top: 100,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodesDrawer() {
    final otherEpisodes = widget.allEpisodes
        .where((e) {
          int eId = int.tryParse(e['id']?.toString() ?? '0') ?? 0;
          return eId != widget.currentEpisodeId;
        })
        .toList();

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
                    'حلقات أخرى',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اختر حلقة أخرى',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
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
                        String title = episode['title']?.toString() ?? 
                                      episode['show_episode_name']?.toString() ?? 
                                      'حلقة';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.movie, color: Colors.white),
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
  
  // ✅ إيقاف وتنظيف المشغل عند الخروج من الشاشة
  try {
    widget.chewieController.videoPlayerController.pause();
    widget.chewieController.videoPlayerController.dispose();
    widget.chewieController.dispose();
  } catch (e) {
    print('⚠️ خطأ في تنظيف المشغل عند الخروج: $e');
  }
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  super.dispose();
}
}