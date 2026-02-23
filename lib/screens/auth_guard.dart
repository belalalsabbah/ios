import 'package:flutter/material.dart';
import 'splash_screen.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? token; // تمرير التوكن مباشرة

  const AuthGuard({super.key, required this.child, this.token});

  @override
  Widget build(BuildContext context) {
    if (token == null || token!.isEmpty) {
      // لو ما فيه توكن، اذهب مباشرة إلى SplashScreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
        );
      });
      return const SizedBox(); // placeholder أثناء الانتقال
    }

    // لو فيه توكن، عرض الشاشة مباشرة
    return child;
  }
}
