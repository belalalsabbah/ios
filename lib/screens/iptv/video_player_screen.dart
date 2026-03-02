import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../services/xtream_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isFullScreen = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  
  List<VodItem> _quickMovies = [];
  bool _loadingMovies = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<String> _savedMovies = [];
  DateTime _lastTapTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadQuickMovies();
    _loadSavedMovies();
    _startControlsTimer();
  }

  Future<void> _loadSavedMovies() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedMovies = prefs.getStringList('saved_movies') ?? [];
    });
  }

  Future<void> _toggleSave(VodItem movie) async {
    final prefs = await SharedPreferences.getInstance();
    final String id = movie.streamId.toString();
    List<String> currentList = List.from(_savedMovies);

    if (currentList.contains(id)) {
      currentList.remove(id);
    } else {
      currentList.add(id);
    }

    await prefs.setStringList('saved_movies', currentList);
    setState(() {
      _savedMovies = currentList;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentList.contains(id) ? '✅ تمت الإضافة إلى المفضلة' : '🗑️ تمت الإزالة من المفضلة'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  bool _isSaved(VodItem movie) => _savedMovies.contains(movie.streamId.toString());

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

  Future<void> _initializePlayer() async {
    try {
      WakelockPlus.enable();
      
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
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
          child: const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                Text('خطأ في تشغيل الفيديو', style: TextStyle(color: Colors.red.shade700)),
                const SizedBox(height: 8),
                Text(errorMessage, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          );
        },
      );

      setState(() => _isInitialized = true);

    } catch (e) {
      print('❌ خطأ في تهيئة مشغل الفيديو: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تشغيل الفيديو: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  void _playMovie(VodItem movie) async {
    try {
      final movieInfo = await widget.xtreamService.getMovieInfo(movie.streamId);
      String extension = 'mp4';
      if (movieInfo != null && movieInfo['movie_data'] != null && movieInfo['movie_data']['container_extension'] != null) {
        extension = movieInfo['movie_data']['container_extension'];
      }
      final url = await widget.xtreamService.getMovieUrl(movie.streamId, extension);
      Navigator.pop(context);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

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
        drawer: _buildQuickMoviesDrawer(backgroundColor, textColor),
        body: Stack(
          children: [
            // مشغل الفيديو
            if (!_isInitialized)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('جاري تحميل المشغل...'),
                  ],
                ),
              )
            else
              Chewie(controller: _chewieController),

            // طبقة شفافة لالتقاط اللمسات
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
                    _startControlsTimer();
                  }
                },
              ),
            ),

            // طبقة التحكمات
            if (_isInitialized && _showControls) ...[
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
                            widget.title,
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

  Widget _buildQuickMoviesDrawer(Color bgColor, Color textColor) {
    return Drawer(
      width: 300,
      child: Container(
        color: Colors.red.shade50,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.red.shade700, Colors.red.shade500]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('أفلام مقترحة', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('اختر فيلماً آخر', style: TextStyle(color: Colors.white.withOpacity(0.8))),
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
                            final saved = _isSaved(movie);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: movie.streamIcon.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: movie.streamIcon,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            color: Colors.red.shade100,
                                            child: const Icon(Icons.movie, color: Colors.red),
                                          ),
                                        )
                                      : Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.red.shade100,
                                          child: const Icon(Icons.movie, color: Colors.red),
                                        ),
                                ),
                                title: Text(
                                  movie.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  widget.xtreamService.getMovieCategoryName(movie.categoryId),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        saved ? Icons.bookmark : Icons.bookmark_border,
                                        color: saved ? Colors.red : Colors.grey,
                                      ),
                                      onPressed: () => _toggleSave(movie),
                                      iconSize: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.play_arrow, color: Colors.red.shade300),
                                  ],
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