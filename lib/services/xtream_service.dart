// FILE: lib/services/xtream_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';

class XtreamService {
  final String baseUrl;
  final String username;
  final String password;
  final String port;
  final String? externalBaseUrl;
  final String? externalPort; // ✅ منفذ واحد خارجي (45677) - نحتفظ به
  
  bool _firstLoadDone = false;
  bool _isInitialized = false;
  bool _isInternalNetwork = false;

  // ✅ التخزين المؤقت (Caching)
  List<LiveStreamItem>? _cachedChannels;
  List<VodItem>? _cachedMovies;
  List<SeriesItem>? _cachedSeries;
  DateTime? _lastFetchTime;
  static const Duration _cacheValidity = Duration(minutes: 5);

  // ✅ التصنيفات
  Map<int, String> _channelCategories = {};
  Map<int, String> _movieCategories = {};
  Map<int, String> _seriesCategories = {};

  XtreamService({
    required this.baseUrl,
    required this.port,
    required this.username,
    required this.password,
    this.externalBaseUrl,
    this.externalPort,
  }) {
    _initialize();
  }

  void _initialize() async {
    _isInitialized = true;
    
    // ✅ التحقق من الشبكة (دائماً true)
    await _checkNetwork();
    
    print('✅ تم تهيئة XtreamService');
    print('📡 داخل الشبكة: $_isInternalNetwork');
    print('📡 السيرفر: $baseUrl:$port');
    print('👤 المستخدم: $username');
    
    if (!_isInternalNetwork && externalBaseUrl != null) {
      print('📡 رابط خارجي: $externalBaseUrl');
      if (externalPort != null) {
        print('📡 منفذ خارجي: $externalPort');
      }
    }
    
    // ✅ تحميل التصنيفات (بدون await)
    _loadAllCategories().catchError((e) {
      print('⚠️ فشل تحميل التصنيفات (غير مهم): $e');
    });
  }

  bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheValidity;
  }

  Future<void> _checkNetwork() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      
      print('📡 جهاز IP: $ip');
      
      // ✅ دائماً نعتبر داخل الشبكة
      _isInternalNetwork = true;
      print('✅ وضع التشغيل: داخل الشبكة دائماً');
      
    } catch (e) {
      print('⚠️ خطأ في كشف الشبكة: $e');
      _isInternalNetwork = true; // دائماً true
    }
  }

  Future<String?> getPublicIp() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.ipify.org'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (e) {
      print('⚠️ خطأ في جلب الـ IP العام: $e');
    }
    return null;
  }

  Future<void> _loadAllCategories() async {
    await Future.wait([
      _loadChannelCategories(),
      _loadMovieCategories(),
      _loadSeriesCategories(),
    ]);
  }

  String _getBaseUrl() {
    // ✅ دائماً استخدم baseUrl (iptv.pdata.ps) بغض النظر عن أي شيء
    return baseUrl;
  }

  String _getPort() {
    // ✅ دائماً استخدم port (80) بغض النظر عن أي شيء
    return port;
  }
// أضف هذه الدوال داخل كلاس XtreamService

  // ✅ دالة للتأكد من تحميل التصنيفات
  Future<void> ensureCategoriesLoaded() async {
    try {
      if (_channelCategories.isEmpty) {
        print('🔄 تحميل تصنيفات القنوات...');
        await _loadChannelCategories();
      }
      if (_movieCategories.isEmpty) {
        print('🔄 تحميل تصنيفات الأفلام...');
        await _loadMovieCategories();
      }
      if (_seriesCategories.isEmpty) {
        print('🔄 تحميل تصنيفات المسلسلات...');
        await _loadSeriesCategories();
      }
      print('✅ تم تحميل جميع التصنيفات');
      print('📊 القنوات: ${_channelCategories.length} تصنيف');
      print('📊 الأفلام: ${_movieCategories.length} تصنيف');
      print('📊 المسلسلات: ${_seriesCategories.length} تصنيف');
    } catch (e) {
      print('⚠️ خطأ في تحميل التصنيفات: $e');
    }
  }

  // ✅ دوال للوصول إلى التصنيفات مع التأكد من وجودها
  String getChannelCategoryName(int categoryId) {
    if (_channelCategories.isEmpty) {
      print('⚠️ تصنيفات القنوات فارغة، يتم تحميلها...');
      _loadChannelCategories(); // تحميل في الخلفية
    }
    return _channelCategories[categoryId] ?? 'تصنيف $categoryId';
  }
  
  String getMovieCategoryName(int categoryId) {
    if (_movieCategories.isEmpty) {
      print('⚠️ تصنيفات الأفلام فارغة، يتم تحميلها...');
      _loadMovieCategories(); // تحميل في الخلفية
    }
    return _movieCategories[categoryId] ?? 'تصنيف $categoryId';
  }
  
  String getSeriesCategoryName(int categoryId) {
    if (_seriesCategories.isEmpty) {
      print('⚠️ تصنيفات المسلسلات فارغة، يتم تحميلها...');
      _loadSeriesCategories(); // تحميل في الخلفية
    }
    return _seriesCategories[categoryId] ?? 'تصنيف $categoryId';
  }
  Future<void> _loadChannelCategories() async {
    try {
      final url = 'http://${_getBaseUrl()}:${_getPort()}/player_api.php?username=$username&password=$password&action=get_live_categories';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          for (var cat in data) {
            int id = int.tryParse(cat['category_id']?.toString() ?? '0') ?? 0;
            String name = cat['category_name']?.toString() ?? 'غير معروف';
            _channelCategories[id] = name;
          }
          print('✅ تم تحميل ${_channelCategories.length} تصنيف للقنوات');
        }
      }
    } catch (e) {
      print('⚠️ خطأ في تحميل تصنيفات القنوات: $e');
    }
  }

  Future<void> _loadMovieCategories() async {
    try {
      final url = 'http://${_getBaseUrl()}:${_getPort()}/player_api.php?username=$username&password=$password&action=get_vod_categories';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          for (var cat in data) {
            int id = int.tryParse(cat['category_id']?.toString() ?? '0') ?? 0;
            String name = cat['category_name']?.toString() ?? 'غير معروف';
            _movieCategories[id] = name;
          }
          print('✅ تم تحميل ${_movieCategories.length} تصنيف للأفلام');
        }
      }
    } catch (e) {
      print('⚠️ خطأ في تحميل تصنيفات الأفلام: $e');
    }
  }

  Future<void> _loadSeriesCategories() async {
    try {
      final url = 'http://${_getBaseUrl()}:${_getPort()}/player_api.php?username=$username&password=$password&action=get_series_categories';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          for (var cat in data) {
            int id = int.tryParse(cat['category_id']?.toString() ?? '0') ?? 0;
            String name = cat['category_name']?.toString() ?? 'غير معروف';
            _seriesCategories[id] = name;
          }
          print('✅ تم تحميل ${_seriesCategories.length} تصنيف للمسلسلات');
        }
      }
    } catch (e) {
      print('⚠️ خطأ في تحميل تصنيفات المسلسلات: $e');
    }
  }

  
  
 

  Future<List<LiveStreamItem>> getLiveChannels({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid() && _cachedChannels != null) {
      print('✅ استخدام الكاش للقنوات');
      return _cachedChannels!;
    }

    try {
      print('🔄 جلب القنوات المباشرة...');
      final url = 'http://${_getBaseUrl()}:${_getPort()}/player_api.php?username=$username&password=$password&action=get_live_streams';
      print('📡 URL: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ timeout في جلب القنوات');
          throw Exception('انتهت مهلة الاتصال');
        },
      );
      
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        if (data is List) {
          List<LiveStreamItem> channels = [];
          for (var item in data) {
            try {
              channels.add(LiveStreamItem(
                id: int.tryParse(item['num']?.toString() ?? '0') ?? 0,
                name: item['name']?.toString() ?? 'قناة',
                streamId: int.tryParse(item['stream_id']?.toString() ?? '0') ?? 0,
                streamIcon: item['stream_icon']?.toString() ?? '',
                categoryId: int.tryParse(item['category_id']?.toString() ?? '0') ?? 0,
              ));
            } catch (e) {
              print('⚠️ خطأ في تحليل عنصر: $e');
            }
          }
          
          _cachedChannels = channels;
          _lastFetchTime = DateTime.now();
          print('✅ تم جلب ${channels.length} قناة');
          return channels;
        }
      }
      return _cachedChannels ?? [];
    } catch (e) {
      print('❌ خطأ في جلب القنوات: $e');
      return _cachedChannels ?? [];
    }
  }

  Future<List<VodItem>> getMovies({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid() && _cachedMovies != null) {
      print('✅ استخدام الكاش للأفلام');
      return _cachedMovies!;
    }

    try {
      print('🔄 جلب الأفلام...');
      final url = 'http://${_getBaseUrl()}:${_getPort()}/player_api.php?username=$username&password=$password&action=get_vod_streams';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          print('⏱️ timeout في جلب الأفلام');
          throw Exception('انتهت مهلة الاتصال');
        },
      );
      
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is List) {
          print('✅ تم جلب ${data.length} فيلم من السيرفر');
          List<VodItem> movies = [];
          for (var item in data) {
            movies.add(VodItem(
              id: int.tryParse(item['num']?.toString() ?? '0') ?? 0,
              name: item['name']?.toString() ?? 'فيلم',
              streamId: int.tryParse(item['stream_id']?.toString() ?? '0') ?? 0,
              streamIcon: item['stream_icon']?.toString() ?? '',
              categoryId: int.tryParse(item['category_id']?.toString() ?? '0') ?? 0,
            ));
          }
          
          _cachedMovies = movies;
          _lastFetchTime = DateTime.now();
          return movies;
        }
      }
      return _cachedMovies ?? [];
    } catch (e) {
      print('❌ خطأ في جلب الأفلام: $e');
      return _cachedMovies ?? [];
    }
  }

  Future<List<SeriesItem>> getSeries({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid() && _cachedSeries != null) {
      print('✅ استخدام الكاش للمسلسلات');
      return _cachedSeries!;
    }

    try {
      print('🔄 جلب المسلسلات...');
      final url = 'http://${_getBaseUrl()}:${_getPort()}/player_api.php?username=$username&password=$password&action=get_series';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          print('⏱️ timeout في جلب المسلسلات');
          throw Exception('انتهت مهلة الاتصال');
        },
      );
      
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is List) {
          print('✅ تم جلب ${data.length} مسلسل من السيرفر');
          List<SeriesItem> series = [];
          for (var item in data) {
            series.add(SeriesItem(
              id: int.tryParse(item['num']?.toString() ?? '0') ?? 0,
              name: item['name']?.toString() ?? 'مسلسل',
              streamId: int.tryParse(item['series_id']?.toString() ?? '0') ?? 0,
              streamIcon: item['cover']?.toString() ?? '',
              categoryId: int.tryParse(item['category_id']?.toString() ?? '0') ?? 0,
            ));
          }
          
          _cachedSeries = series;
          _lastFetchTime = DateTime.now();
          return series;
        }
      }
      return _cachedSeries ?? [];
    } catch (e) {
      print('❌ خطأ في جلب المسلسلات: $e');
      return _cachedSeries ?? [];
    }
  }

  String getLiveStreamUrl(int streamId, {String extension = 'ts'}) {
    final url = 'http://$baseUrl:$port/live/$username/$password/$streamId.$extension';
    print('🎬 رابط التشغيل: $url');
    return url;
  }

  String getMovieUrl(int streamId, String extension) {
    final url = 'http://$baseUrl:$port/movie/$username/$password/$streamId.$extension';
    print('🎬 رابط الفيلم: $url');
    return url;
  }

  String getEpisodeUrl(int episodeId, String extension) {
    final url = 'http://$baseUrl:$port/series/$username/$password/$episodeId.$extension';
    print('🎬 رابط الحلقة: $url');
    return url;
  }

  Future<Map<String, dynamic>?> getMovieInfo(int vodId) async {
    try {
      final url = 'http://${_getBaseUrl()}:${_getPort()}/player_api.php?username=$username&password=$password&action=get_vod_info&vod_id=$vodId';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('⚠️ خطأ في جلب معلومات الفيلم: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getSeriesInfo(int seriesId) async {
    try {
      final url = 'http://${_getBaseUrl()}:${_getPort()}/player_api.php?username=$username&password=$password&action=get_series_info&series_id=$seriesId';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('⚠️ خطأ في جلب معلومات المسلسل: $e');
    }
    return null;
  }

  Future<void> clearCache() async {
    _cachedChannels = null;
    _cachedMovies = null;
    _cachedSeries = null;
    _lastFetchTime = null;
    _firstLoadDone = false;
    print('🗑️ تم مسح الكاش');
  }
}

class LiveStreamItem {
  final int id;
  final String name;
  final int streamId;
  final String streamIcon;
  final int categoryId;
  
  LiveStreamItem({
    required this.id,
    required this.name,
    required this.streamId,
    required this.streamIcon,
    required this.categoryId,
  });
}

class VodItem {
  final int id;
  final String name;
  final int streamId;
  final String streamIcon;
  final int categoryId;
  
  VodItem({
    required this.id,
    required this.name,
    required this.streamId,
    required this.streamIcon,
    required this.categoryId,
  });
}

class SeriesItem {
  final int id;
  final String name;
  final int streamId;
  final String streamIcon;
  final int categoryId;
  
  SeriesItem({
    required this.id,
    required this.name,
    required this.streamId,
    required this.streamIcon,
    required this.categoryId,
  });
}