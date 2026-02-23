import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _key = "auth_token";

  static Future<void> save(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, token);
  }

  static Future<String?> load() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
