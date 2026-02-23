import 'main_navigation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_store.dart';
import 'inside_network_screen.dart';
import 'status_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? error;

  @override
  void initState() {
    super.initState();
    boot();
  }

  Future<void> boot() async {
    try {
      // 1) محاولة تحميل token محفوظ
      final saved = await TokenStore.load();

      if (saved != null && saved.isNotEmpty) {
        final ok = await _tryStatus(saved);
        if (ok) return;

        // token غير صالح → امسحه
        await TokenStore.clear();
      }

      // 2) لا يوجد token → جرّب auto-login (من داخل الشبكة)
      await _tryAutoLogin();
    } catch (e) {
      setState(() {
        error = "خطأ غير متوقع: $e";
      });
    }
  }

  Future<bool> _tryStatus(String token) async {
    try {
      final res = await ApiService.getStatus(token);

      if (res["ok"] == true) {
        _goStatus(token);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _tryAutoLogin() async {
    try {
      final res = await ApiService.autoLogin();

      if (res["ok"] == true) {
        final token = res["token"]?.toString() ?? "";

        if (token.isEmpty) {
          setState(() {
            error = "Token غير صالح من السيرفر";
          });
          return;
        }

        await TokenStore.save(token);
        _goStatus(token);
      } else {
        final msg = (res["message"] ??
                "أول تفعيل لازم يتم من داخل شبكة 2Net")
            .toString();
        _goInsideNetwork(msg);
      }
    } catch (e) {
      setState(() {
        error = "فشل الاتصال بالسيرفر: $e";
      });
    }
  }

  void _goStatus(String token) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigation(token: token)
,
      ),
    );
  }

  void _goInsideNetwork(String msg) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InsideNetworkScreen(message: msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: error == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text("2Net... جاري التحقق"),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
      ),
    );
  }
}
