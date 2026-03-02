// FILE: lib/services/xtream_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:math' show min;

class XtreamService {
  final String baseUrl;
  final String username;
  final String password;
  final String port;
  final String? externalBaseUrl;
  final String? externalPort;

  bool _firstLoadDone = false;
  bool _isInitialized = false;
  bool _isInternalNetwork = false;

  List<LiveStreamItem>? _cachedChannels;
  List<VodItem>? _cachedMovies;
  List<SeriesItem>? _cachedSeries;
  DateTime? _lastFetchTime;
  static const Duration _cacheValidity = Duration(minutes: 5);

  Map<int, String> _channelCategories = {};
  Map<int, String> _movieCategories = {};
  Map<int, String> _seriesCategories = {};

  final String _proxyUrl = 'http://50.50.50.1/api/iptv_proxy.php';

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
    await _checkNetwork();
    print('✅ تم تهيئة XtreamService');
    print('📡 داخل الشبكة: $_isInternalNetwork');
    print('📡 السيرفر: $baseUrl:$port');
    print('👤 المستخدم: $username');
    print('📡 البروكسي: $_proxyUrl');
    if (!_isInternalNetwork && externalBaseUrl != null) {
      print('📡 رابط خارجي: $externalBaseUrl');
      if (externalPort != null) print('📡 منفذ خارجي: $externalPort');
    }
    _loadAllCategories().catchError((e) => print('⚠️ فشل تحميل التصنيفات: $e'));
  }

  bool _isCacheValid() => _lastFetchTime != null && DateTime.now().difference(_lastFetchTime!) < _cacheValidity;

  Future<void> _checkNetwork() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      print('📡 جهاز IP: $ip');
      _isInternalNetwork = true;
      print('✅ وضع التشغيل: داخل الشبكة دائماً');
    } catch (e) {
      print('⚠️ خطأ في كشف الشبكة: $e');
      _isInternalNetwork = true;
    }
  }

  Future<String?> getPublicIp() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return response.body.trim();
    } catch (e) {
      print('⚠️ خطأ في جلب الـ IP العام: $e');
    }
    return null;
  }

  Future<void> _loadAllCategories() async {
    await Future.wait([_loadChannelCategories(), _loadMovieCategories(), _loadSeriesCategories()]);
  }

  Future<void> ensureCategoriesLoaded() async {
    try {
      if (_channelCategories.isEmpty) await _loadChannelCategories();
      if (_movieCategories.isEmpty) await _loadMovieCategories();
      if (_seriesCategories.isEmpty) await _loadSeriesCategories();
      print('✅ تم تحميل جميع التصنيفات');
      print('📊 القنوات: ${_channelCategories.length} تصنيف');
      print('📊 الأفلام: ${_movieCategories.length} تصنيف');
      print('📊 المسلسلات: ${_seriesCategories.length} تصنيف');
    } catch (e) {
      print('⚠️ خطأ في تحميل التصنيفات: $e');
    }
  }

  String getChannelCategoryName(int categoryId) {
    if (_channelCategories.isEmpty) _loadChannelCategories();
    return _channelCategories[categoryId] ?? 'تصنيف $categoryId';
  }

  String getMovieCategoryName(int categoryId) {
    if (_movieCategories.isEmpty) _loadMovieCategories();
    return _movieCategories[categoryId] ?? 'تصنيف $categoryId';
  }

  String getSeriesCategoryName(int categoryId) {
    if (_seriesCategories.isEmpty) _loadSeriesCategories();
    return _seriesCategories[categoryId] ?? 'تصنيف $categoryId';
  }

  // ================= دوال مساعدة للطلبات عبر البروكسي =================

  void _logResponseDetails(http.Response response, {String tag = ''}) {
    print('📌 --- تشخيص الاستجابة $tag ---');
    print('📌 Status code: ${response.statusCode}');
    print('📌 Headers: ${response.headers}');
    print('📌 Body length: ${response.body.length}');
    if (response.body.isNotEmpty) {
      print('📌 Body preview: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
    } else {
      print('📌 Body: فارغ');
    }
    print('📌 --- نهاية التشخيص ---');
  }

  Future<dynamic> _proxyGet(String action, {Map<String, dynamic>? params}) async {
    try {
      // تحويل جميع القيم إلى String لتجنب مشاكل النوع
      final safeParams = <String, String>{};
      if (params != null) {
        params.forEach((key, value) {
          safeParams[key] = value.toString(); // تحويل أي قيمة إلى String
        });
      }

      final uri = Uri.parse(_proxyUrl).replace(queryParameters: {
        'action': action,
        'username': username,
        'password': password,
        ...safeParams,
      });
      print('🌐 Calling proxy: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      print('📥 Proxy response status: ${response.statusCode}');

      _logResponseDetails(response, tag: action);

      if (response.statusCode != 200) {
        print('⚠️ Proxy returned error: ${response.statusCode}');
        return null;
      }

      if (response.body.isEmpty) {
        print('⚠️ Proxy returned empty response');
        return null;
      }

      final decoded = json.decode(response.body);
      print('📊 Decoded type: ${decoded.runtimeType}');

      if (decoded is int) {
        print('⚠️ Proxy returned int: $decoded');
        return null;
      }
      if (decoded is String) {
        print('⚠️ Proxy returned string: $decoded');
        return null;
      }
      if (decoded is Map) {
        print('📡 **البروكسي استجاب بنجاح (كـ Map)**');
        print('🔑 Map keys: ${decoded.keys}');
        return decoded;
      }
      if (decoded is List) {
        print('📡 **البروكسي استجاب بنجاح (كـ List)**');
        print('📏 List length: ${decoded.length}');
        return decoded;
      }

      print('⚠️ Proxy returned unexpected type: ${decoded.runtimeType}');
      return null;

    } catch (e, stack) {
      print('❌ Exception in _proxyGet: $e');
      print('Stack: $stack');
      return null;
    }
  }

  Future<List<dynamic>> _proxyGetList(String action, {Map<String, dynamic>? params}) async {
    try {
      final result = await _proxyGet(action, params: params);
      if (result == null) return [];
      if (result is List) return result;
      if (result is Map) {
        if (result['data'] is List) return result['data'];
        if (result['items'] is List) return result['items'];
      }
      return [];
    } catch (e) {
      print('❌ _proxyGetList error: $e');
      return [];
    }
  }

  // ================= دوال روابط البث عبر البروكسي فقط =================

  Future<String> getLiveStreamUrl(int streamId, {String extension = 'ts'}) async =>
      await _getStreamUrlViaProxy(streamId, 'live', extension);

  Future<String> getMovieUrl(int streamId, String extension) async =>
      await _getStreamUrlViaProxy(streamId, 'movie', extension);

  Future<String> getEpisodeUrl(int episodeId, String extension) async =>
      await _getStreamUrlViaProxy(episodeId, 'series', extension);

  Future<String> _getStreamUrlViaProxy(int streamId, String type, String extension) async {
    try {
      print('🔄 جلب رابط $type عبر البروكسي: $streamId');
      final url = Uri.parse(_proxyUrl).replace(queryParameters: {
        'action': 'get_stream_url',
        'username': username,
        'password': password,
        'stream_id': streamId.toString(),
        'type': type,
        'extension': extension,
      });
      print('🌐 URL كامل: $url');
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      _logResponseDetails(response, tag: 'get_stream_url');
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('url')) {
            print('✅ الرابط موجود: ${data['url']}');
            return data['url'];
          }
        } catch (e) {
          print('⚠️ فشل تحليل JSON: $e');
        }
      }
      print('❌ فشل الحصول على الرابط عبر البروكسي');
      return '';
    } catch (e) {
      print('❌ خطأ في البروكسي: $e');
      return '';
    }
  }

  // ================= دوال معلومات إضافية (فقط عبر البروكسي) =================

  Future<Map<String, dynamic>?> getMovieInfo(int vodId) async {
    try {
      print('🔄 محاولة جلب معلومات الفيلم: $vodId');
      final result = await _proxyGet('get_vod_info', params: {'vod_id': vodId});

      if (result == null) {
        print('❌ result is null');
        return null;
      }

      // تحويل النتيجة إلى Map بشكل آمن
      Map<String, dynamic> data;
      if (result is Map) {
        data = Map<String, dynamic>.from(result);
      } else {
        print('❌ result is not a Map: ${result.runtimeType}');
        return null;
      }

      // استخراج البيانات من مفتاح 'data' إذا كان موجوداً
      if (data.containsKey('data') && data['data'] is Map) {
        data = Map<String, dynamic>.from(data['data']);
      }

      // التأكد من وجود المفاتيح المطلوبة
      if (!data.containsKey('info')) data['info'] = {};
      if (!data.containsKey('movie_data')) data['movie_data'] = {};

      print('✅ تم جلب معلومات الفيلم بنجاح');
      return data;
    } catch (e) {
      print('❌ خطأ في getMovieInfo: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSeriesInfo(int seriesId) async {
    try {
      print('🔄 محاولة جلب معلومات المسلسل: $seriesId');
      final result = await _proxyGet('get_series_info', params: {'series_id': seriesId});

      if (result == null) {
        print('❌ result is null');
        return null;
      }

      // تحويل النتيجة إلى Map بشكل آمن
      Map<String, dynamic> data;
      if (result is Map) {
        data = Map<String, dynamic>.from(result);
      } else {
        print('❌ result is not a Map: ${result.runtimeType}');
        return null;
      }

      // استخراج البيانات من مفتاح 'data' إذا كان موجوداً
      if (data.containsKey('data') && data['data'] is Map) {
        data = Map<String, dynamic>.from(data['data']);
      }

      // التأكد من وجود المفاتيح المطلوبة
      if (!data.containsKey('episodes')) data['episodes'] = {};
      if (!data.containsKey('info')) data['info'] = {};
      if (!data.containsKey('seasons')) data['seasons'] = [];

      print('✅ تم جلب معلومات المسلسل بنجاح');
      if (data['episodes'] is Map) {
        int episodeCount = 0;
        (data['episodes'] as Map).forEach((key, value) {
          if (value is List) episodeCount += value.length;
        });
        print('📊 عدد الحلقات: $episodeCount');
      }
      return data;
    } catch (e) {
      print('❌ خطأ في getSeriesInfo: $e');
      return null;
    }
  }

  // ================= دوال جلب المحتوى =================

  Future<List<LiveStreamItem>> getLiveChannels({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid() && _cachedChannels != null) {
      print('✅ استخدام الكاش للقنوات');
      return _cachedChannels!;
    }
    print('🔄 جلب القنوات عبر البروكسي...');
    final list = await _proxyGetList('get_live_streams');
    final channels = list.map((e) => LiveStreamItem.fromJson(e)).toList();
    _cachedChannels = channels;
    _lastFetchTime = DateTime.now();
    print('✅ تم جلب ${channels.length} قناة');
    return channels;
  }

  Future<List<VodItem>> getMovies({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid() && _cachedMovies != null) {
      print('✅ استخدام الكاش للأفلام');
      return _cachedMovies!;
    }
    print('🔄 جلب الأفلام عبر البروكسي...');
    final list = await _proxyGetList('get_vod_streams');
    final movies = list.map((e) => VodItem.fromJson(e)).toList();
    _cachedMovies = movies;
    _lastFetchTime = DateTime.now();
    print('✅ تم جلب ${movies.length} فيلم');
    return movies;
  }

  Future<List<SeriesItem>> getSeries({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid() && _cachedSeries != null) {
      print('✅ استخدام الكاش للمسلسلات');
      return _cachedSeries!;
    }
    print('🔄 جلب المسلسلات عبر البروكسي...');
    final list = await _proxyGetList('get_series');
    final series = list.map((e) => SeriesItem.fromJson(e)).toList();
    _cachedSeries = series;
    _lastFetchTime = DateTime.now();
    print('✅ تم جلب ${series.length} مسلسل');
    return series;
  }

  // ================= دوال التصنيفات =================

  Future<void> _loadChannelCategories() async {
    final list = await _proxyGetList('get_live_categories');
    _channelCategories = {
      for (var cat in list)
        int.tryParse(cat['category_id']?.toString() ?? '0') ?? 0: cat['category_name']?.toString() ?? 'غير معروف',
    };
    print('✅ تم تحميل ${_channelCategories.length} تصنيف للقنوات');
  }

  Future<void> _loadMovieCategories() async {
    final list = await _proxyGetList('get_vod_categories');
    _movieCategories = {
      for (var cat in list)
        int.tryParse(cat['category_id']?.toString() ?? '0') ?? 0: cat['category_name']?.toString() ?? 'غير معروف',
    };
    print('✅ تم تحميل ${_movieCategories.length} تصنيف للأفلام');
  }

  Future<void> _loadSeriesCategories() async {
    final list = await _proxyGetList('get_series_categories');
    _seriesCategories = {
      for (var cat in list)
        int.tryParse(cat['category_id']?.toString() ?? '0') ?? 0: cat['category_name']?.toString() ?? 'غير معروف',
    };
    print('✅ تم تحميل ${_seriesCategories.length} تصنيف للمسلسلات');
  }

  // ================= مسح الكاش =================

  Future<void> clearCache() async {
    _cachedChannels = null;
    _cachedMovies = null;
    _cachedSeries = null;
    _lastFetchTime = null;
    _firstLoadDone = false;
    print('🗑️ تم مسح الكاش');
  }
}

// ================= كلاسات البيانات =================

class LiveStreamItem {
  final int id; final String name; final int streamId; final String streamIcon; final int categoryId;
  LiveStreamItem({required this.id, required this.name, required this.streamId, required this.streamIcon, required this.categoryId});
  factory LiveStreamItem.fromJson(Map<String, dynamic> json) => LiveStreamItem(
    id: int.tryParse(json['num']?.toString() ?? '0') ?? 0,
    name: json['name']?.toString() ?? 'قناة',
    streamId: int.tryParse(json['stream_id']?.toString() ?? '0') ?? 0,
    streamIcon: json['stream_icon']?.toString() ?? '',
    categoryId: int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
  );
}

class VodItem {
  final int id; final String name; final int streamId; final String streamIcon; final int categoryId;
  VodItem({required this.id, required this.name, required this.streamId, required this.streamIcon, required this.categoryId});
  factory VodItem.fromJson(Map<String, dynamic> json) => VodItem(
    id: int.tryParse(json['num']?.toString() ?? '0') ?? 0,
    name: json['name']?.toString() ?? 'فيلم',
    streamId: int.tryParse(json['stream_id']?.toString() ?? '0') ?? 0,
    streamIcon: json['stream_icon']?.toString() ?? '',
    categoryId: int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
  );
}

class SeriesItem {
  final int id; final String name; final int streamId; final String streamIcon; final int categoryId;
  SeriesItem({required this.id, required this.name, required this.streamId, required this.streamIcon, required this.categoryId});
  factory SeriesItem.fromJson(Map<String, dynamic> json) => SeriesItem(
    id: int.tryParse(json['num']?.toString() ?? '0') ?? 0,
    name: json['name']?.toString() ?? 'مسلسل',
    streamId: int.tryParse(json['series_id']?.toString() ?? '0') ?? 0,
    streamIcon: json['cover']?.toString() ?? '',
    categoryId: int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
  );
}