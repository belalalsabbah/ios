import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class PushService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// تهيئة الإشعارات + إرسال FCM Token للسيرفر
  static Future<void> init(String token) async {
    try {
      // 1️⃣ طلب الإذن (Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print("🔔 Notification permission: ${settings.authorizationStatus}");

      // في حال الرفض
      if (settings.authorizationStatus ==
          AuthorizationStatus.denied) {
        print("❌ Notification permission denied");
        return;
      }

      // 2️⃣ الحصول على FCM Token
      final String? fcmToken = await _fcm.getToken();
      print("🔥 FCM TOKEN = $fcmToken");

      if (fcmToken == null || fcmToken.isEmpty) {
        print("❌ FCM token is null or empty");
        return;
      }

      // 3️⃣ إرسال التوكن إلى السيرفر
      await ApiService.saveFcmToken(
        token: token,
        fcmToken: fcmToken,
      );

      print("✅ FCM token sent to server");

      // 4️⃣ الاستماع لتغيّر التوكن (مهم جدًا)
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (String newToken) async {
          print("♻️ FCM token refreshed = $newToken");

          if (newToken.isEmpty) return;

          await ApiService.saveFcmToken(
            token: token,
            fcmToken: newToken,
          );

          print("✅ New FCM token updated on server");
        },
        onError: (e) {
          print("❌ Token refresh error: $e");
        },
      );
    } catch (e) {
      print("❌ PushService init error: $e");
    }
  }
}
