// lib/services/push_service.dart

import 'dart:convert';  // ✅ هذا السطر المهم جداً
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'app_update_service.dart';
import '../main.dart'; // rootNavigatorKey

class PushService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  /// تهيئة الإشعارات المحلية
  static Future<void> initLocalNotifications() async {
    // إعدادات Android
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          _handleNotificationPayload(response.payload!);
        }
      },
    );
    
    // إنشاء قناة واحدة لجميع الإشعارات
    await _createNotificationChannel();
  }

  /// إنشاء قناة واحدة لجميع الإشعارات
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      '2net_channel',
      '2Net',
      description: 'جميع إشعارات تطبيق 2Net',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Colors.blue,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// عرض إشعار محلي
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      '2net_channel',
      '2Net',
      channelDescription: 'جميع إشعارات تطبيق 2Net',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Colors.blue,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// تحديث FCM token للجهاز الحالي
  static Future<void> refreshToken(String token) async {
    try {
      print('🔄 محاولة تحديث FCM token للجهاز الحالي...');
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      
      if (fcmToken != null && fcmToken.isNotEmpty) {
        print('📱 FCM token المستلم: $fcmToken');
        
        await ApiService.saveFcmToken(
          token: token,
          fcmToken: fcmToken,
        );
        
        print('✅ تم تحديث FCM token للجهاز الحالي بنجاح');
        
        // الاستماع لتغيّر التوكن
        FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
          print('♻️ FCM token تغير: $newToken');
          await ApiService.saveFcmToken(
            token: token,
            fcmToken: newToken,
          );
        });
      } else {
        print('❌ فشل الحصول على FCM token');
      }
    } catch (e) {
      print('❌ خطأ في تحديث FCM token: $e');
    }
  }

  /// ✅ تحديث جميع أجهزة المستخدم (للاستخدام عند تسجيل الدخول)
  static Future<void> refreshAllDevices(String token) async {
    try {
      print('🔄 محاولة تحديث جميع أجهزة المستخدم...');
      
      // هذا سيسجل الجهاز الحالي فقط
      // لكن السيرفر سيرسل الإشعارات لجميع الأجهزة المسجلة لهذا المستخدم
      await refreshToken(token);
      
      // يمكنك إضافة منطق إضافي هنا إذا أردت
      // مثلاً: إرسال إشعار تجريبي لجميع الأجهزة
      
      print('✅ تم تحديث جميع أجهزة المستخدم بنجاح');
      
    } catch (e) {
      print('❌ خطأ في تحديث جميع الأجهزة: $e');
    }
  }

  // ============================================================
  // ✅ دالة جديدة: فرض تسجيل FCM token حتى لو كان مكرر
  // ============================================================
  static Future<void> forceRegisterDevice(String token) async {
    try {
      print('🔥 [Force] بدء فرض تسجيل الجهاز...');
      
      // 1. طلب الإذن مرة أخرى للتأكيد
      print('🔔 [Force] طلب إذن الإشعارات...');
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // 2. انتظر قليلاً
      await Future.delayed(const Duration(seconds: 1));
      
      // 3. محاولة الحصول على FCM token
      print('📱 [Force] محاولة الحصول على FCM token...');
      String? fcmToken = await _fcm.getToken();
      
      if (fcmToken == null || fcmToken.isEmpty) {
        print('❌ [Force] فشل الحصول على FCM token');
        return;
      }
      
      print('📱 [Force] FCM token المستلم: $fcmToken');
      
      // 4. محاولة التسجيل المباشر مع تجاهل الأخطاء
      try {
        print('📡 [Force] إرسال طلب التسجيل إلى السيرفر...');
        
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/register_fcm.php'),
          headers: {'X-Auth-Token': token},
          body: {'fcm_token': fcmToken, 'device': 'android'},
        ).timeout(const Duration(seconds: 10));
        
        print('📡 [Force] استجابة السيرفر: ${response.statusCode}');
        print('📦 [Force] النص: ${response.body}');
        
        if (response.statusCode == 200) {
          print('✅ [Force] تم تسجيل الجهاز بنجاح');
        } else {
          print('⚠️ [Force] فشل التسجيل: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ [Force] خطأ في الاتصال: $e');
      }
      
      // 5. محاولة JSON أيضاً
      try {
        print('📡 [Force] محاولة التسجيل بصيغة JSON...');
        
        final jsonResponse = await http.post(
          Uri.parse('${ApiService.baseUrl}/register_fcm.php'),
          headers: {
            'X-Auth-Token': token,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'fcm_token': fcmToken,
            'device': 'android',
          }),
        ).timeout(const Duration(seconds: 10));
        
        print('📡 [Force] JSON استجابة: ${jsonResponse.statusCode}');
        print('📦 [Force] JSON نص: ${jsonResponse.body}');
        
      } catch (e) {
        print('❌ [Force] خطأ في JSON: $e');
      }
      
      // 6. تحديث التوكن في الخلفية
      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
        print('♻️ [Force] FCM token تغير: $newToken');
        try {
          await http.post(
            Uri.parse('${ApiService.baseUrl}/register_fcm.php'),
            headers: {'X-Auth-Token': token},
            body: {'fcm_token': newToken, 'device': 'android'},
          );
        } catch (e) {}
      });
      
      print('✅ [Force] انتهت عملية فرض التسجيل');
      
    } catch (e) {
      print('❌ [Force] خطأ عام: $e');
    }
  }

  /// تهيئة الإشعارات
  static Future<void> init(String token) async {
    try {
      // تهيئة الإشعارات المحلية
      await initLocalNotifications();

      // طلب الإذن
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
        criticalAlert: true,
      );

      print("🔔 Notification permission: ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print("❌ Notification permission denied");
        return;
      }

      // الحصول على FCM Token
      final String? fcmToken = await _fcm.getToken();
      print("🔥 FCM TOKEN = $fcmToken");

      if (fcmToken == null || fcmToken.isEmpty) {
        print("❌ FCM token is null or empty");
        return;
      }

      // إرسال التوكن إلى السيرفر
      await ApiService.saveFcmToken(
        token: token,
        fcmToken: fcmToken,
      );
      print("✅ FCM token sent to server");

      // الاستماع لتغيّر التوكن
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (String newToken) async {
          print("♻️ FCM token refreshed = $newToken");
          await ApiService.saveFcmToken(
            token: token,
            fcmToken: newToken,
          );
        },
      );

      // ✅ معالجة الإشعارات عندما يكون التطبيق مغلقاً
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print("📱 App opened from terminated state: ${initialMessage.data}");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotification(initialMessage);
        });
      }

      // ✅ الاستماع عند فتح التطبيق من إشعار (التطبيق في الخلفية)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("📱 App opened from background: ${message.data}");
        _handleNotification(message);
      });

      // ✅ الاستماع للإشعارات أثناء تشغيل التطبيق
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("🔔 Foreground message: ${message.data}");
        _showForegroundNotification(message);
      });

      // ✅ معالج الخلفية
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      print("✅ PushService initialized successfully");

    } catch (e) {
      print("❌ PushService init error: $e");
    }
  }

  /// ✅ معالجة الإشعارات - نسخة محدثة مع indices الصحيحة
  static void _handleNotification(RemoteMessage message) {
    print("🔔 Notification opened: ${message.data}");
    
    final type = message.data['type'];
    final action = message.data['action'];
    final apkUrl = message.data['apk_url'];
    final ticketId = message.data['ticket_id'];
    
    // تحديث التطبيق
    if (apkUrl != null && apkUrl.isNotEmpty) {
      AppUpdateService.silentDownload(apkUrl, 'تحديث جديد');
      return;
    }

    // ✅ التأكد من وجود navigator
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      print("❌ Navigator is null");
      return;
    }

    // فتح التذاكر (الدعم - index 3)
    if (type == 'open_tickets' || action == 'open_tickets_screen' || type == 'ticket_reply') {
      print("🟢 فتح شاشة التذاكر (index 3)");
      navigator.pushNamedAndRemoveUntil(
        '/main', 
        (route) => false,
        arguments: {'selectedTab': 3}, // ✅ الدعم index 3
      );
      return;
    }

    // فتح تذكرة محددة
    if (type == 'ticket_reply' && ticketId != null) {
      print("🟢 فتح تذكرة رقم: $ticketId");
      
      // ✅ فتح الرئيسية ثم التذكرة
      navigator.pushNamedAndRemoveUntil(
        '/main',
        (route) => false,
        arguments: {'selectedTab': 3},
      ).then((_) {
        // بعد فتح الرئيسية، افتح التذكرة
        Future.delayed(const Duration(milliseconds: 300), () {
          navigator.pushNamed(
            '/ticket-details',
            arguments: int.parse(ticketId),
          );
        });
      });
      return;
    }

    // ✅ باقي الإشعارات تفتح تبويب الإشعارات (index 2)
    print("🟢 فتح تبويب الإشعارات (index 2)");
    navigator.pushNamedAndRemoveUntil(
      '/main',
      (route) => false,
      arguments: {'selectedTab': 2}, // ✅ الإشعارات index 2
    );
  }

  /// معالجة payload
  static void _handleNotificationPayload(String payload) {
    try {
      final data = <String, dynamic>{};
      payload.split(',').forEach((e) {
        final parts = e.split(':');
        if (parts.length == 2) {
          data[parts[0].trim()] = parts[1].trim();
        }
      });
      
      _handleNotification(RemoteMessage(data: data));
    } catch (e) {
      print("❌ Error parsing payload: $e");
    }
  }

  /// عرض إشعار في المقدمة
  static void _showForegroundNotification(RemoteMessage message) {
    final title = message.notification?.title ?? 'إشعار 2Net';
    final body = message.notification?.body ?? '';
    final data = message.data;
    
    // عرض إشعار محلي
    showLocalNotification(
      title: title,
      body: body,
      payload: data.toString(),
    );
    
    // ✅ عرض SnackBar محسن
    final context = rootNavigatorKey.currentState?.overlay?.context;
    if (context != null) {
      // إخفاء أي SnackBar قديم
      ScaffoldMessenger.of(context).clearSnackBars();
      
      // عرض SnackBar جديد مع معالجة الضغط
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          duration: const Duration(seconds: 6),
          backgroundColor: _getSnackBarColor(data['type']),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'عرض',
            textColor: Colors.white,
            onPressed: () {
              // ✅ إغلاق SnackBar أولاً
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              
              // ✅ ثم فتح الإشعار
              _handleNotification(message);
            },
          ),
        ),
      );
    }
  }

  /// لون SnackBar
  static Color _getSnackBarColor(String? type) {
    switch (type) {
      case 'expired': return Colors.red;
      case 'expire_soon': return Colors.orange;
      case 'renewed': return Colors.green;
      case 'extend_days': return Colors.teal;
      case 'reset_subscription': return Colors.amber;
      case 'ticket_reply': return Colors.blue;
      default: return Colors.grey;
    }
  }

  /// ✅ معالج الخلفية
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("📥 Background message received: ${message.messageId}");
    print("📥 Background data: ${message.data}");
    print("📥 Background notification: ${message.notification?.title}");
    
    final title = message.notification?.title ?? 
                  message.data['title'] ?? 
                  'إشعار 2Net';
    
    final body = message.notification?.body ?? 
                 message.data['body'] ?? 
                 'لديك إشعار جديد';
    
    final type = message.data['type'] ?? 'unknown';
    
    print("📥 Processing background notification of type: $type");
    
    try {
      await showLocalNotification(
        title: title,
        body: body,
        payload: message.data.toString(),
      );
      
      print("✅ Background notification shown successfully for type: $type");
    } catch (e) {
      print("❌ Error showing background notification: $e");
    }
  }
}