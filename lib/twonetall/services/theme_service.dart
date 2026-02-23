import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _key = "dark_mode";
  bool _dark = false;

  bool get isDark => _dark;

  ThemeService() {
    _load();
  }

  void toggle() async {
    _dark = !_dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_key, _dark);
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    _dark = prefs.getBool(_key) ?? false;
    notifyListeners();
  }
}
