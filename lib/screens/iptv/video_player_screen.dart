import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../services/xtream_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  final Color color;
  final String? subtitle;
  final XtreamService xtreamService;
  final List<VodItem>? similarMovies;

  const VideoPlayerScreen({
    super.key,
    required this.title,
    required this.url,
    this.color = Colors.red,
    this.subtitle,
    required this.xtreamService,
    this.similarMovies,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  late ChewieController _chewieController;
  bool _isInitialized = false;
  bool _isFullScreen = false; // هذا للمقارنة مع القنوات
  bool _showControls = true;
  Timer? _controlsTimer;
  
  // ✅ قائمة جانبية للأفلام المشابهة
  List<VodItem> _quickMovies = [];
  bool _loadingMovies = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadQuickMovies();
    _startControlsTimer();
  }

  void _loadQuickMovies() async {
    if (widget.similarMovies != null) {
      setState(() {
        _quickMovies = widget.similarMovies!.take(20).toList();
      });
      return;
    }

    setState(() => _loadingMovies = true);
    try {
      final movies = await widget.xtreamService.getMovies();
      setState(() {
        _quickMovies = movies.take(20).toList();
        _loadingMovies = false;
      });
    } catch (e) {
      print('❌ خطأ في تحميل الأفلام السريعة: $e');
      setState(() => _loadingMovies = false);
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

  Future<void> _initializePlayer() async {
    try {
      WakelockPlus.enable();
      
      // ✅ تعيين الاتجاهات المسموح بها (مثل القنوات)
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
        ),
      );

      await _videoController.initialize();

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                Text(
                  'خطأ في تشغيل الفيديو',
                  style: TextStyle(color: Colors.red.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isInitialized = true;
      });

    } catch (e) {
      print('❌ خطأ في تهيئة مشغل الفيديو: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تشغيل الفيديو: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ هذه الدالة للتبديل بين الوضعين (مثل القنوات)
  void _toggleOrientation() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      
      if (_isFullScreen) {
        // ✅ وضع أفقي مع بقاء التحكمات (ليس Full Screen كامل)
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        // ✅ إخفاء الـ Status Bar لكن إبقاء التحكمات
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, 
          overlays: [SystemUiOverlay.bottom]);
      } else {
        // ✅ وضع عمودي
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        // ✅ إظهار الـ Status Bar
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

  void _playMovie(VodItem movie) async {
    try {
      final movieInfo = await widget.xtreamService.getMovieInfo(movie.streamId);
      String extension = 'mp4';
      
      if (movieInfo != null && 
          movieInfo['movie_data'] != null && 
          movieInfo['movie_data']['container_extension'] != null) {
        extension = movieInfo['movie_data']['container_extension'];
      }
      
      final url = widget.xtreamService.getMovieUrl(movie.streamId, extension);
      
      // إغلاق القائمة الجانبية
      Navigator.pop(context);
      
      // فتح الفيلم الجديد في نفس الشاشة
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            title: movie.name,
            url: url,
            color: widget.color,
            xtreamService: widget.xtreamService,
            similarMovies: _quickMovies,
          ),
        ),
      );
      
    } catch (e) {
      print('❌ خطأ في تشغيل الفيلم: $e');
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
      drawer: _buildQuickMoviesDrawer(),
      body: GestureDetector(
        onTap: () {
          // ✅ عند الضغط على الشاشة، نظهر التحكمات
          setState(() {
            _showControls = true;
          });
          // ✅ نلغي التايمر القديم ونبدأ تايمر جديد
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
            // مشغل الفيديو
            !_isInitialized
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('جاري تحميل المشغل...'),
                      ],
                    ),
                  )
                : Chewie(controller: _chewieController),
            
            // طبقة التحكمات
            if (_isInitialized) ...[
              // الخلفية الشفافة
              if (_showControls)
                Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              
              // الأزرار العلوية
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
        
        // ✅ عنوان الفيلم - يختفي مع التحكمات
        if (_showControls)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.title,
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
        
        // ✅ زر ملء الشاشة - ثابت دائماً (لا يختفي)
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
              
              // أزرار السطوع
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
              
              // زر الرجوع - يظهر فقط في الوضع العمودي
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

  // ✅ بناء القائمة الجانبية للأفلام
  Widget _buildQuickMoviesDrawer() {
    return Drawer(
      width: 300,
      child: Container(
        color: Colors.red.shade50,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade500],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'أفلام مقترحة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اختر فيلماً آخر',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loadingMovies
                  ? const Center(child: CircularProgressIndicator())
                  : _quickMovies.isEmpty
                      ? const Center(child: Text('لا توجد أفلام'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _quickMovies.length,
                          itemBuilder: (context, index) {
                            final movie = _quickMovies[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.shade100,
                                  backgroundImage: movie.streamIcon.isNotEmpty
                                      ? CachedNetworkImageProvider(movie.streamIcon)
                                      : null,
                                  child: movie.streamIcon.isEmpty
                                      ? const Icon(Icons.movie, color: Colors.red)
                                      : null,
                                ),
                                title: Text(
                                  movie.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  widget.xtreamService.getMovieCategoryName(movie.categoryId),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.play_arrow,
                                  color: Colors.red.shade300,
                                ),
                                onTap: () => _playMovie(movie),
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
    _videoController.dispose();
    _chewieController.dispose();
    WakelockPlus.disable();
    // ✅ إعادة تعيين الاتجاهات
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}