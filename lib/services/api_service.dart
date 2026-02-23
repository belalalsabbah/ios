import 'dart:convert';
import 'package:restart_app/restart_app.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/splash_screen.dart';
import 'token_store.dart';

class ApiService {
  static String baseUrl = "http://50.50.50.1/api"; // سيتم تحديثها تلقائيًا

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
  static Future<http.Response> _get(String path,
      {Map<String, String>? headers}) async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/$path"), headers: headers)
          .timeout(const Duration(seconds: 5));
      return res;
    } catch (_) {
      await detectBaseUrl();
      return await http
          .get(Uri.parse("$baseUrl/$path"), headers: headers)
          .timeout(const Duration(seconds: 5));
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
  // BOOTSTRAP (SplashScreen)
  // =================================================
  static Future<Map<String, dynamic>> bootstrap({String? token}) async {
    final headers = <String, String>{"Accept": "application/json"};
    if (token != null && token.isNotEmpty) headers["X-Auth-Token"] = token;

    final res = await _get("app/bootstrap", headers: headers);
    if (res.statusCode != 200)
      throw Exception("BOOTSTRAP HTTP ${res.statusCode}: ${res.body}");
    return json.decode(res.body);
  }

  // =================================================
  // STATUS (بدون تسجيل دخول – داخل الشبكة فقط)
  // =================================================
  static Future<Map<String, dynamic>> getStatusAnonymous() async {
    final res = await _get("status", headers: {"Accept": "application/json"});
    if (res.statusCode != 200)
      throw Exception("STATUS HTTP ${res.statusCode}: ${res.body}");
    return json.decode(res.body);
  }

  // =================================================
  // STATUS (بعد تسجيل الدخول)
  // =================================================
  static Future<Map<String, dynamic>> getStatus(String token) async {
    final res = await _get("status.php",
        headers: {"X-Auth-Token": token, "Accept": "application/json"});
    if (res.statusCode != 200)
      throw Exception("STATUS AUTH HTTP ${res.statusCode}: ${res.body}");
    return json.decode(res.body);
  }

  // =================================================
  // LOGIN
  // =================================================
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await _post(
      "login",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: json.encode({
        "username": username,
        "password": password,
      }),
    );

    try {
      return json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        "ok": false,
        "error": "invalid_response",
        "message": res.body,
      };
    }
  }

  // =================================================
  // CREATE ACCOUNT
  // =================================================
  static Future<Map<String, dynamic>> createAccount(
      {required String username, required String password}) async {
    final res = await _post("create-account",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: json.encode({"username": username, "password": password}));
    if (res.statusCode != 200)
      throw Exception("CREATE ACCOUNT HTTP ${res.statusCode}: ${res.body}");
    return json.decode(res.body);
  }

  // =================================================
  // GET NOTIFICATIONS
  // =================================================
  static Future<Map<String, dynamic>> getNotifications(String token) async {
    final res = await _get("notifications.php",
        headers: {"X-Auth-Token": token, "Accept": "application/json"});
    if (res.statusCode != 200)
      throw Exception("NOTIFICATIONS HTTP ${res.statusCode}: ${res.body}");
    return json.decode(res.body);
  }

  // =================================================
  // CREATE TICKET
  // =================================================
  static Future<Map<String, dynamic>> createTicket(
      {required String token,
      required String type,
      required String message}) async {
    final res = await _post("tickets/create",
        headers: {
          "X-Auth-Token": token,
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: json.encode({"type": type, "message": message}));
    if (res.statusCode != 200)
      throw Exception("CREATE TICKET HTTP ${res.statusCode}: ${res.body}");
    return json.decode(res.body);
  }

  // في api_service.dart، استبدل دالة saveFcmToken بهذا:

static Future<void> saveFcmToken({
  required String token,
  required String fcmToken,
}) async {
  try {
    // الطريقة 1: استخدام x-www-form-urlencoded
    final url = Uri.parse('$baseUrl/register_fcm.php');
    
    // إنشاء طلب MultipartRequest
    var request = http.MultipartRequest('POST', url);
    request.headers['X-Auth-Token'] = token;
    request.fields['fcm_token'] = fcmToken;
    request.fields['device'] = 'android';
    
    print('📤 إرسال FCM token إلى: $url');
    print('🔑 Token: $token');
    print('📱 FCM: $fcmToken');
    
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    print('📥 استجابة: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode != 200) {
      // إذا فشل، جرب الطريقة الثانية (application/json)
      print('⚠️ فشل MultipartRequest، جرب JSON...');
      
      final jsonResponse = await http.post(
        url,
        headers: {
          'X-Auth-Token': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fcm_token': fcmToken,
          'device': 'android',
        }),
      );
      
      print('📥 JSON استجابة: ${jsonResponse.statusCode} - ${jsonResponse.body}');
      
      if (jsonResponse.statusCode != 200) {
        throw Exception('فشل جميع محاولات إرسال FCM token');
      }
    }
  } catch (e) {
    print('❌ خطأ في saveFcmToken: $e');
    throw Exception('فشل حفظ FCM token: $e');
  }
}

  // =================================================
  // LOGOUT - إعادة تشغيل التطبيق
  // =================================================
  static Future<void> logout({
    required String token,
    required BuildContext context,
  }) async {
    try {
      await _post("logout.php",
          headers: {"X-Auth-Token": token, "Accept": "application/json"});
      print("✅ Logout request sent successfully");
    } catch (e) {
      print("⚠️ Logout request failed: $e");
    }

    // مسح التوكن من TokenStore أولاً
    await TokenStore.clear();

    // مسح كل SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    print("✅ All SharedPreferences cleared");

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
  static Future<Map<String, dynamic>> markAllNotificationsRead(
      String token) async {
    final res = await _post("mark-all-notifications-read.php",
        headers: {"X-Auth-Token": token, "Accept": "application/json"});
    if (res.statusCode != 200)
      throw Exception("MARK ALL READ HTTP ${res.statusCode}");
    return json.decode(res.body);
  }

  // =================================================
  // MARK NOTIFICATION UNREAD
  // =================================================
  static Future<void> markNotificationUnread(
      {required String token, required int notificationId}) async {
    final res = await _post("mark-notification-unread.php",
        headers: {"X-Auth-Token": token, "Content-Type": "application/json"},
        body: json.encode({"id": notificationId}));
    if (res.statusCode != 200)
      throw Exception("MARK UNREAD HTTP ${res.statusCode}");
  }

  // =================================================
  // MARK NOTIFICATION READ
  // =================================================
  static Future<void> markNotificationRead(
      {required String token, required int notificationId}) async {
    final res = await _post("mark-notification-read.php",
        headers: {
          "X-Auth-Token": token,
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: json.encode({"id": notificationId}));
    if (res.statusCode != 200)
      throw Exception("MARK READ HTTP ${res.statusCode}");
  }

  // =================================================
  // GET MY TICKETS
  // =================================================
  static Future<Map<String, dynamic>> getMyTickets(String token) async {
    try {
      final res = await _get("my_tickets.php",
          headers: {"X-Auth-Token": token, "Accept": "application/json"});
      final body = res.body.trim();
      if (!body.startsWith("{"))
        return {"ok": false, "error": "invalid_response", "raw": body};
      return jsonDecode(body);
    } catch (e) {
      return {"ok": false, "error": "exception", "message": e.toString()};
    }
  }

  // =================================================
  // DELETE NOTIFICATION
  // =================================================
  static Future<Map<String, dynamic>> deleteNotification(
      {required String token, required int notificationId}) async {
    final res = await _post("delete-notification.php",
        headers: {
          "X-Auth-Token": token,
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: json.encode({"id": notificationId}));
    if (res.statusCode != 200)
      throw Exception("DELETE NOTIFICATION HTTP ${res.statusCode}");
    return json.decode(res.body);
  }

  // =================================================
  // ADD DAYS (RENEW)
  // =================================================
  static Future<Map<String, dynamic>> addDays(
      {required String token,
      required String days,
      String notes = ''}) async {
    final res = await _post("add-days.php",
        headers: {"X-Auth-Token": token, "Accept": "application/json"},
        body: {"api": "1", "day_num": days, "notes": notes});
    if (res.statusCode != 200)
      throw Exception("ADD DAYS HTTP ${res.statusCode}: ${res.body}");
    return json.decode(res.body);
  }

  // =================================================
  // REPLY TO TICKET - دالة جديدة
  // =================================================
  static Future<Map<String, dynamic>> replyToTicket({
    required String token,
    required int ticketId,
    required String reply,
  }) async {
    try {
      final res = await _post(
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

      try {
        return json.decode(res.body) as Map<String, dynamic>;
      } catch (e) {
        return {
          "ok": false,
          "error": "invalid_response",
          "message": res.body,
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
}