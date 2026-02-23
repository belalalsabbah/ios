import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_update_service.dart';
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
                // ✅ إظهار نافذة تأكيد
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('تأكيد تسجيل الخروج'),
                    content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('تسجيل خروج'),
                      ),
                    ],
                  ),
                );

                // ✅ إذا أكد المستخدم، سجل خروج
                if (confirm == true) {
                  await ApiService.logout(
                    token: token,
                    context: context,
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