// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/token_store.dart';
import '../services/push_service.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  final String? prefillUsername;
  final String? prefillPassword;

  const LoginScreen({
    Key? key,
    this.prefillUsername,
    this.prefillPassword,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();

    if (widget.prefillUsername != null) {
      userCtrl.text = widget.prefillUsername!;
    }
    if (widget.prefillPassword != null) {
      passCtrl.text = widget.prefillPassword!;
    }
  }

  Future<void> login() async {
    if (userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
      setState(() => error = "يرجى إدخال اسم المستخدم وكلمة السر");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await ApiService.login(
        username: userCtrl.text.trim(),
        password: passCtrl.text,
      );

      if (res["ok"] == true) {
        final token = res["token"].toString();
        final username = userCtrl.text.trim();

        await TokenStore.save(token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);

        try {
          await PushService.refreshAllDevices(token);
        } catch (e) {
          debugPrint("⚠️ فشل تحديث أجهزة المستخدم: $e");
        }

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigation(token: token),
          ),
          (_) => false,
        );
        return;
      }

      // ✅ معالجة الأخطاء بشكل صحيح
      final errorType = res["error"]?.toString() ?? '';
      final errorMessage = res["message"]?.toString() ?? 'حدث خطأ غير متوقع';

      // ✅ رسائل مفهومة للمستخدم
      String userFriendlyMessage;
      
      if (errorType.contains('wrong_password') || 
          errorMessage.contains('wrong_password') ||
          errorMessage.contains('كلمة السر غير صحيحة')) {
        userFriendlyMessage = "❌ كلمة السر غير صحيحة";
      } 
      else if (errorType.contains('no_account') || 
               errorMessage.contains('no_account') ||
               errorMessage.contains('المستخدم غير موجود')) {
        userFriendlyMessage = "❌ اسم المستخدم غير موجود";
      }
      else if (errorType.contains('no_app_account')) {
        userFriendlyMessage = "❌ لا يوجد حساب تطبيق لهذا المستخدم";
      }
      else if (errorType.contains('http_401')) {
        userFriendlyMessage = "❌ اسم المستخدم أو كلمة السر غير صحيحة";
      }
      else {
        // ✅ في حالة أي خطأ آخر، نعرض رسالة مناسبة
        if (errorMessage.contains('wrong') || errorMessage.contains('password')) {
          userFriendlyMessage = "❌ كلمة السر غير صحيحة";
        } else if (errorMessage.contains('user') || errorMessage.contains('account')) {
          userFriendlyMessage = "❌ اسم المستخدم غير موجود";
        } else {
          userFriendlyMessage = "❌ $errorMessage";
        }
      }

      setState(() => error = userFriendlyMessage);

    } catch (e) {
      setState(() => error = "❌ فشل الاتصال بالسيرفر");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("تسجيل الدخول"),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // شعار التطبيق
                Container(
                  margin: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icon/2Neticon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.blue.shade50,
                                child: Icon(
                                  Icons.wifi,
                                  size: 50,
                                  color: Colors.blue.shade700,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "2Net",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Text(
                        "تطبيق المشتركين",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // حقل اسم المستخدم
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: userCtrl,
                    decoration: InputDecoration(
                      labelText: "اسم المستخدم",
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // حقل كلمة السر
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: passCtrl,
                    obscureText: true,
                    onSubmitted: (_) => login(),
                    decoration: InputDecoration(
                      labelText: "كلمة السر",
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ✅ رسالة الخطأ المحسنة
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // زر تسجيل الدخول
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade500],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'جاري تسجيل الدخول...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            "تسجيل الدخول",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                // معلومات المساعدة
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.help_outline, color: Colors.grey.shade600, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'معلومات المساعدة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• إذا لم يكن لديك حساب، قم بتشغيل التطبيق من داخل شبكة 2Net لإنشاء حساب جديد\n'
                        '• في حال نسيان كلمة السر، يرجى التواصل مع الدعم الفني',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}