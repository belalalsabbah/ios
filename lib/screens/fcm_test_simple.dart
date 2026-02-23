// lib/screens/fcm_test_simple.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import '../services/token_store.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';
import 'package:permission_handler/permission_handler.dart';  // ✅ أضف هذا السطر
class FcmTestSimple extends StatefulWidget {
  const FcmTestSimple({super.key});

  @override
  State<FcmTestSimple> createState() => _FcmTestSimpleState();
}

class _FcmTestSimpleState extends State<FcmTestSimple> {
  String _result = 'اضغط على الزر لبدء الاختبار';
  bool _loading = false;
  String? _fcmToken;
  String? _sessionToken;
  String? _directToken;
  String? _deviceInfo;
  bool _hasPermission = false;
  String? _username;
  
  // ✅ متغير للتحقق إذا كان المستخدم هو belal
  bool get _isBelal => _username == 'belal';

  @override
  void initState() {
    super.initState();
    _loadTokens();
    _checkDeviceInfo();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = prefs.getString('username');
      });
    } catch (e) {
      print('❌ Error loading username: $e');
    }
  }

  Future<void> _checkDeviceInfo() async {
    String info = '';
    info += '📱 الجهاز: ${Platform.operatingSystem}\n';
    info += '🔧 الإصدار: ${Platform.operatingSystemVersion}\n';
    
    setState(() {
      _deviceInfo = info;
    });
  }

 Future<void> _requestPermission() async {
  try {
    // 1. تحقق من الحالة أولاً
    NotificationSettings settings = await FirebaseMessaging.instance.getNotificationSettings();
    
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // إذا كان مرفوضاً، وجه المستخدم للإعدادات
      _showSettingsDialog();
      return;
    }
    
    // 2. إذا لم يطلب بعد، اطلب الإذن
    setState(() {
      _result = 'جاري طلب الإذن...';
    });

    NotificationSettings newSettings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    setState(() {
      _hasPermission = newSettings.authorizationStatus == AuthorizationStatus.authorized;
      _result = _hasPermission 
          ? '✅ تم منح إذن الإشعارات' 
          : '❌ رفض المستخدم إذن الإشعارات';
    });

    await _loadTokens();

  } catch (e) {
    setState(() {
      _result = '❌ خطأ في طلب الإذن: $e';
    });
  }
}

  Future<void> _loadTokens() async {
    try {
      String debug = '';
      
      // 1. جلب FCM token
      try {
        _fcmToken = await FirebaseMessaging.instance.getToken();
        debug += '📱 FCM token: ${_fcmToken != null ? 'موجود' : 'غير موجود'}\n';
      } catch (e) {
        debug += '❌ خطأ في جلب FCM token: $e\n';
        _fcmToken = null;
      }
      
      // 2. جلب session token من TokenStore
      try {
        _sessionToken = await TokenStore.load();
        debug += '🔑 TokenStore.load(): ${_sessionToken != null ? 'موجود' : 'غير موجود'}\n';
      } catch (e) {
        debug += '❌ خطأ في TokenStore.load(): $e\n';
        _sessionToken = null;
      }
      
      // 3. جلب التوكن مباشرة من SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        _directToken = prefs.getString('auth_token');
        debug += '📦 SharedPreferences مباشرة: ${_directToken != null ? 'موجود' : 'غير موجود'}\n';
      } catch (e) {
        debug += '❌ خطأ في SharedPreferences: $e\n';
        _directToken = null;
      }
      
      // 4. إذا كان في توكن في SharedPreferences ولكن TokenStore فشل
      if (_sessionToken == null && _directToken != null) {
        debug += '🔄 محاولة إصلاح TokenStore...\n';
        try {
          await TokenStore.save(_directToken!);
          _sessionToken = await TokenStore.load();
          debug += '✅ بعد الإصلاح: ${_sessionToken != null ? 'موجود' : 'فشل'}\n';
        } catch (e) {
          debug += '❌ فشل الإصلاح: $e\n';
        }
      }
      
      // 5. التحقق من حالة الإذن
      try {
        NotificationSettings settings = await FirebaseMessaging.instance.getNotificationSettings();
        switch (settings.authorizationStatus) {
          case AuthorizationStatus.authorized:
          case AuthorizationStatus.provisional:
            _hasPermission = true;
            break;
          case AuthorizationStatus.denied:
          case AuthorizationStatus.notDetermined:
            _hasPermission = false;
            break;
        }
        debug += '🔔 حالة الإذن: ${_hasPermission ? 'مصرح' : 'غير مصرح'}\n';
      } catch (e) {
        debug += '❌ خطأ في التحقق من الإذن: $e\n';
      }
      
      // 6. التحقق من دعم Firebase
      try {
        bool isSupported = await FirebaseMessaging.instance.isSupported();
        debug += '📱 Firebase مدعوم: ${isSupported ? 'نعم' : 'لا'}\n';
      } catch (e) {
        debug += '❌ خطأ في التحقق من الدعم: $e\n';
      }
      
      print('🔍 تشخيص التوكنات:\n$debug');
      
      setState(() {}); // تحديث الواجهة
      
    } catch (e) {
      print('❌ خطأ عام في _loadTokens: $e');
      setState(() {
        _result = '❌ خطأ في تحميل التوكنات: $e';
      });
    }
  }

  // دالة لفرض التسجيل
  Future<void> _forceRegister() async {
    setState(() {
      _loading = true;
      _result = '🔄 جاري فرض تسجيل الجهاز...';
    });

    try {
      String? token = _sessionToken ?? _directToken;
      if (token == null) {
        setState(() {
          _result = '❌ لا يوجد توكن جلسة للمستخدم';
          _loading = false;
        });
        return;
      }

      await PushService.forceRegisterDevice(token);
      
      await Future.delayed(const Duration(seconds: 2));
      
      await _loadTokens();
      await _testFcm();

    } catch (e) {
      setState(() {
        _result = '❌ خطأ في فرض التسجيل: $e';
        _loading = false;
      });
    }
  }

  Future<void> _testFcm() async {
    setState(() {
      _loading = true;
      _result = 'جاري الاختبار...';
    });

    try {
      String output = '';
      output += '════════════════════════════════════════\n';
      output += '🔍 بدء تشخيص FCM\n';
      output += '════════════════════════════════════════\n\n';

      // 1. معلومات الجهاز
      output += '📱 معلومات الجهاز:\n';
      output += '   ${_deviceInfo ?? 'غير متوفرة'}\n';
      output += '   👤 المستخدم: ${_username ?? 'غير معروف'}\n\n';

      // 2. التحقق من تسجيل الدخول
      String? sessionToken = _sessionToken ?? _directToken;
      if (sessionToken == null) {
        output += '❌ أنت غير مسجل دخول!\n';
        output += '   الرجاء تسجيل الدخول أولاً\n\n';
        setState(() {
          _result = output;
          _loading = false;
        });
        return;
      }

      // 3. التحقق من اتصال الإنترنت
      output += '🌐 فحص الاتصال بالإنترنت...\n';
      try {
        final response = await http.get(
          Uri.parse('https://www.google.com'),
          headers: {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          output += '   ✅ متصل بالإنترنت\n\n';
        } else {
          output += '   ⚠️ اتصال محدود (${response.statusCode})\n\n';
        }
      } catch (e) {
        output += '   ❌ لا يوجد اتصال بالإنترنت: $e\n\n';
      }

      // 4. التحقق من خدمات Google Play
      output += '📱 فحص خدمات Google Play...\n';
      bool isSupported = await FirebaseMessaging.instance.isSupported();
      if (isSupported) {
        output += '   ✅ Firebase مدعوم على هذا الجهاز\n\n';
      } else {
        output += '   ❌ Firebase غير مدعوم على هذا الجهاز\n\n';
      }

      // 5. حالة الإذن
      output += '🔔 حالة إذن الإشعارات:\n';
      NotificationSettings settings = await FirebaseMessaging.instance.getNotificationSettings();
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          output += '   ✅ مصرح\n';
          break;
        case AuthorizationStatus.provisional:
          output += '   ⚠️ مصرح بشكل مؤقت\n';
          break;
        case AuthorizationStatus.denied:
          output += '   ❌ مرفوض\n';
          break;
        case AuthorizationStatus.notDetermined:
          output += '   ❓ لم يطلب بعد\n';
          break;
      }
      output += '\n';

      // 6. FCM token - مخفي للمستخدم العادي
      output += '📱 FCM TOKEN:\n';
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        output += '   ✅ موجود\n';
        if (_isBelal) {
          output += '   📝 $fcmToken\n\n';
        } else {
          output += '   📝 [مخفي - للمسؤولين فقط]\n\n';
        }
        _fcmToken = fcmToken;
      } else {
        output += '   ❌ غير موجود\n';
        output += '   ⚠️ قد تحتاج لطلب الإذن أو إعادة تشغيل التطبيق\n\n';
        _fcmToken = null;
      }

      // 7. Session token (من TokenStore) - مخفي للمستخدم العادي
      output += '🔑 SESSION TOKEN:\n';
      if (_sessionToken != null) {
        output += '   ✅ موجود\n';
        if (_isBelal) {
          output += '   📝 ${_sessionToken!.substring(0, 20)}...\n\n';
        } else {
          output += '   📝 [مخفي - للمسؤولين فقط]\n\n';
        }
      } else {
        output += '   ❌ غير موجود\n\n';
      }

    // 8. التحقق من صحة التوكن في السيرفر - معدل ليعرض معلومات مناسبة لكل مستخدم
if (sessionToken != null) {  // ✅ للجميع وليس فقط للمسؤولين
  output += '════════════════════════════════════════\n';
  output += '🌐 التحقق من صحة التوكن في السيرفر...\n';
  output += '════════════════════════════════════════\n\n';

  try {
    final checkUrl = Uri.parse('${ApiService.baseUrl}/check_token');
    final checkResponse = await http.get(
      checkUrl,
      headers: {
        'X-Auth-Token': sessionToken,
      },
    ).timeout(const Duration(seconds: 5));
    
    output += '📤 حالة الاستجابة: ${checkResponse.statusCode}\n';
    
    // محاولة تحليل JSON
    try {
      var jsonData = jsonDecode(checkResponse.body);
      
      if (checkResponse.statusCode == 200 && jsonData['ok'] == true) {
        // ✅ توكن صالح
        output += '✅ التوكن: صالح\n';
        output += '   👤 المستخدم: ${jsonData['username'] ?? 'غير معروف'}\n';
        output += '   📅 تاريخ انتهاء التوكن: ${jsonData['expires_at'] ?? 'غير محدد'}\n';
        
        // ✅ معلومات إضافية للمسؤول فقط
        if (_isBelal) {
          output += '\n📋 معلومات إضافية (للمسؤول):\n';
          output += '   📝 الاسم: ${jsonData['name'] ?? 'غير معروف'}\n';
          output += '   📅 انتهاء الاشتراك: ${jsonData['user_expiration'] ?? 'غير محدد'}\n';
          output += '   📦 البيانات كاملة: ${jsonEncode(jsonData)}\n';
        }
      } else {
        // ❌ توكن غير صالح
        output += '❌ التوكن: غير صالح\n';
        output += '   ⚠️ السبب: ${jsonData['message'] ?? jsonData['error'] ?? 'خطأ غير معروف'}\n';
        
        // ✅ معلومات إضافية للمسؤول فقط عند الخطأ
        if (_isBelal) {
          output += '\n📋 تفاصيل الخطأ (للمسؤول):\n';
          output += '   📦 ${jsonEncode(jsonData)}\n';
        }
      }
      output += '\n';
      
    } catch (e) {
      output += '❌ فشل تحليل استجابة السيرفر\n';
      if (_isBelal) {
        output += '📦 النص الخام: ${checkResponse.body}\n';
      }
      output += '\n';
    }
  } catch (e) {
    output += '❌ فشل الاتصال بالسيرفر: $e\n\n';
  }
}
 
  // 9. إذا كان كل شيء موجود، جرب التسجيل
if (fcmToken != null && sessionToken != null) {
  output += '════════════════════════════════════════\n';
  output += '📤 محاولة تسجيل FCM في السيرفر...\n';
  output += '════════════════════════════════════════\n\n';

  final url = Uri.parse('${ApiService.baseUrl}/register_fcm.php');

  try {
    final jsonResponse = await http.post(
      url,
      headers: {
        'X-Auth-Token': sessionToken,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fcm_token': fcmToken,
        'device': 'android',
      }),
    ).timeout(const Duration(seconds: 10));
    
    output += '📤 JSON Response: ${jsonResponse.statusCode}\n';
    
    try {
      var jsonData = jsonDecode(jsonResponse.body);
      
      // ✅ إذا كان المستخدم هو belal، اعرض كل البيانات
      if (_isBelal) {
        String responseData = jsonEncode(jsonData, toEncodable: (e) => e.toString());
        output += '📦 البيانات: $responseData\n';
        
        if (jsonData['ok'] == true) {
          output += '✅ تم التسجيل بنجاح!\n';
          if (jsonData['username'] != null) {
            output += '   👤 المستخدم: ${jsonData['username']}\n';
          }
        } else {
          output += '❌ فشل التسجيل: ${jsonData['error'] ?? 'خطأ غير معروف'}\n';
        }
      } 
      // ✅ للمستخدمين العاديين، اعرض فقط نتيجة النجاح/الفشل
      else {
        if (jsonData['ok'] == true) {
          output += '✅ تم التسجيل بنجاح!\n';
        } else {
          output += '❌ فشل التسجيل\n';
        }
        output += '📦 [المعلومات مخفية للمستخدمين العاديين]\n';
      }
      
      output += '\n';

    } catch (e) {
      output += '📦 النص: ${jsonResponse.body}\n';
    }
    output += '\n';

  } catch (e) {
    output += '❌ خطأ في طلب JSON: $e\n\n';
  }
}

      setState(() {
        _result = output;
        _loading = false;
      });

    } catch (e) {
      setState(() {
        _result = '❌ خطأ عام: $e';
        _loading = false;
      });
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم النسخ')),
      );
    }
  }

  Future<void> _clearTokenAndRestart() async {
    try {
      await TokenStore.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      
      setState(() {
        _result = '✅ تم مسح التوكنات\nالرجاء إعادة تشغيل التطبيق';
        _sessionToken = null;
        _directToken = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔄 تم مسح التوكنات، أعد تشغيل التطبيق')),
        );
      }
    } catch (e) {
      setState(() {
        _result = '❌ فشل مسح التوكنات: $e';
      });
    }
  }
  

  void _showSettingsDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('تفعيل الإشعارات'),
      content: const Text(
        'تم رفض إذن الإشعارات. يمكنك تفعيلها من إعدادات الجهاز.'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('لاحقاً'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            openAppSettings(); // ✅ فتح إعدادات التطبيق
          },
          child: const Text('فتح الإعدادات'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🔧 فحص FCM'),
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          actions: [
            // ✅ زر النسخ الاحتياطي للمسؤولين فقط
            if (_isBelal)
              IconButton(
                icon: const Icon(Icons.copy_all),
                onPressed: () {
                  String allData = '''
المستخدم: $_username
FCM: ${_fcmToken ?? 'غير موجود'}
Session: ${_sessionToken ?? 'غير موجود'}
''';
                  _copyToClipboard(allData);
                },
                tooltip: 'نسخ كل البيانات',
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTokens,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // بطاقة المعلومات السريعة
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'معلومات سريعة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      
                      // المستخدم (غير حساس)
                      _buildInfoRow(
                        icon: Icons.person,
                        label: 'المستخدم',
                        value: _username ?? 'غير معروف',
                        color: _username != null ? Colors.blue : Colors.grey,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // حالة FCM (تظهر للمستخدم العادي كموجود/غير موجود)
                      _buildInfoRow(
                        icon: Icons.fingerprint,
                        label: 'حالة FCM',
                        value: _fcmToken != null ? '✅ موجود' : '❌ غير موجود',
                        color: _fcmToken != null ? Colors.green : Colors.red,
                        sensitiveValue: _fcmToken,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // حالة الجلسة (تظهر للمستخدم العادي كموجود/غير موجود)
                      _buildInfoRow(
                        icon: Icons.key,
                        label: 'حالة الجلسة',
                        value: _sessionToken != null ? '✅ موجود' : '❌ غير موجود',
                        color: _sessionToken != null ? Colors.green : Colors.red,
                        sensitiveValue: _sessionToken,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // حالة الإذن (غير حساس)
                      _buildInfoRow(
                        icon: Icons.notifications,
                        label: 'إذن الإشعارات',
                        value: _hasPermission ? '✅ مصرح' : '❌ غير مصرح',
                        color: _hasPermission ? Colors.green : Colors.orange,
                      ),
                      
                      // ✅ إظهار معلومات إضافية للمسؤول فقط
                      if (_isBelal && _directToken != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.storage,
                          label: 'التوكن المباشر',
                          value: '✅ موجود',
                          color: Colors.green,
                          sensitiveValue: _directToken,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // نتيجة الاختبار
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _result,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // أزرار الإجراءات
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _testFcm,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('بدء الاختبار'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  
                  OutlinedButton.icon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('طلب الإذن'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  
                  OutlinedButton.icon(
                    onPressed: _loadTokens,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  
                  // ✅ زر فرض التسجيل (متاح للجميع)
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _forceRegister,
                    icon: const Icon(Icons.power),
                    label: const Text('فرض التسجيل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  
                  // ✅ زر مسح التوكنات (متاح للجميع)
                  OutlinedButton.icon(
                    onPressed: _clearTokenAndRestart,
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('مسح التوكنات'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? sensitiveValue,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // ✅ إظهار زر النسخ للمسؤول فقط إذا كانت القيمة حساسة
        if (_isBelal && sensitiveValue != null)
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => _copyToClipboard(sensitiveValue),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}