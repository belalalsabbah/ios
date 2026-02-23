import 'package:flutter/material.dart';
import '../services/app_update_service.dart';
import '../services/token_store.dart';
import 'splash_screen.dart';

class SettingsScreen extends StatelessWidget {
  final String token;
  const SettingsScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الإعدادات")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.system_update),
              title: const Text("فحص تحديث التطبيق"),
              subtitle: const Text("تحميل آخر إصدار من السيرفر"),
              onTap: () {
                AppUpdateService.manualCheck(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "تسجيل الخروج",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await TokenStore.clear();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => SplashScreen()),
                    (_) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
