// lib/services/push_service.dart

import 'dart:convert';
import 'dart:async';
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
  
  // للتحكم بالـ listeners
  static StreamSubscription? _tokenSubscription;
  static StreamSubscription? _messageSubscription;
  static StreamSubscription? _messageOpenedSubscription;

  /// تهيئة الإشعارات المحلية
  static Future<void> initLocalNotifications() async {
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
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
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

  /// ✅ تحديث FCM token مع إعادة محاولة (محسّن)
  static Future<void> refreshToken(String? token, {int maxRetries = 5}) async {
    if (token == null || token.isEmpty) {
      debugPrint('❌ token is null or empty in refreshToken');
      return;
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        debugPrint('🔄 محاولة ${attempt + 1} للحصول على FCM token...');
        String? fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken != null && fcmToken.isNotEmpty) {
          debugPrint('📱 FCM token المستلم: ${fcmToken.substring(0, 20)}...');
          await ApiService.saveFcmToken(
            token: token,
            fcmToken: fcmToken,
          );
          debugPrint('✅ تم تحديث FCM token للجهاز الحالي بنجاح');

          // إلغاء الاشتراك القديم إذا موجود
          await _tokenSubscription?.cancel();
          
          // الاستماع لتغيّر التوكن
          _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
            (String newToken) async {
              debugPrint('♻️ FCM token تغير: ${newToken.substring(0, 20)}...');
              try {
                await ApiService.saveFcmToken(
                  token: token,
                  fcmToken: newToken,
                );
                debugPrint('✅ تم تحديث FCM token الجديد');
              } catch (e) {
                debugPrint('❌ خطأ في تحديث FCM token الجديد: $e');
              }
            },
            onError: (error) {
              debugPrint('❌ خطأ في onTokenRefresh: $error');
            },
          );
          
          return; // نجاح
        } else {
          debugPrint('⚠️ FCM token فارغ');
        }
      } catch (e) {
        debugPrint('❌ خطأ في المحاولة ${attempt + 1}: $e');
        if (e.toString().contains('SERVICE_NOT_AVAILABLE')) {
          debugPrint('⚠️ SERVICE_NOT_AVAILABLE – قد يكون بسبب الشبكة أو خدمات Google Play.');
        }
      }

      attempt++;
      if (attempt < maxRetries) {
        // انتظار قبل إعادة المحاولة: 2^attempt ثانية (1, 2, 4, 8...)
        int delaySeconds = 1 << attempt; // 2^attempt
        debugPrint('⏳ انتظار $delaySeconds ثانية قبل إعادة المحاولة...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
    debugPrint('❌ فشل الحصول على FCM token بعد $maxRetries محاولات');
  }

  /// ✅ تحديث جميع أجهزة المستخدم (محسّن)
  static Future<void> refreshAllDevices(String? token) async {
    if (token == null || token.isEmpty) {
      debugPrint('❌ token is null or empty in refreshAllDevices');
      return;
    }

    try {
      debugPrint('🔄 محاولة تحديث جميع أجهزة المستخدم...');
      await refreshToken(token);
      debugPrint('✅ تم تحديث جميع أجهزة المستخدم بنجاح');
    } catch (e) {
      debugPrint('❌ خطأ في تحديث جميع الأجهزة: $e');
    }
  }

  // ============================================================
  // ✅ دالة فرض تسجيل FCM token (كما هي)
  // ============================================================
  static Future<bool> forceRegisterDevice(String? token) async {
    if (token == null || token.isEmpty) {
      debugPrint('❌ token is null or empty in forceRegisterDevice');
      return false;
    }

    try {
      debugPrint('🔥 [Force] بدء فرض تسجيل الجهاز...');
      
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('❌ [Force] تم رفض الإذن');
        return false;
      }
      
      await Future.delayed(const Duration(seconds: 1));
      String? fcmToken = await _fcm.getToken();

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('❌ [Force] فشل الحصول على FCM token');
        return false;
      }
      debugPrint('📱 [Force] FCM token المستلم: ${fcmToken.substring(0, 20)}...');

      // جرب JSON أولاً (الأكثر توافقاً)
      bool success = false;
      
      try {
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
        
        debugPrint('📡 [Force] JSON استجابة: ${jsonResponse.statusCode}');
        
        if (jsonResponse.statusCode == 200) {
          success = true;
        }
      } catch (e) {
        debugPrint('❌ [Force] خطأ في JSON: $e');
      }

      // إذا فشل JSON، جرب multipart
      if (!success) {
        try {
          final response = await http.post(
            Uri.parse('${ApiService.baseUrl}/register_fcm.php'),
            headers: {'X-Auth-Token': token},
            body: {'fcm_token': fcmToken, 'device': 'android'},
          ).timeout(const Duration(seconds: 10));
          
          debugPrint('📡 [Force] استجابة multipart: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            success = true;
          }
        } catch (e) {
          debugPrint('❌ [Force] خطأ في multipart: $e');
        }
      }

      // إلغاء الاشتراك القديم
      await _tokenSubscription?.cancel();
      
      // استماع للتغييرات المستقبلية
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (String newToken) async {
          debugPrint('♻️ [Force] FCM token تغير: ${newToken.substring(0, 20)}...');
          try {
            await http.post(
              Uri.parse('${ApiService.baseUrl}/register_fcm.php'),
              headers: {'X-Auth-Token': token},
              body: {'fcm_token': newToken, 'device': 'android'},
            );
            debugPrint('✅ [Force] تم تحديث FCM token الجديد');
          } catch (e) {
            debugPrint('❌ [Force] خطأ في تحديث FCM token: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ [Force] خطأ في onTokenRefresh: $error');
        },
      );

      debugPrint('✅ [Force] انتهت عملية فرض التسجيل بنجاح: $success');
      return success;
      
    } catch (e) {
      debugPrint('❌ [Force] خطأ عام: $e');
      return false;
    }
  }

  /// تهيئة الإشعارات (محسّنة)
  static Future<void> init(String? token) async {
    if (token == null || token.isEmpty) {
      debugPrint('❌ token is null or empty in init');
      return;
    }

    try {
      await initLocalNotifications();

      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
        criticalAlert: true,
      );

      debugPrint("🔔 Notification permission: ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint("❌ Notification permission denied");
        return;
      }

      // محاولة الحصول على التوكن مع إعادة المحاولة
      await refreshToken(token);

      // إلغاء الاشتراكات القديمة
      await _messageSubscription?.cancel();
      await _messageOpenedSubscription?.cancel();

      // الاستماع للأحداث الأخرى
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint("📱 App opened from terminated state: ${initialMessage.data}");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotification(initialMessage);
        });
      }

      _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          debugPrint("📱 App opened from background: ${message.data}");
          _handleNotification(message);
        },
        onError: (error) {
          debugPrint('❌ خطأ في onMessageOpenedApp: $error');
        },
      );

      _messageSubscription = FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          debugPrint("🔔 Foreground message: ${message.data}");
          _showForegroundNotification(message);
        },
        onError: (error) {
          debugPrint('❌ خطأ في onMessage: $error');
        },
      );

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      debugPrint("✅ PushService initialized successfully");
    } catch (e) {
      debugPrint("❌ PushService init error: $e");
    }
  }

  /// ✅ معالجة الإشعارات
  static void _handleNotification(RemoteMessage message) {
    debugPrint("🔔 Notification opened: ${message.data}");
    final type = message.data['type'];
    final action = message.data['action'];
    final apkUrl = message.data['apk_url'];
    final ticketId = message.data['ticket_id'];

    if (apkUrl != null && apkUrl.isNotEmpty) {
      AppUpdateService.silentDownload(apkUrl, 'تحديث جديد');
      return;
    }

    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint("❌ Navigator is null");
      return;
    }

    // ✅ إذا كان الإشعار خاص بتذكرة، نفتح التذكرة مباشرة
    if (type == 'ticket_reply' && ticketId != null) {
      int? ticketIdInt = int.tryParse(ticketId.toString());
      if (ticketIdInt != null && ticketIdInt > 0) {
        debugPrint("🟢 فتح تذكرة رقم: $ticketIdInt مباشرة");
        
        // نفتح main مع بارامترات لفتح التذكرة
        navigator.pushNamedAndRemoveUntil(
          '/main',
          (route) => false,
          arguments: {
            'selectedTab': 3,  // تبويب الدعم
            'openTicketId': ticketIdInt,
            'fromNotification': true,  // مؤشر أنه من إشعار
          },
        );
        return;
      }
    }

    // باقي الحالات
    if (type == 'open_tickets' || action == 'open_tickets_screen') {
      debugPrint("🟢 فتح شاشة التذاكر (index 3)");
      navigator.pushNamedAndRemoveUntil(
        '/main',
        (route) => false,
        arguments: {'selectedTab': 3},
      );
      return;
    }

    debugPrint("🟢 فتح تبويب الإشعارات (index 2)");
    navigator.pushNamedAndRemoveUntil(
      '/main',
      (route) => false,
      arguments: {'selectedTab': 2},
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
      debugPrint("❌ Error parsing payload: $e");
    }
  }

  /// عرض إشعار في المقدمة
  static void _showForegroundNotification(RemoteMessage message) {
    final title = message.notification?.title ?? 'إشعار 2Net';
    final body = message.notification?.body ?? '';
    final data = message.data;

    showLocalNotification(
      title: title,
      body: body,
      payload: data.toString(),
    );

    final context = rootNavigatorKey.currentState?.overlay?.context;
    if (context != null) {
      ScaffoldMessenger.of(context).clearSnackBars();
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
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
      case 'expired':
        return Colors.red;
      case 'expire_soon':
        return Colors.orange;
      case 'renewed':
        return Colors.green;
      case 'extend_days':
        return Colors.teal;
      case 'reset_subscription':
        return Colors.amber;
      case 'ticket_reply':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// ✅ معالج الخلفية
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("📥 Background message received: ${message.messageId}");
    final title = message.notification?.title ?? message.data['title'] ?? 'إشعار 2Net';
    final body = message.notification?.body ?? message.data['body'] ?? 'لديك إشعار جديد';
    final type = message.data['type'] ?? 'unknown';
    debugPrint("📥 Processing background notification of type: $type");

    try {
      await showLocalNotification(
        title: title,
        body: body,
        payload: message.data.toString(),
      );
      debugPrint("✅ Background notification shown successfully for type: $type");
    } catch (e) {
      debugPrint("❌ Error showing background notification: $e");
    }
  }

  /// ✅ دالة لإلغاء الاشتراكات (نظيفة)
  static void dispose() {
    _tokenSubscription?.cancel();
    _messageSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    debugPrint('🧹 تم إلغاء جميع اشتراكات PushService');
  }
}