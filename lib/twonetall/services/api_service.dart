import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://50.50.50.1/api";

  // -------------------------------
  // AUTO LOGIN
  // -------------------------------
  static Future<Map<String, dynamic>> autoLogin() async {
    final res = await http.get(
      Uri.parse("$baseUrl/auto-login"),
      headers: {
        "Accept": "application/json",
      },
    );
    return json.decode(res.body);
  }

  // -------------------------------
  // SUBSCRIPTION STATUS
  // -------------------------------
  static Future<Map<String, dynamic>> getStatus(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/subscription/status"),
      headers: {
        "X-Auth-Token": token,
        "Accept": "application/json",
      },
    );
    return json.decode(res.body);
  }

  // -------------------------------
  // NOTIFICATIONS
  // -------------------------------
  static Future<Map<String, dynamic>> getNotifications(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/notifications"),
      headers: {
        "X-Auth-Token": token,
        "Accept": "application/json",
      },
    );
    return json.decode(res.body);
  }

  // -------------------------------
  // CREATE TICKET
  // -------------------------------
  static Future<Map<String, dynamic>> createTicket({
    required String token,
    required String type,
    required String message,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/tickets/create"),
      headers: {
        "X-Auth-Token": token,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: json.encode({
        "type": type,
        "message": message,
      }),
    );

    return json.decode(res.body);
  }

  // -------------------------------
  // SAVE FCM TOKEN 🔥 (النسخة الصحيحة)
  // -------------------------------
  static Future<void> saveFcmToken({
    required String token,
    required String fcmToken,
  }) async {
    await http.post(
      Uri.parse("$baseUrl/register_fcm.php"),
      headers: {
        "X-Auth-Token": token,
        // ❌ لا Content-Type JSON
      },
      body: {
        "fcm_token": fcmToken,
        "device": "android",
      },
    );
  }
}
