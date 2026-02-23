import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_store.dart';
import 'main_navigation.dart';

class CreateAccountScreen extends StatefulWidget {
  final String username;
  final String fullName;

  const CreateAccountScreen({
    Key? key,
    required this.username,
    required this.fullName,
  }) : super(key: key);

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool loading = false;
  String? error;

  Future<void> createAccount() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      setState(() => error = "يرجى إدخال كلمة السر وتأكيدها");
      return;
    }

    if (password.length < 4) {
      setState(() => error = "كلمة السر قصيرة جداً");
      return;
    }

    if (password != confirm) {
      setState(() => error = "كلمتا السر غير متطابقتين");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await ApiService.createAccount(
        username: widget.username,
        password: password,
      );

      if (res['ok'] != true) {
        setState(() {
          error = res['error'] ?? 'فشل إنشاء الحساب';
        });
        return;
      }

      // ✅ Popup تحذير قبل الدخول
   await showDialog(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => AlertDialog(
    title: const Text("تم إنشاء الحساب"),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("اسم المستخدم: ${widget.username}"),
        const SizedBox(height: 8),
        const Text(
          "يرجى حفظ كلمة السر وعدم نسيانها.\nفي حال نسيانها يرجى التواصل مع الدعم الفني.",
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(), // ✅ هذا هو المفتاح
        child: const Text("متابعة"),
      ),
    ],
  ),
);


      // =============================
      // تسجيل دخول تلقائي
      // =============================
      final login = await ApiService.login(
        username: widget.username,
        password: password,
      );

      if (login["ok"] == true) {
        final token = login["token"].toString();
        await TokenStore.save(token);

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigation(token: token),
          ),
          (_) => false,
        );
      } else {
        setState(() {
          error = "تم إنشاء الحساب لكن فشل تسجيل الدخول";
        });
      }
    } catch (e) {
      setState(() => error = "فشل الاتصال بالسيرفر");
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text("إنشاء حساب")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "اهلا بك ${widget.fullName}\nهذا أول دخول للتطبيق — الرجاء إنشاء كلمة مرور",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text("اسم المستخدم: ${widget.username}"),
              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "كلمة المرور"),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: "تأكيد كلمة المرور"),
              ),

              const SizedBox(height: 20),

              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : createAccount,
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("إنشاء الحساب"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
