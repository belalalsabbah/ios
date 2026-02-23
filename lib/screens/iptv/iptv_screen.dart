// FILE: lib/screens/iptv/iptv_screen.dart
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../services/xtream_service.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'episodes_screen.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:media_kit/src/models/playlist.dart'; // للتشغيل
class IptvScreen extends StatefulWidget {
  final XtreamService xtreamService;
  
  const IptvScreen({super.key, required this.xtreamService});

  @override
  State<IptvScreen> createState() => _IptvScreenState();
}

class _IptvScreenState extends State<IptvScreen> with SingleTickerProviderStateMixin {
  // قوائم المحتوى
  List<LiveStreamItem> _channels = [];
  List<VodItem> _movies = [];
  List<SeriesItem> _series = [];
  
  // تخزين المحتوى مصنف حسب التصنيف
  Map<int, List<LiveStreamItem>> _channelsByCategory = {};
  Map<int, List<VodItem>> _moviesByCategory = {};
  Map<int, List<SeriesItem>> _seriesByCategory = {};
  
  // قوائم التصنيفات
  List<int> _channelCategoryIds = [];
  List<int> _movieCategoryIds = [];
  List<int> _seriesCategoryIds = [];
  
  // حالة الطي لكل تصنيف
  Map<int, bool> _channelExpandedState = {};
  Map<int, bool> _movieExpandedState = {};
  Map<int, bool> _seriesExpandedState = {};
  
  bool _loading = true;
  String? _error;
  // 👇✅ هنا ضع المتغير الجديد - مع باقي المتغيرات
  bool _firstLoadDone = false;
  bool _isLoadingMoviesAndSeries = false;
  int _moviesRetryCount = 0;
int _seriesRetryCount = 0;
final int _maxRetryCount = 3; // ✅ استخدم final بدل const
  // للبحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // للتبويبات
  late TabController _tabController;
  
  // مشغل الفيديو للقنوات المباشرة
  Player? _player;
  VideoController? _videoController;
 // ✅ بعد دالة _loadMoviesAndSeries() أضف هذه الدالة
  Future<void> _checkAndReloadIfEmpty() async {
    if (_movies.isEmpty) {
      print('🔄 الأفلام فارغة، إعادة تحميل...');
      await _loadMoviesAndSeries();
    }
    if (_series.isEmpty) {
      print('🔄 المسلسلات فارغة، إعادة تحميل...');
      await _loadMoviesAndSeries();
    }
  }

 @override
void initState() {
  super.initState();
  _tabController = TabController(length: 3, vsync: this);
  _initializePlayer();
  
  // ✅ تحميل المحتوى بعد بناء الواجهة
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadAllContent();
  });
  
  // ✅ الاستماع لتغيير التبويب لتحديث الواجهة
  _tabController.addListener(() {
    if (_tabController.indexIsChanging) {
      // عند تغيير التبويب، تأكد من تحديث الواجهة
      if (mounted) setState(() {});
    }
  });
  
  _searchController.addListener(() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  });
}
  void _initializePlayer() {
    try {
      _player = Player();
      _videoController = VideoController(_player!);
    } catch (e) {
      print('❌ خطأ في تهيئة المشغل: $e');
    }
  }

  bool _matchesSearch(String text) {
    return _searchQuery.isEmpty || text.toLowerCase().contains(_searchQuery);
  }

Future<void> _loadAllContent() async {
  if (_firstLoadDone) {
    setState(() => _loading = false);
    return;
  }
  
  setState(() => _loading = true);
  
  try {
    await Future.delayed(const Duration(milliseconds: 300));
    
    print('🔄 جاري تحميل القنوات...');
    final channels = await widget.xtreamService.getLiveChannels(forceRefresh: true);
    
    if (!mounted) return;
    
    setState(() {
      _channels = channels;
    });
    _organizeChannels();
    
    print('✅ تم تحميل ${channels.length} قناة');
    setState(() => _loading = false);
    _firstLoadDone = true;
    
    // ✅ تأخير بسيط قبل تحميل الأفلام والمسلسلات
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _loadMoviesAndSeries();
      }
    });
    
  } catch (e) {
    print('❌ خطأ في تحميل القنوات: $e');
    if (mounted) {
      setState(() {
        _error = 'فشل تحميل القنوات: $e';
        _loading = false;
      });
    }
  }
}

 Future<void> _loadMoviesAndSeries() async {
  // ✅ تحميل الأفلام
  try {
    print('🔄 جاري تحميل الأفلام...');
    final movies = await widget.xtreamService.getMovies(forceRefresh: true);
    
    if (mounted) {
      if (movies.isEmpty && _moviesRetryCount < _maxRetryCount) {
        _moviesRetryCount++;
        print('⚠️ السيرفر رجع 0 فيلم - محاولة $_moviesRetryCount من $_maxRetryCount');
        // ✅ حاول مرة أخرى بعد ثانيتين
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadMoviesAndSeries();
        });
      } else {
        setState(() {
          _movies = movies;
        });
        _organizeMovies();
        print('✅ تم تحميل ${movies.length} فيلم');
        _moviesRetryCount = 0; // إعادة تعيين العداد
      }
    }
  } catch (e) {
    print('⚠️ خطأ في تحميل الأفلام: $e');
    if (_moviesRetryCount < _maxRetryCount) {
      _moviesRetryCount++;
      print('⚠️ إعادة المحاولة $_moviesRetryCount من $_maxRetryCount بعد خطأ');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _loadMoviesAndSeries();
      });
    } else {
      print('❌ فشل تحميل الأفلام بعد $_maxRetryCount محاولات');
      _moviesRetryCount = 0;
    }
  }
  
  // ✅ تحميل المسلسلات
  try {
    print('🔄 جاري تحميل المسلسلات...');
    final series = await widget.xtreamService.getSeries(forceRefresh: true);
    
    if (mounted) {
      if (series.isEmpty && _seriesRetryCount < _maxRetryCount) {
        _seriesRetryCount++;
        print('⚠️ السيرفر رجع 0 مسلسل - محاولة $_seriesRetryCount من $_maxRetryCount');
        // ✅ حاول مرة أخرى بعد ثانيتين
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadMoviesAndSeries();
        });
      } else {
        setState(() {
          _series = series;
        });
        _organizeSeries();
        print('✅ تم تحميل ${series.length} مسلسل');
        _seriesRetryCount = 0; // إعادة تعيين العداد
      }
    }
  } catch (e) {
    print('⚠️ خطأ في تحميل المسلسلات: $e');
    if (_seriesRetryCount < _maxRetryCount) {
      _seriesRetryCount++;
      print('⚠️ إعادة المحاولة $_seriesRetryCount من $_maxRetryCount بعد خطأ');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _loadMoviesAndSeries();
      });
    } else {
      print('❌ فشل تحميل المسلسلات بعد $_maxRetryCount محاولات');
      _seriesRetryCount = 0;
    }
  }
}


  // ✅ دوال التنظيم المنفصلة
  void _organizeChannels() {
    _channelsByCategory = {};
    for (var channel in _channels) {
      if (!_channelsByCategory.containsKey(channel.categoryId)) {
        _channelsByCategory[channel.categoryId] = [];
      }
      _channelsByCategory[channel.categoryId]!.add(channel);
    }
    _channelCategoryIds = _channelsByCategory.keys.toList()..sort();
    
    _channelExpandedState = {};
    for (var id in _channelCategoryIds) {
      _channelExpandedState[id] = true;
    }
  }

void _organizeMovies() {
  if (_movies.isEmpty) return;
  
  _moviesByCategory = {};
  for (var movie in _movies) {
    if (!_moviesByCategory.containsKey(movie.categoryId)) {
      _moviesByCategory[movie.categoryId] = [];
    }
    _moviesByCategory[movie.categoryId]!.add(movie);
  }
  _movieCategoryIds = _moviesByCategory.keys.toList()..sort();
  
  _movieExpandedState = {};
  for (var id in _movieCategoryIds) {
    _movieExpandedState[id] = true;
  }
  
  // تحديث الواجهة بعد التنظيم
  if (mounted) setState(() {});
}

void _organizeSeries() {
  if (_series.isEmpty) return;
  
  _seriesByCategory = {};
  for (var item in _series) {
    if (!_seriesByCategory.containsKey(item.categoryId)) {
      _seriesByCategory[item.categoryId] = [];
    }
    _seriesByCategory[item.categoryId]!.add(item);
  }
  _seriesCategoryIds = _seriesByCategory.keys.toList()..sort();
  
  _seriesExpandedState = {};
  for (var id in _seriesCategoryIds) {
    _seriesExpandedState[id] = true;
  }
  
  // تحديث الواجهة بعد التنظيم
  if (mounted) setState(() {});
}

void _playChannel(LiveStreamItem channel) {
  try {
    _player?.stop();
    
    // ✅ الحصول على الرابط
    final url = widget.xtreamService.getLiveStreamUrl(channel.streamId);
    
    // ✅ تسجيل تفاصيل أكثر (بدون استخدام _isInternalNetwork)
    print('=' * 60);
    print('🎬 محاولة تشغيل القناة: ${channel.name} (ID: ${channel.streamId})');
    print('📺 رابط التشغيل: $url');
    print('=' * 60);
    
    // ✅ محاولة فتح الرابط
    _player?.open(Media(url));
    
    // ✅ مراقبة حالة التشغيل (بدون playback)
    _player?.stream.error.listen((error) {
      print('❌ خطأ في التشغيل: $error');
    });
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChannelPlayerScreen(
          channelName: channel.name,
          player: _player!,
          videoController: _videoController!,
        ),
      ),
    ).then((_) => _player?.stop());
    
  } catch (e) {
    print('❌ خطأ في تشغيل القناة: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطأ في التشغيل: $e')),
    );
  }
}

  // ✅ دالة تشغيل الأفلام باستخدام video_player مع chewie
void _playMovie(VodItem movie) async {
  try {
    print('=' * 60);
    print('🎬 محاولة تشغيل الفيلم: ${movie.name} (ID: ${movie.streamId})');
    
    final movieInfo = await widget.xtreamService.getMovieInfo(movie.streamId);
    String extension = 'mp4';
    
    if (movieInfo != null && 
        movieInfo['movie_data'] != null && 
        movieInfo['movie_data']['container_extension'] != null) {
      extension = movieInfo['movie_data']['container_extension'];
      print('📦 الامتداد المستخرج: $extension');
    }
    
    final url = widget.xtreamService.getMovieUrl(movie.streamId, extension);
    print('📺 رابط الفيلم: $url');
    print('=' * 60);
    
    // ✅ تشغيل الفيلم باستخدام video_player
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
          child: CircularProgressIndicator(color: Colors.red),
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
        builder: (context) => _VideoPlayerScreen(
          title: movie.name,
          chewieController: chewieController,
          color: Colors.red,
        ),
      ),
    ).then((_) {
      controller.dispose();
      chewieController.dispose();
    });
    
  } catch (e) {
    print('❌ خطأ في تشغيل الفيلم: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تشغيل الفيلم: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  // دالة لتبديل حالة الطي للتصنيف
  void _toggleChannelCategory(int categoryId) {
    setState(() {
      _channelExpandedState[categoryId] = !(_channelExpandedState[categoryId] ?? true);
    });
  }

  void _toggleMovieCategory(int categoryId) {
    setState(() {
      _movieExpandedState[categoryId] = !(_movieExpandedState[categoryId] ?? true);
    });
  }

  void _toggleSeriesCategory(int categoryId) {
    setState(() {
      _seriesExpandedState[categoryId] = !(_seriesExpandedState[categoryId] ?? true);
    });
  }

  @override
 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text(
        'IPTV',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
      ),
      backgroundColor: Colors.deepPurple,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _loadAllContent(),
          tooltip: 'تحديث',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(icon: Icon(Icons.live_tv), text: 'قنوات'),
          Tab(icon: Icon(Icons.movie), text: 'أفلام'),
          Tab(icon: Icon(Icons.tv), text: 'مسلسلات'),
        ],
      ),
    ),
    body: Column(
      children: [
        // شريط البحث
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'بحث...',
              prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
        ),
        
        // المحتوى حسب التبويب مع سحب للتحديث
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRefreshableList(_buildChannelList(), 0),
                        _buildRefreshableList(_buildMovieList(), 1),
                        _buildRefreshableList(_buildSeriesList(), 2),
                      ],
                    ),
        ),
      ],
    ),
  );
}

// ✅ دالة مساعدة لإنشاء قائمة قابلة للسحب للتحديث
Widget _buildRefreshableList(Widget listWidget, int tabIndex) {
  return RefreshIndicator(
    onRefresh: () async {
      // مسح الكاش أولاً
      await widget.xtreamService.clearCache();
      
      // إعادة تحميل المحتوى حسب التبويب الحالي
      if (tabIndex == 0) {
        // تحديث القنوات
        final channels = await widget.xtreamService.getLiveChannels(forceRefresh: true);
        if (mounted) {
          setState(() {
            _channels = channels;
          });
          _organizeChannels();
        }
      } else if (tabIndex == 1) {
        // تحديث الأفلام
        final movies = await widget.xtreamService.getMovies(forceRefresh: true);
        if (mounted) {
          setState(() {
            _movies = movies;
          });
          _organizeMovies();
        }
      } else if (tabIndex == 2) {
        // تحديث المسلسلات
        final series = await widget.xtreamService.getSeries(forceRefresh: true);
        if (mounted) {
          setState(() {
            _series = series;
          });
          _organizeSeries();
        }
      }
    },
    child: listWidget,
  );
}

  // بناء قائمة القنوات مع خاصية الطي
  Widget _buildChannelList() {
    if (_channels.isEmpty) {
      return _buildEmptyState(Icons.live_tv, 'لا توجد قنوات');
    }

    List<int> categoriesToShow = _channelCategoryIds.where((catId) {
      return _channelsByCategory[catId]!.any((item) => _matchesSearch(item.name));
    }).toList();

    if (categoriesToShow.isEmpty) {
      return _buildEmptyState(Icons.search_off, 'لا توجد نتائج للبحث');
    }

    return ListView.builder(
      cacheExtent: 500,
      itemCount: categoriesToShow.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        int categoryId = categoriesToShow[index];
        List<LiveStreamItem> categoryChannels = _channelsByCategory[categoryId]!
            .where((item) => _matchesSearch(item.name))
            .toList();
        
        bool isExpanded = _channelExpandedState[categoryId] ?? true;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              // عنوان التصنيف القابل للنقر
              InkWell(
                onTap: () => _toggleChannelCategory(categoryId),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.xtreamService.getChannelCategoryName(categoryId),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${categoryChannels.length} قناة',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // المحتوى (يظهر فقط إذا كان التصنيف مفتوحاً)
              if (isExpanded)
                ...categoryChannels.map((channel) => Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 45,
                          height: 45,
                          color: Colors.blue.shade50,
                          child: channel.streamIcon.isNotEmpty
                              ? Image.network(
                                  channel.streamIcon,
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => 
                                      Icon(Icons.live_tv, color: Colors.blue.shade700, size: 25),
                                )
                              : Icon(Icons.live_tv, color: Colors.blue.shade700, size: 25),
                        ),
                      ),
                      title: Text(
                        channel.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      trailing: Container(
                        decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                        child: const Icon(Icons.play_circle_fill, color: Colors.green, size: 35),
                      ),
                      onTap: () => _playChannel(channel),
                    ),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }

  // بناء قائمة الأفلام مع خاصية الطي
  Widget _buildMovieList() {
    if (_movies.isEmpty) {
      return _buildEmptyState(Icons.movie, 'لا توجد أفلام');
    }

    List<int> categoriesToShow = _movieCategoryIds.where((catId) {
      return _moviesByCategory[catId]!.any((item) => _matchesSearch(item.name));
    }).toList();

    if (categoriesToShow.isEmpty) {
      return _buildEmptyState(Icons.search_off, 'لا توجد نتائج للبحث');
    }

    return ListView.builder(
      cacheExtent: 500,
      itemCount: categoriesToShow.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        int categoryId = categoriesToShow[index];
        List<VodItem> categoryMovies = _moviesByCategory[categoryId]!
            .where((item) => _matchesSearch(item.name))
            .toList();
        
        bool isExpanded = _movieExpandedState[categoryId] ?? true;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              InkWell(
                onTap: () => _toggleMovieCategory(categoryId),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.xtreamService.getMovieCategoryName(categoryId),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${categoryMovies.length} فيلم',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (isExpanded)
                ...categoryMovies.map((movie) => Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 45,
                          height: 45,
                          color: Colors.red.shade50,
                          child: movie.streamIcon.isNotEmpty
                              ? Image.network(
                                  movie.streamIcon,
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => 
                                      Icon(Icons.movie, color: Colors.red.shade700, size: 25),
                                )
                              : Icon(Icons.movie, color: Colors.red.shade700, size: 25),
                        ),
                      ),
                      title: Text(
                        movie.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      trailing: Container(
                        decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                        child: const Icon(Icons.play_circle_fill, color: Colors.red, size: 35),
                      ),
                      onTap: () => _playMovie(movie),
                    ),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }

  // بناء قائمة المسلسلات مع خاصية الطي
  Widget _buildSeriesList() {
    if (_series.isEmpty) {
      return _buildEmptyState(Icons.tv, 'لا توجد مسلسلات');
    }

    List<int> categoriesToShow = _seriesCategoryIds.where((catId) {
      return _seriesByCategory[catId]!.any((item) => _matchesSearch(item.name));
    }).toList();

    if (categoriesToShow.isEmpty) {
      return _buildEmptyState(Icons.search_off, 'لا توجد نتائج للبحث');
    }

    return ListView.builder(
      cacheExtent: 500,
      itemCount: categoriesToShow.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        int categoryId = categoriesToShow[index];
        List<SeriesItem> categorySeries = _seriesByCategory[categoryId]!
            .where((item) => _matchesSearch(item.name))
            .toList();
        
        bool isExpanded = _seriesExpandedState[categoryId] ?? true;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              InkWell(
                onTap: () => _toggleSeriesCategory(categoryId),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.xtreamService.getSeriesCategoryName(categoryId),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${categorySeries.length} مسلسل',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (isExpanded)
                ...categorySeries.map((series) => Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 45,
                          height: 45,
                          color: Colors.orange.shade50,
                          child: series.streamIcon.isNotEmpty
                              ? Image.network(
                                  series.streamIcon,
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => 
                                      Icon(Icons.tv, color: Colors.orange.shade700, size: 25),
                                )
                              : Icon(Icons.tv, color: Colors.orange.shade700, size: 25),
                        ),
                      ),
                      title: Text(
                        series.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      trailing: Container(
                        decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                        child: const Icon(Icons.play_circle_fill, color: Colors.orange, size: 35),
                      ),
                      onTap: () {
                        // ✅ فتح شاشة الحلقات
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EpisodesScreen(
                              xtreamService: widget.xtreamService,
                              series: series,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _player?.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

// ✅ شاشة منفصلة لتشغيل القناة مع خيارات التحكم
class _ChannelPlayerScreen extends StatefulWidget {
  final String channelName;
  final Player player;
  final VideoController videoController;

  const _ChannelPlayerScreen({
    required this.channelName,
    required this.player,
    required this.videoController,
  });

  @override
  State<_ChannelPlayerScreen> createState() => _ChannelPlayerScreenState();
}

class _ChannelPlayerScreenState extends State<_ChannelPlayerScreen> {
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    // تفعيل Wakelock عند تشغيل الفيديو
    WakelockPlus.enable();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      
      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  void _adjustBrightness(bool increase) async {
    try {
      double brightness = await ScreenBrightness.instance.current;
      if (increase && brightness < 1.0) {
        await ScreenBrightness.instance.setScreenBrightness(brightness + 0.2);
      } else if (!increase && brightness > 0.0) {
        await ScreenBrightness.instance.setScreenBrightness(brightness - 0.2);
      }
    } catch (e) {
      print('خطأ في تعديل السطوع: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen ? null : AppBar(
        title: Text(
          widget.channelName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: _toggleFullScreen,
          ),
          IconButton(
            icon: const Icon(Icons.brightness_7),
            onPressed: () => _adjustBrightness(true),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_4),
            onPressed: () => _adjustBrightness(false),
          ),
        ],
      ),
      body: Stack(
        children: [
          Video(controller: widget.videoController),
          if (!_isFullScreen)
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // إلغاء Wakelock عند الخروج
    WakelockPlus.disable();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
}

// ✅ شاشة منفصلة للأفلام
// ✅ شاشة منفصلة للأفلام (يجب أن تكون موجودة)
class _VideoPlayerScreen extends StatefulWidget {
  final String title;
  final ChewieController chewieController;
  final Color color;

  const _VideoPlayerScreen({
    required this.title,
    required this.chewieController,
    this.color = Colors.red,
  });

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      
      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  void _adjustBrightness(bool increase) async {
    try {
      double brightness = await ScreenBrightness.instance.current;
      if (increase && brightness < 1.0) {
        await ScreenBrightness.instance.setScreenBrightness(brightness + 0.2);
      } else if (!increase && brightness > 0.0) {
        await ScreenBrightness.instance.setScreenBrightness(brightness - 0.2);
      }
    } catch (e) {
      print('خطأ في تعديل السطوع: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen ? null : AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: widget.color,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: _toggleFullScreen,
          ),
          IconButton(
            icon: const Icon(Icons.brightness_7),
            onPressed: () => _adjustBrightness(true),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_4),
            onPressed: () => _adjustBrightness(false),
          ),
        ],
      ),
      body: Center(
        child: Chewie(controller: widget.chewieController),
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
}