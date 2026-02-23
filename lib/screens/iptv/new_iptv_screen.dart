import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/xtream_service.dart';
import 'movie_details_screen.dart';
import 'video_player_screen.dart';
import 'episodes_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'dart:async'; // ✅ أضف هذا السطر

class NewIptvScreen extends StatefulWidget {
  final XtreamService xtreamService;
  
  const NewIptvScreen({super.key, required this.xtreamService});

  @override
  State<NewIptvScreen> createState() => _NewIptvScreenState();
}

class _NewIptvScreenState extends State<NewIptvScreen> with SingleTickerProviderStateMixin {
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // المحتوى
  List<LiveStreamItem> _channels = [];
  List<VodItem> _movies = [];
  List<SeriesItem> _series = [];
  
  // التصنيفات
  Map<int, List<LiveStreamItem>> _channelsByCategory = {};
  Map<int, List<VodItem>> _moviesByCategory = {};
  Map<int, List<SeriesItem>> _seriesByCategory = {};
  
  List<int> _channelCategoryIds = [];
  List<int> _movieCategoryIds = [];
  List<int> _seriesCategoryIds = [];
  
  // التصنيف المختار
  int? _selectedCategoryId;
  int _selectedTabIndex = 0; // 0: قنوات, 1: أفلام, 2: مسلسلات
  
  bool _loading = true;
  String? _error;
  
  // للبحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  late TabController _tabController;
  
  // مشغل الفيديو للقنوات المباشرة
  Player? _player;
  VideoController? _videoController;


@override
void initState() {
  super.initState();
  _initializePlayer();
  _tabController = TabController(length: 3, vsync: this);
  _tabController.addListener(() {
    if (mounted) {
      setState(() {
        _selectedTabIndex = _tabController.index;
        _selectedCategoryId = null;
      });
    }
  });
  
  // ✅ تأكد من تحميل التصنيفات أولاً
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _ensureCategoriesLoaded();
    _loadAllContent();
  });
  
  _searchController.addListener(() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  });
}

Future<void> _ensureCategoriesLoaded() async {
  await widget.xtreamService.ensureCategoriesLoaded();
}
  void _initializePlayer() {
    try {
      _player = Player();
      _videoController = VideoController(_player!);
    } catch (e) {
      print('❌ خطأ في تهيئة المشغل: $e');
    }
  }

 Future<void> _loadAllContent() async {
  setState(() => _loading = true);
  
  try {
    final channels = await widget.xtreamService.getLiveChannels(forceRefresh: true);
    _channels = channels;
    _organizeChannels();
    
    final movies = await widget.xtreamService.getMovies(forceRefresh: true);
    _movies = movies;
    _organizeMovies();
    
    final series = await widget.xtreamService.getSeries(forceRefresh: true);
    _series = series;
    _organizeSeries();
    
    // ✅ ترتيب القنوات حسب الأحدث
    _channels.sort((a, b) => b.streamId.compareTo(a.streamId));
    
    // ✅ ترتيب الأفلام حسب الأحدث
    _movies.sort((a, b) => b.streamId.compareTo(a.streamId));
    
    // ✅ ترتيب المسلسلات حسب الأحدث
    _series.sort((a, b) => b.streamId.compareTo(a.streamId));
    
    setState(() => _loading = false);
    
  } catch (e) {
    setState(() {
      _error = 'فشل التحميل: $e';
      _loading = false;
    });
  }
}

  void _organizeChannels() {
    _channelsByCategory = {};
    for (var channel in _channels) {
      if (!_channelsByCategory.containsKey(channel.categoryId)) {
        _channelsByCategory[channel.categoryId] = [];
      }
      _channelsByCategory[channel.categoryId]!.add(channel);
    }
    _channelCategoryIds = _channelsByCategory.keys.toList()..sort();
  }

  void _organizeMovies() {
    _moviesByCategory = {};
    for (var movie in _movies) {
      if (!_moviesByCategory.containsKey(movie.categoryId)) {
        _moviesByCategory[movie.categoryId] = [];
      }
      _moviesByCategory[movie.categoryId]!.add(movie);
    }
    _movieCategoryIds = _moviesByCategory.keys.toList()..sort();
  }

  void _organizeSeries() {
    _seriesByCategory = {};
    for (var item in _series) {
      if (!_seriesByCategory.containsKey(item.categoryId)) {
        _seriesByCategory[item.categoryId] = [];
      }
      _seriesByCategory[item.categoryId]!.add(item);
    }
    _seriesCategoryIds = _seriesByCategory.keys.toList()..sort();
  }

  List<dynamic> _getCurrentContent() {
    if (_selectedTabIndex == 0) {
      if (_selectedCategoryId != null && _channelsByCategory.containsKey(_selectedCategoryId)) {
        return _channelsByCategory[_selectedCategoryId]!;
      }
      return _channels;
    } else if (_selectedTabIndex == 1) {
      if (_selectedCategoryId != null && _moviesByCategory.containsKey(_selectedCategoryId)) {
        return _moviesByCategory[_selectedCategoryId]!;
      }
      return _movies;
    } else {
      if (_selectedCategoryId != null && _seriesByCategory.containsKey(_selectedCategoryId)) {
        return _seriesByCategory[_selectedCategoryId]!;
      }
      return _series;
    }
  }
List<dynamic> _sortContentByDate(List<dynamic> content) {
  // نسخة جديدة من القائمة
  List<dynamic> sorted = List.from(content);
  
  // ترتيب تنازلي حسب المعرف (streamId) - كلما زاد الرقم كلما كان أحدث
  sorted.sort((a, b) {
    // استخدم streamId للمقارنة (الأرقام الأكبر هي الأحدث)
    int idA = 0;
    int idB = 0;
    
    if (a is LiveStreamItem) idA = a.streamId;
    else if (a is VodItem) idA = a.streamId;
    else if (a is SeriesItem) idA = a.streamId;
    
    if (b is LiveStreamItem) idB = b.streamId;
    else if (b is VodItem) idB = b.streamId;
    else if (b is SeriesItem) idB = b.streamId;
    
    return idB.compareTo(idA); // ترتيب تنازلي (الأكبر أولاً)
  });
  
  return sorted;
}
 String _getCategoryName(int categoryId) {
  try {
    if (_selectedTabIndex == 0) {
      // للقنوات
      final name = widget.xtreamService.getChannelCategoryName(categoryId);
      // إذا رجع نفس الرقم، معناته التصنيف غير موجود
      if (name == 'تصنيف $categoryId') {
        print('⚠️ تصنيف قناة غير موجود: $categoryId');
      }
      return name;
    } else if (_selectedTabIndex == 1) {
      // للأفلام
      final name = widget.xtreamService.getMovieCategoryName(categoryId);
      if (name == 'تصنيف $categoryId') {
        print('⚠️ تصنيف فيلم غير موجود: $categoryId');
      }
      return name;
    } else {
      // للمسلسلات
      final name = widget.xtreamService.getSeriesCategoryName(categoryId);
      if (name == 'تصنيف $categoryId') {
        print('⚠️ تصنيف مسلسل غير موجود: $categoryId');
      }
      return name;
    }
  } catch (e) {
    print('❌ خطأ في جلب اسم التصنيف: $e');
    return 'تصنيف $categoryId';
  }
}

  Widget _buildLoadingShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 16, color: Colors.grey),
                      const SizedBox(height: 4),
                      Container(height: 12, width: 100, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

void _playChannel(LiveStreamItem channel) {
  try {
    _player?.stop();
    final url = widget.xtreamService.getLiveStreamUrl(channel.streamId);
    print('🎬 تشغيل القناة: $url');
    
    _player?.open(Media(url));
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChannelPlayerScreen(
          channelName: channel.name,
          player: _player!,
          videoController: _videoController!,
          xtreamService: widget.xtreamService, // ✅ أضف هذا السطر
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
    
    // ✅ جلب أفلام مشابهة (اختياري)
    List<VodItem> similarMovies = [];
    try {
      similarMovies = _movies
          .where((m) => m.categoryId == movie.categoryId && m.streamId != movie.streamId)
          .take(10)
          .toList();
    } catch (e) {
      print('⚠️ خطأ في جلب أفلام مشابهة: $e');
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          title: movie.name,
          url: url,
          color: Colors.red,
          xtreamService: widget.xtreamService, // ✅ أضف هذا
          similarMovies: similarMovies, // ✅ أفلام مشابهة
        ),
      ),
    );
    
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
  

  // ✅ أضف هذه الدالة هنا
  void _showChannelInfo(LiveStreamItem channel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // صورة القناة
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: channel.streamIcon,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey.shade300,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.blue.shade50,
                    child: Icon(Icons.live_tv, size: 50, color: Colors.blue.shade700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // اسم القناة
            Center(
              child: Text(
                channel.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            
            // التصنيف
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.xtreamService.getChannelCategoryName(channel.categoryId),
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // أزرار
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _playChannel(channel);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('تشغيل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('إلغاء'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

 
 @override
Widget build(BuildContext context) {
  final currentContent = _getCurrentContent();
  
  // ترتيب المحتوى حسب الأحدث (إضافة تاريخ)
  final sortedContent = _sortContentByDate(currentContent);
  
  final filteredContent = _searchQuery.isEmpty 
      ? sortedContent 
      : sortedContent.where((item) => 
          item.name.toLowerCase().contains(_searchQuery)).toList();

  return Scaffold(
    key: _scaffoldKey, // ✅ أضف هذا السطر
    appBar: AppBar(
      title: const Text(
        'IPTV',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.deepPurple,
      elevation: 0,
      leading: IconButton( // ✅ زر لفتح القائمة الجانبية
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(icon: Icon(Icons.live_tv), text: 'قنوات'),
          Tab(icon: Icon(Icons.movie), text: 'أفلام'),
          Tab(icon: Icon(Icons.tv), text: 'مسلسلات'),
        ],
      ),
    ),
    drawer: Drawer( // ✅ القائمة الجانبية
      child: Container(
        color: Colors.deepPurple.shade50,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade500],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'التصنيفات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedTabIndex == 0 ? '${_channels.length} قناة' :
                    _selectedTabIndex == 1 ? '${_movies.length} فيلم' : '${_series.length} مسلسل',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
            child: ListView.builder(
  padding: const EdgeInsets.all(8),
  itemCount: (_selectedTabIndex == 0 ? _channelCategoryIds.length :
              _selectedTabIndex == 1 ? _movieCategoryIds.length :
              _seriesCategoryIds.length) + 1,
  itemBuilder: (context, index) {
    if (index == 0) {
      return Card(
        margin: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.all_inclusive, color: Colors.white),
          ),
          title: const Text(
            'الكل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          selected: _selectedCategoryId == null,
          selectedTileColor: Colors.deepPurple.shade100,
          onTap: () {
            setState(() {
              _selectedCategoryId = null;
            });
            Navigator.pop(context);
          },
        ),
      );
    }
    
    final categoryId = _selectedTabIndex == 0 ? _channelCategoryIds[index - 1] :
                      _selectedTabIndex == 1 ? _movieCategoryIds[index - 1] :
                      _seriesCategoryIds[index - 1];
    
    final count = _selectedTabIndex == 0 ? _channelsByCategory[categoryId]?.length ?? 0 :
                  _selectedTabIndex == 1 ? _moviesByCategory[categoryId]?.length ?? 0 :
                  _seriesByCategory[categoryId]?.length ?? 0;
    
    // الحصول على اسم التصنيف
    final categoryName = _getCategoryName(categoryId);
    
    return Card(
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _selectedCategoryId == categoryId 
              ? Colors.deepPurple 
              : Colors.deepPurple.shade100,
          child: Text(
            count.toString(),
            style: TextStyle(
              color: _selectedCategoryId == categoryId 
                  ? Colors.white 
                  : Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          categoryName,
          style: TextStyle(
            fontWeight: _selectedCategoryId == categoryId 
                ? FontWeight.bold 
                : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '$count عنصر',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        selected: _selectedCategoryId == categoryId,
        selectedTileColor: Colors.deepPurple.shade100,
        onTap: () {
          setState(() {
            _selectedCategoryId = categoryId;
          });
          Navigator.pop(context);
        },
      ),
    );
  },
),
            ),
          ],
        ),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '🔍 بحث...',
              prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
        ),
        
        Expanded(
          child: _loading
              ? _buildLoadingShimmer()
              : _error != null
                  ? Center(child: Text(_error!))
                  : filteredContent.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedTabIndex == 0 ? Icons.live_tv :
                                _selectedTabIndex == 1 ? Icons.movie :
                                Icons.tv,
                                size: 80,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد نتائج',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: filteredContent.length,
                          itemBuilder: (context, index) {
                            final item = filteredContent[index];
                            return _buildContentCard(item);
                          },
                        ),
        ),
      ],
    ),
  );
}

 Widget _buildContentCard(dynamic item) {
  final isLive = _selectedTabIndex == 0;
  final isMovie = _selectedTabIndex == 1;
  
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // الصورة - للتشغيل المباشر
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: () {
              if (isLive) {
                _playChannel(item);
              } else if (isMovie) {
                _playMovie(item);
              } else {
                // للمسلسلات، نفتح شاشة الحلقات
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EpisodesScreen(
                      xtreamService: widget.xtreamService,
                      series: item,
                    ),
                  ),
                );
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: item.streamIcon,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade300,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isLive ? Colors.blue.shade50 : 
                             isMovie ? Colors.red.shade50 : Colors.orange.shade50,
                      child: Icon(
                        isLive ? Icons.live_tv : (isMovie ? Icons.movie : Icons.tv),
                        size: 40,
                        color: isLive ? Colors.blue.shade700 : 
                               isMovie ? Colors.red.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ),
                // أيقونة التشغيل
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLive ? Icons.play_arrow : (isMovie ? Icons.play_arrow : Icons.list),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // العنوان والتفاصيل - لفتح شاشة التفاصيل
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: () {
              if (isLive) {
                // للقنوات، نفتح شاشة معلومات القناة
                _showChannelInfo(item);
              } else if (isMovie) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MovieDetailsScreen(
                      movie: item,
                      xtreamService: widget.xtreamService,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EpisodesScreen(
                      xtreamService: widget.xtreamService,
                      series: item,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 10,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          _getCategoryName(item.categoryId),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}

class _ChannelPlayerScreen extends StatefulWidget {
  final String channelName;
  final Player player;
  final VideoController videoController;
  final XtreamService xtreamService; // ✅ أضف هذا

  const _ChannelPlayerScreen({
    required this.channelName,
    required this.player,
    required this.videoController,
    required this.xtreamService, // ✅ أضف هذا
  });

  @override
  State<_ChannelPlayerScreen> createState() => _ChannelPlayerScreenState();
}

class _ChannelPlayerScreenState extends State<_ChannelPlayerScreen> {
  bool _isFullScreen = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  
  // ✅ قنوات سريعة للقائمة الجانبية
  List<LiveStreamItem> _quickChannels = [];
  bool _loadingChannels = false;
  
  // ✅ مفتاح للقائمة الجانبية
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // ✅ بدء إخفاء التحكمات بعد 3 ثواني
    _startControlsTimer();
    
    // ✅ تحميل القنوات للقائمة الجانبية
    _loadQuickChannels();
  }

  void _loadQuickChannels() async {
    setState(() => _loadingChannels = true);
    try {
      final channels = await widget.xtreamService.getLiveChannels();
      setState(() {
        _quickChannels = channels.take(30).toList(); // أول 30 قناة
        _loadingChannels = false;
      });
    } catch (e) {
      print('❌ خطأ في تحميل القنوات السريعة: $e');
      setState(() => _loadingChannels = false);
    }
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

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _startControlsTimer();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      
      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

  void _changeChannel(LiveStreamItem channel) {
    try {
      widget.player.stop();
      final url = widget.xtreamService.getLiveStreamUrl(channel.streamId);
      widget.player.open(Media(url));
      
      // إغلاق القائمة الجانبية
      Navigator.pop(context);
      
      // تحديث اسم القناة
      setState(() {});
      
      // إظهار رسالة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📺 ${channel.name}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('❌ خطأ في تغيير القناة: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _toggleFullScreen();
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildQuickChannelsDrawer(),
        body: GestureDetector(
          onTap: _showControlsTemporarily,
          child: Stack(
            children: [
              // مشغل الفيديو
              Video(controller: widget.videoController),
              
              // طبقة التحكمات
              if (_showControls) ...[
                // خلفية شفافة
                Container(
                  color: Colors.black.withOpacity(0.3),
                ),
                
                // الأزرار العلوية
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // زر القائمة الجانبية
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
                        
                        // اسم القناة
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.channelName,
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
                        
                        // زر ملء الشاشة
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
                            onPressed: _toggleFullScreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // أزرار السطوع (يمين)
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
                
                // زر الرجوع (يسار)
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
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ✅ بناء القائمة الجانبية للقنوات السريعة
  Widget _buildQuickChannelsDrawer() {
    return Drawer(
      width: 300,
      child: Container(
        color: Colors.deepPurple.shade50,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade500],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'القنوات السريعة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اختر قناة للتبديل السريع',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loadingChannels
                  ? const Center(child: CircularProgressIndicator())
                  : _quickChannels.isEmpty
                      ? const Center(child: Text('لا توجد قنوات'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _quickChannels.length,
                          itemBuilder: (context, index) {
                            final channel = _quickChannels[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.deepPurple.shade100,
                                  backgroundImage: channel.streamIcon.isNotEmpty
                                      ? CachedNetworkImageProvider(channel.streamIcon)
                                      : null,
                                  child: channel.streamIcon.isEmpty
                                      ? const Icon(Icons.live_tv, color: Colors.deepPurple)
                                      : null,
                                ),
                                title: Text(
                                  channel.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  widget.xtreamService.getChannelCategoryName(channel.categoryId),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.play_arrow,
                                  color: Colors.deepPurple.shade300,
                                ),
                                onTap: () => _changeChannel(channel),
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
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}
