// lib/services/api_service.dart - النسخة الكاملة مع دعم الأجهزة المتعددة

import 'dart:convert';
import 'dart:math';
import 'package:restart_app/restart_app.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_store.dart';
import '../main.dart'; // rootNavigatorKey
import '../screens/splash_screen.dart';

class ApiService {
  static String baseUrl = "http://50.50.50.1/api"; // سيتم تحديثها تلقائيًا
  
  // مفتاح لتخزين device_id
  static const String _deviceIdKey = 'device_id';

  // =========================
  // كشف الشبكة لتحديد baseUrl
  // =========================
  static Future<void> detectBaseUrl() async {
    try {
      final response = await http
          .get(Uri.parse('http://50.50.50.1/api/status'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        baseUrl = "http://50.50.50.1/api"; // داخل الشبكة
        return;
      }
    } catch (_) {
      // تجاهل الخطأ
    }

    // fallback للعنوان الخارجي
    baseUrl = "http://213.6.142.189:45678/api";
  }

  // =========================
  // دوال مساعدة للـ fallback
  // =========================
  static Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? headers}) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/$path"), headers: headers)
          .timeout(const Duration(seconds: 5));

      return await _handleResponse(response);
    } catch (_) {
      await detectBaseUrl();
      try {
        final response = await http
            .get(Uri.parse("$baseUrl/$path"), headers: headers)
            .timeout(const Duration(seconds: 5));

        return await _handleResponse(response);
      } catch (e) {
        return {'ok': false, 'error': 'connection_failed', 'message': e.toString()};
      }
    }
  }

  static Future<http.Response> _post(String path,
      {Map<String, String>? headers, Object? body}) async {
    try {
      final res = await http
          .post(Uri.parse("$baseUrl/$path"), headers: headers, body: body)
          .timeout(const Duration(seconds: 5));
      return res;
    } catch (_) {
      await detectBaseUrl();
      return await http
          .post(Uri.parse("$baseUrl/$path"), headers: headers, body: body)
          .timeout(const Duration(seconds: 5));
    }
  }

  // =================================================
  // دوال مساعدة للجهاز (Device ID)
  // =================================================
  
  /// إنشاء أو جلب device_id فريد للجهاز
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // محاولة جلب device_id المخزن
    String? deviceId = prefs.getString(_deviceIdKey);
    
    // إذا لم يكن موجوداً، ننشئ واحد جديد
    if (deviceId == null || deviceId.isEmpty) {
      // إنشاء معرف فريد (مزيج من التاريخ والرقم العشوائي)
      final random = Random.secure();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomNum = random.nextInt(1000000);
      deviceId = 'dev_${timestamp}_$randomNum';
      
      // حفظه في SharedPreferences
      await prefs.setString(_deviceIdKey, deviceId);
      debugPrint('📱 تم إنشاء device_id جديد: $deviceId');
    }
    
    return deviceId;
  }

  /// تحديث device_id (إذا احتجنا)
  static Future<void> updateDeviceId(String newDeviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIdKey, newDeviceId);
    debugPrint('📱 تم تحديث device_id: $newDeviceId');
  }

  // =================================================
  // BOOTSTRAP (SplashScreen)
  // =================================================
  static Future<Map<String, dynamic>> bootstrap({String? token}) async {
    final headers = <String, String>{"Accept": "application/json"};
    if (token != null && token.isNotEmpty) headers["X-Auth-Token"] = token;

    final result = await _get("app/bootstrap", headers: headers);
    return result;
  }

  // =================================================
  // STATUS (بدون تسجيل دخول – داخل الشبكة فقط)
  // =================================================
  static Future<Map<String, dynamic>> getStatusAnonymous() async {
    final result = await _get("status", headers: {"Accept": "application/json"});
    return result;
  }

  // =================================================
  // STATUS (بعد تسجيل الدخول)
  // =================================================
  static Future<Map<String, dynamic>> getStatus(String token) async {
    return await _get("status.php",
        headers: {"X-Auth-Token": token, "Accept": "application/json"});
  }

  // =================================================
  // LOGIN - مع device_id
  // =================================================
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      // ✅ جلب device_id الخاص بالجهاز
      final deviceId = await getDeviceId();
      
      final Map<String, dynamic> requestBody = {
        "username": username,
        "password": password,
        "device_id": deviceId, // إضافة device_id إلى الطلب
      };
      
      final response = await _post(
        "login",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode != 200) {
        return {
          'ok': false,
          'error': 'http_${response.statusCode}',
          'message': response.body,
        };
      }

      try {
        final result = json.decode(response.body) as Map<String, dynamic>;
        
        // ✅ حفظ device_id إذا رجعه السيرفر (قد يكون محدثاً)
        if (result.containsKey('device_id')) {
          await updateDeviceId(result['device_id']);
        }
        
        return result;
      } catch (e) {
        return {
          "ok": false,
          "error": "invalid_response",
          "message": response.body,
        };
      }
    } catch (e) {
      return {
        "ok": false,
        "error": "connection_failed",
        "message": e.toString(),
      };
    }
  }

  // =================================================
  // CREATE ACCOUNT
  // =================================================
  static Future<Map<String, dynamic>> createAccount({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _post("create-account",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json"
          },
          body: json.encode({"username": username, "password": password}));

      if (response.statusCode != 200) {
        return {
          'ok': false,
          'error': 'http_${response.statusCode}',
          'message': response.body,
        };
      }

      try {
        return json.decode(response.body);
      } catch (e) {
        return {
          'ok': false,
          'error': 'invalid_response',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'error': 'connection_failed',
        'message': e.toString(),
      };
    }
  }

  // =================================================
  // GET NOTIFICATIONS
  // =================================================
  static Future<Map<String, dynamic>> getNotifications(String token) async {
    return await _get("notifications.php",
        headers: {"X-Auth-Token": token, "Accept": "application/json"});
  }

  // =================================================
  // CREATE TICKET
  // =================================================
  static Future<Map<String, dynamic>> createTicket({
    required String token,
    required String type,
    required String message,
  }) async {
    try {
      final response = await _post("tickets/create",
          headers: {
            "X-Auth-Token": token,
            "Content-Type": "application/json",
            "Accept": "application/json"
          },
          body: json.encode({"type": type, "message": message}));

      if (response.statusCode != 200) {
        return {
          'ok': false,
          'error': 'http_${response.statusCode}',
          'message': response.body,
        };
      }

      try {
        return json.decode(response.body);
      } catch (e) {
        return {
          'ok': false,
          'error': 'invalid_response',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'error': 'connection_failed',
        'message': e.toString(),
      };
    }
  }

  // =================================================
  // SAVE FCM TOKEN - مع device_id
  // =================================================
  static Future<bool> saveFcmToken({
    required String token,
    required String fcmToken,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/register_fcm.php');
      
      // ✅ جلب device_id الخاص بالجهاز
      final deviceId = await getDeviceId();

      // الطريقة الأولى: JSON مع device_id
      try {
        final Map<String, dynamic> body = {
          'fcm_token': fcmToken,
          'device': 'android',
          'device_id': deviceId,
        };
        
        final jsonResponse = await http.post(
          url,
          headers: {
            'X-Auth-Token': token,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));

        debugPrint('📥 JSON استجابة: ${jsonResponse.statusCode}');

        if (jsonResponse.statusCode == 200) {
          // محاولة تحليل الاستجابة للحصول على device_id محدث
          try {
            final responseBody = json.decode(jsonResponse.body);
            if (responseBody['device_id'] != null) {
              await updateDeviceId(responseBody['device_id']);
            }
          } catch (_) {}
          
          debugPrint('✅ تم حفظ FCM token بنجاح (JSON)');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ فشل JSON: $e');
      }

      // الطريقة الثانية: Multipart مع device_id
      try {
        var request = http.MultipartRequest('POST', url);
        request.headers['X-Auth-Token'] = token;
        request.fields['fcm_token'] = fcmToken;
        request.fields['device'] = 'android';
        request.fields['device_id'] = deviceId;

        debugPrint('📤 محاولة Multipart مع device_id: $deviceId');

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        debugPrint('📥 Multipart استجابة: ${response.statusCode}');

        if (response.statusCode == 200) {
          debugPrint('✅ تم حفظ FCM token بنجاح (Multipart)');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ فشل Multipart: $e');
      }

      debugPrint('❌ فشلت جميع محاولات حفظ FCM token');
      return false;

    } catch (e) {
      debugPrint('❌ خطأ في saveFcmToken: $e');
      return false;
    }
  }

  // =================================================
  // HANDLE RESPONSE - النسخة المصححة
  // =================================================
  static Future<Map<String, dynamic>> _handleResponse(
    http.Response response, {
    bool throwOnError = false,
  }) async {
    // تحقق من حالة HTTP
    if (response.statusCode == 401) {
      debugPrint('🚨 Received 401 - checking session status');
      
      // ✅ التحقق من سبب 401
      final responseBody = response.body;
      
      // محاولة تحليل الاستجابة
      try {
        final jsonResponse = json.decode(responseBody);
        
        // إذا كان الخطأ بسبب تعارض الجلسات
        if (jsonResponse['error'] == 'session_conflict') {
          debugPrint('⚠️ Session conflict detected');
          
          if (rootNavigatorKey.currentContext != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showSessionConflictDialog(rootNavigatorKey.currentContext!);
            });
          }
          
          return {'ok': false, 'error': 'session_conflict'};
        }
      } catch (e) {
        // إذا كانت الاستجابة ليست JSON، نعتبرها token expired
        debugPrint('❌ Error parsing 401 response: $e');
      }

      // عرض رسالة للمستخدم وإعادة التوجيه
      if (rootNavigatorKey.currentContext != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTokenExpiredDialog(rootNavigatorKey.currentContext!);
        });
      }

      if (throwOnError) {
        throw Exception('token_expired');
      } else {
        return {'ok': false, 'error': 'token_expired'};
      }
    }

    // باقي حالات HTTP
    if (response.statusCode != 200) {
      return {
        'ok': false,
        'error': 'http_${response.statusCode}',
        'message': response.body,
      };
    }

    // محاولة تحليل JSON
    try {
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'ok': false,
        'error': 'invalid_response',
        'message': response.body,
      };
    }
  }

  // =================================================
  // SHOW SESSION CONFLICT DIALOG - نافذة جديدة
  // =================================================
  static void _showSessionConflictDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعارض الجلسات'),
        content: const Text(
          'تم تسجيل الدخول من جهاز آخر. هل تريد:\n\n'
          '• البقاء في هذا الجهاز (سيتم تسجيل خروج الجهاز الآخر)\n'
          '• تسجيل الخروج من هذا الجهاز'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // البقاء في هذا الجهاز - إرسال طلب لإبقاء هذه الجلسة
              _keepCurrentSession();
            },
            child: const Text('البقاء هنا'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              // تسجيل الخروج من هذا الجهاز فقط
              await TokenStore.clear();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('تسجيل خروج'),
          ),
        ],
      ),
    );
  }

  // =================================================
  // KEEP CURRENT SESSION - إبقاء الجلسة الحالية
  // =================================================
  static Future<void> _keepCurrentSession() async {
    final token = await TokenStore.load();
    if (token == null) return;
    
    try {
      // إرسال طلب لإبقاء هذه الجلسة وحذف الأخرى
      final response = await _post("keep-session.php",
          headers: {"X-Auth-Token": token});
      
      if (response.statusCode == 200) {
        debugPrint('✅ تم إبقاء الجلسة الحالية');
        
        // إظهار رسالة نجاح للمستخدم
        if (rootNavigatorKey.currentContext != null) {
          ScaffoldMessenger.of(rootNavigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('✅ تم إبقاء هذه الجلسة وتسجيل خروج الأجهزة الأخرى'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ فشل في إبقاء الجلسة: $e');
    }
  }

  // =================================================
  // SHOW TOKEN EXPIRED DIALOG
  // =================================================
  static void _showTokenExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('انتهت الجلسة'),
        content: const Text(
          'انتهت صلاحية الجلسة الحالية. يرجى تسجيل الدخول مرة أخرى للمتابعة.'
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: const Text('تسجيل الدخول'),
          ),
        ],
      ),
    );
  }

  // =================================================
  // LOGOUT
  // =================================================
  static Future<void> logout({
    required String token,
    required BuildContext context,
  }) async {
    try {
      await _post("logout.php",
          headers: {"X-Auth-Token": token, "Accept": "application/json"});
      debugPrint("✅ Logout request sent successfully");
    } catch (e) {
      debugPrint("⚠️ Logout request failed: $e");
    }

    // مسح التوكن من TokenStore أولاً
    await TokenStore.clear();

    // مسح كل SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    debugPrint("✅ All SharedPreferences cleared");

    // إظهار رسالة للمستخدم
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تسجيل الخروج بنجاح، جاري إعادة التشغيل...'),
          duration: Duration(seconds: 1),
        ),
      );

      await Future.delayed(const Duration(seconds: 1));

      // إعادة تشغيل التطبيق تلقائيًا
      Restart.restartApp();
    }
  }

  // =================================================
  // MARK ALL NOTIFICATIONS READ
  // =================================================
  static Future<Map<String, dynamic>> markAllNotificationsRead(String token) async {
    try {
      final response = await _post("mark-all-notifications-read.php",
          headers: {"X-Auth-Token": token, "Accept": "application/json"});

      if (response.statusCode != 200) {
        return {
          'ok': false,
          'error': 'http_${response.statusCode}',
          'message': response.body,
        };
      }

      try {
        return json.decode(response.body);
      } catch (e) {
        return {
          'ok': false,
          'error': 'invalid_response',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'error': 'connection_failed',
        'message': e.toString(),
      };
    }
  }

  // =================================================
  // MARK NOTIFICATION UNREAD
  // =================================================
  static Future<Map<String, dynamic>> markNotificationUnread({
    required String token,
    required int notificationId,
  }) async {
    try {
      final response = await _post("mark-notification-unread.php",
          headers: {
            "X-Auth-Token": token,
            "Content-Type": "application/json",
            "Accept": "application/json"
          },
          body: json.encode({"id": notificationId}));

      if (response.statusCode != 200) {
        return {
          'ok': false,
          'error': 'http_${response.statusCode}',
          'message': response.body,
        };
      }

      try {
        return json.decode(response.body);
      } catch (e) {
        return {
          'ok': false,
          'error': 'invalid_response',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'error': 'connection_failed',
        'message': e.toString(),
      };
    }
  }

  // =================================================
  // MARK NOTIFICATION READ
  // =================================================
  static Future<Map<String, dynamic>> markNotificationRead({
    required String token,
    required int notificationId,
  }) async {
    try {
      final response = await _post("mark-notification-read.php",
          headers: {
            "X-Auth-Token": token,
            "Content-Type": "application/json",
            "Accept": "application/json"
          },
          body: json.encode({"id": notificationId}));

      if (response.statusCode != 200) {
        return {
          'ok': false,
          'error': 'http_${response.statusCode}',
          'message': response.body,
        };
      }

      try {
        return json.decode(response.body);
      } catch (e) {
        return {
          'ok': false,
          'error': 'invalid_response',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'error': 'connection_failed',
        'message': e.toString(),
      };
    }
  }

  // =================================================
  // GET MY TICKETS
  // =================================================
  static Future<Map<String, dynamic>> getMyTickets(String token) async {
    try {
      final result = await _get("my_tickets.php",
          headers: {"X-Auth-Token": token, "Accept": "application/json"});
      return result;
    } catch (e) {
      return {"ok": false, "error": "exception", "message": e.toString()};
    }
  }

  // =================================================
  // DELETE NOTIFICATION
  // =================================================
  static Future<Map<String, dynamic>> deleteNotification({
    required String token,
    required int notificationId,
  }) async {
    try {
      final response = await _post("delete-notification.php",
          headers: {
            "X-Auth-Token": token,
            "Content-Type": "application/json",
            "Accept": "application/json"
          },
          body: json.encode({"id": notificationId}));

      if (response.statusCode != 200) {
        return {
          'ok': false,
          'error': 'http_${response.statusCode}',
          'message': response.body,
        };
      }

      try {
        return json.decode(response.body);
      } catch (e) {
        return {
          'ok': false,
          'error': 'invalid_response',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'error': 'connection_failed',
        'message': e.toString(),
      };
    }
  }

  // =================================================
  // ADD DAYS (RENEW)
  // =================================================
  static Future<Map<String, dynamic>> addDays({
    required String token,
    required String days,
    String notes = '',
  }) async {
    try {
      final response = await _post("add-days.php",
          headers: {"X-Auth-Token": token, "Accept": "application/json"},
          body: {"api": "1", "day_num": days, "notes": notes});

      if (response.statusCode != 200) {
        return {
          'ok': false,
          'error': 'http_${response.statusCode}',
          'message': response.body,
        };
      }

      try {
        return json.decode(response.body);
      } catch (e) {
        return {
          'ok': false,
          'error': 'invalid_response',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'error': 'connection_failed',
        'message': e.toString(),
      };
    }
  }

  // =================================================
  // REPLY TO TICKET
  // =================================================
  static Future<Map<String, dynamic>> replyToTicket({
    required String token,
    required int ticketId,
    required String reply,
  }) async {
    try {
      final response = await _post(
        "reply-ticket",
        headers: {
          "X-Auth-Token": token,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: json.encode({
          "ticket_id": ticketId,
          "reply": reply,
        }),
      );

      if (response.statusCode != 200) {
        return {
          'ok': false,
          'error': 'http_${response.statusCode}',
          'message': response.body,
        };
      }

      try {
        return json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return {
          "ok": false,
          "error": "invalid_response",
          "message": response.body,
        };
      }
    } catch (e) {
      return {
        "ok": false,
        "error": "connection_failed",
        "message": e.toString(),
      };
    }
  }

  // =================================================
  // CHECK SESSIONS - دالة للتحقق من الجلسات
  // =================================================
  static Future<Map<String, dynamic>> checkSessions(String token) async {
    try {
      return await _get("check_sessions.php",
          headers: {"X-Auth-Token": token, "Accept": "application/json"});
    } catch (e) {
      return {'ok': false, 'error': 'connection_failed'};
    }
  }

  // =================================================
  // GET DEVICE INFO - جلب معلومات الجهاز الحالي
  // =================================================
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceId = await getDeviceId();
    final token = await TokenStore.load();
    
    return {
      'device_id': deviceId,
      'has_token': token != null,
      'token_exists': token != null,
    };
  }
}