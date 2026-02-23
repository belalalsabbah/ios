import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ إضافة هذا الاستيراد
import '../services/app_update_service.dart';
import '../services/api_service.dart';
import '../services/token_store.dart';
import 'main_navigation.dart';
import 'login_screen.dart';
import 'create_account_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? error;
  bool _booting = true;
  bool isInsideNetwork = false;
  
  // متغيرات إعادة المحاولة
  int _retryCount = 0;
  final int _maxRetries = 3;
  Timer? _retryTimer;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // فحص التحديث في الخلفية (مرة واحدة فقط)
      AppUpdateService.autoCheck(context);
      // بدء عملية التشغيل مع إعادة المحاولة
      _startBootProcess();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  // =========================
  // 🔄 بدء عملية التشغيل مع إعادة المحاولة
  // =========================
  Future<void> _startBootProcess() async {
    setState(() {
      _booting = true;
      error = null;
      _retryCount = 0;
      _isRetrying = false;
    });
    
    await _bootWithRetry();
  }

  // =========================
  // 🔄 إعادة المحاولة التلقائية
  // =========================
  Future<void> _bootWithRetry() async {
    while (_retryCount < _maxRetries) {
      try {
        await _boot();
        return; // نجاح → نخرج من الحلقة
        
      } on TimeoutException catch (e) {
        _retryCount++;
        
        if (_retryCount >= _maxRetries) {
          if (mounted) {
            setState(() {
              _isRetrying = false;
              error = "⚠️ السيرفر غير متاح حالياً بعد $_maxRetries محاولات.\n"
                      "يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.";
              _booting = false;
            });
          }
          return;
        }
        
        // إظهار رسالة إعادة المحاولة للمستخدم
        if (mounted) {
          setState(() {
            _isRetrying = true;
            error = "⚠️ جاري إعادة المحاولة... ($_retryCount/$_maxRetries)";
          });
        }
        
        // انتظار قبل إعادة المحاولة (زيادة الوقت مع كل محاولة)
        await Future.delayed(Duration(seconds: _retryCount * 2));
        
      } catch (e) {
        if (mounted) {
          setState(() {
            _isRetrying = false;
            error = "❌ فشل الاتصال بالسيرفر\n${e.toString()}";
            _booting = false;
          });
        }
        return;
      }
    }
  }

  // =========================
  // 🔍 فحص الإنترنت
  // =========================
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // =========================
  // 🔍 فحص الشبكة الداخلية
  // =========================
  Future<bool> _detectNetwork() async {
    try {
      final socket = await Socket.connect('50.50.50.1', 80, 
          timeout: const Duration(seconds: 2));
      socket.destroy();
      return true; // داخل الشبكة
    } catch (_) {
      return false; // خارج الشبكة
    }
  }

  // =========================
  // 🚀 تشغيل التطبيق (الكود الأساسي)
  // =========================
  Future<void> _boot() async {
    // التحقق من mounted قبل كل تحديث للحالة
    if (!mounted) return;

    setState(() {
      _booting = true;
      error = null;
    });

    // 1️⃣ فحص الإنترنت
    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      throw TimeoutException("لا يوجد اتصال بالإنترنت");
    }

    // 2️⃣ فحص الشبكة الداخلية
    isInsideNetwork = await _detectNetwork();
    if (isInsideNetwork) {
      ApiService.baseUrl = "http://50.50.50.1/api";
    } else {
      ApiService.baseUrl = "http://213.6.142.189:45678/api";
    }

    // 3️⃣ التحقق من وجود توكن محفوظ
    final savedToken = await TokenStore.load();
    if (savedToken != null && savedToken.isNotEmpty) {
      if (mounted) {
        _navigateToMain(savedToken);
      }
      return;
    }

    // 4️⃣ إذا داخل الشبكة → نتحقق إذا لديه حساب مسبقاً
    if (isInsideNetwork) {
      final res = await ApiService.getStatusAnonymous()
          .timeout(const Duration(seconds: 4));

      if (!mounted) return;

      if (res["ok"] != true) {
        throw Exception(res["message"] ?? "⚠️ فشل الاتصال بالسيرفر الداخلي");
      }

      if (res["has_account"] == true) {
        // مستخدم لديه حساب → نذهب لتسجيل الدخول
        _goLogin();
      } else {
        // أول مرة داخل الشبكة → إنشاء حساب
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateAccountScreen(
              username: res["username"],
              fullName: res["name"] ?? res["username"],
            ),
          ),
        );

        if (!mounted) return;

        if (result != null && result is Map) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                prefillUsername: result["username"],
                prefillPassword: result["password"],
              ),
            ),
          );
        }
      }
    } else {
      // 5️⃣ خارج الشبكة → نذهب مباشرة لشاشة تسجيل الدخول
      _goLogin();
    }

    if (mounted) {
      setState(() {
        _booting = false;
      });
    }
  }

  // =========================
  // تحديث الخطأ
  // =========================
  void _setError(String msg) {
    if (mounted) {
      setState(() {
        error = msg;
        _booting = false;
        _isRetrying = false;
      });
    }
  }

  // =========================
  // التنقل للشاشات
  // =========================
  void _navigateToMain(String token) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainNavigation(token: token)),
    );
  }

  void _goLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // =========================
  // إعادة المحاولة اليدوية
  // =========================
  Future<void> _manualRetry() async {
    setState(() {
      _retryCount = 0;
      _isRetrying = false;
    });
    await _startBootProcess();
  }

  // =========================
  // 🖥️ واجهة المستخدم - نسخة محسنة مع أيقونة التطبيق
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade600,
              Colors.blue.shade400,
            ],
          ),
        ),
        child: Center(
          child: _booting
              ? _buildLoadingUI()
              : error != null
                  ? _buildErrorUI()
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }

  // =========================
  // واجهة التحميل مع أيقونة التطبيق
  // =========================
  Widget _buildLoadingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ✅ أيقونة التطبيق (بدلاً من النص)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipOval(
            // استبدال سطر Image.asset بهذا:
child: Image.asset(
  'assets/icon/2Neticon.png',
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    // إذا لم يتم العثور على الصورة، نعرض أيقونة افتراضية
    return Container(
      color: Colors.white,
      child: Icon(
        Icons.wifi,  // أو أي أيقونة أخرى
        size: 70,
        color: Colors.blue.shade700,
      ),
    );
  },
),
            ),
          ),
        ),
        
        const SizedBox(height: 40),
        
        // ✅ دائرة تحميل متحركة
        SizedBox(
          width: 60,
          height: 60,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            curve: Curves.linear,
            builder: (context, value, child) {
              return CircularProgressIndicator(
                value: null, // مؤشر غير محدد (indeterminate)
                strokeWidth: 4,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.lerp(
                    Colors.white,
                    Colors.yellow,
                    (value * 2) % 1.0,
                  )!,
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 24),
        
        // ✅ نص الحالة مع تأثير الظهور
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          builder: (context, opacity, child) {
            return Opacity(
              opacity: opacity,
              child: child,
            );
          },
          child: Column(
            children: [
              Text(
                _isRetrying 
                    ? "⚠️ جاري إعادة المحاولة... ($_retryCount/$_maxRetries)"
                    : "2Net",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRetrying 
                    ? "نواجه بعض المشاكل في الاتصال"
                    : "جاري التحميل...",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================
  // واجهة الخطأ (محسنة مع أيقونة)
  // =========================
  Widget _buildErrorUI() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ✅ أيقونة الخطأ مع حركة اهتزاز
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.error_outline,
                size: 70,
                color: Colors.red.shade700,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // ✅ نص الخطأ
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // ✅ أزرار الإجراءات
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // زر إعادة المحاولة
              ElevatedButton.icon(
                onPressed: _manualRetry,
                icon: const Icon(Icons.refresh),
                label: const Text("إعادة المحاولة"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade800,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // زر الدعم الفني
              OutlinedButton.icon(
                onPressed: _openSupportWhatsApp, // ✅ استخدام الدالة المصححة
                icon: const Icon(Icons.support_agent),
                label: const Text("الدعم الفني"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // ✅ نص مساعد صغير
          Text(
            "إذا استمرت المشكلة، تواصل مع الدعم الفني",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // ✅ فتح واتساب الدعم الفني (نسخة مصححة)
  // =========================
  Future<void> _openSupportWhatsApp() async {
    final Uri whatsappUri = Uri.parse(
      "https://wa.me/972569139191?text=مرحباً، أواجه مشكلة في فتح التطبيق"
    );
    
    try {
      // ✅ استخدام الدوال الصحيحة من حزمة url_launcher
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        // إذا فشل الفتح، أظهر رسالة خطأ
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ لا يمكن فتح واتساب، تأكد من تثبيت التطبيق"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ حدث خطأ: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}