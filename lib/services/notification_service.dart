import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class NotificationService {
  static Future<int> getUnreadCount(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastStr = prefs.getString("notifications_last_opened");
      final lastOpened =
          lastStr != null ? DateTime.tryParse(lastStr) : null;

      final res = await ApiService.getNotifications(token);
      if (res["ok"] != true) return 0;

      int unread = 0;
      for (final n in res["items"]) {
        final created = DateTime.tryParse(n["created_at"]);
        if (created != null &&
            (lastOpened == null || created.isAfter(lastOpened))) {
          unread++;
        }
      }
      return unread;
    } catch (_) {
      return 0;
    }
  }
}
