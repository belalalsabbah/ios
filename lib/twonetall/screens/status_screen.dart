import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/token_store.dart';
import '../services/push_service.dart';
import '../services/app_update_service.dart';
import '../services/notification_service.dart';

import 'splash_screen.dart';
import 'notifications_screen.dart';
import 'ticket_screen.dart';

/// ================== Subscription Helpers ==================

Color statusColorByDays(int days) {
  if (days <= 0) return Colors.red;
  if (days <= 10) return Colors.orange;
  if (days <= 20) return Colors.yellow.shade700;
  return Colors.green;
}

Gradient statusGradientByDays(int days) {
  if (days <= 0) {
    return const LinearGradient(
      colors: [Colors.red, Colors.redAccent],
    );
  } else if (days <= 10) {
    return const LinearGradient(
      colors: [Colors.orange, Colors.deepOrange],
    );
  } else if (days <= 20) {
    return const LinearGradient(
      colors: [Colors.yellow, Colors.orangeAccent],
    );
  } else {
    return const LinearGradient(
      colors: [Colors.green, Colors.teal],
    );
  }
}

IconData statusIconByDays(int days) {
  if (days <= 0) return Icons.cancel;
  if (days <= 10) return Icons.warning;
  return Icons.check_circle;
}

String statusTextByDays(int days) {
  if (days <= 0) return "منتهي";
  if (days <= 10) return "قارب على الانتهاء";
  return "فعال";
}

double progressValueByDays(int days) {
  const totalDays = 30;
  return (days / totalDays).clamp(0.0, 1.0);
}

/// ===========================================================

class StatusScreen extends StatefulWidget {
  final String token;
  const StatusScreen({super.key, required this.token});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  int notificationsCount = 0;
  bool renewSending = false;

  @override
  void initState() {
    super.initState();
    load();
    loadNotificationsCount();
    PushService.init(widget.token);
  }

  /// ===== Load Status =====
  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await ApiService.getStatus(widget.token);
      if (res["ok"] == true) {
        setState(() {
          data = res;
          loading = false;
        });
      } else {
        setState(() {
          error = res["error"]?.toString();
          loading = false;
        });
      }
    } catch (_) {
      setState(() {
        error = "فشل الاتصال بالسيرفر";
        loading = false;
      });
    }
  }

  /// ===== Notifications Count =====
  Future<void> loadNotificationsCount() async {
    try {
      final count =
          await NotificationService.getUnreadCount(widget.token);
      setState(() => notificationsCount = count);
    } catch (_) {}
  }

  /// ===== Logout =====
  Future<void> logout() async {
    await TokenStore.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) =>  SplashScreen()),
      (_) => false,
    );
  }

  /// ===== WhatsApp Support =====
  void openSupportWhatsapp() async {
    final uri = Uri.parse(
      "https://wa.me/972569139191?text=مرحبا، أنا ${data?["name"] ?? ""} وأحتاج دعم",
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// ===== Renew Request =====
  Future<void> requestRenew() async {
    if (renewSending) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تأكيد التجديد"),
        content: const Text(
          "سيتم إرسال طلب تجديد الاشتراك إلى الإدارة.\nهل تريد المتابعة؟",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => renewSending = true);

    final res = await ApiService.createTicket(
      token: widget.token,
      type: "renew",
      message: "طلب تجديد اشتراك من التطبيق",
    );

    if (!mounted) return;

    setState(() => renewSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res["ok"] == true
              ? "✅ تم إرسال طلب التجديد"
              : "❌ فشل إرسال الطلب",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = data?["days_left"] ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("2Net – لوحة التحكم"),
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () async {
                    final opened = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            NotificationsScreen(token: widget.token),
                      ),
                    );
                    if (opened == true) {
                      loadNotificationsCount();
                    }
                  },
                ),
                if (notificationsCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      builder: (_, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: statusGradientByDays(daysLeft),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          notificationsCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: load),
            IconButton(icon: const Icon(Icons.logout), onPressed: logout),
          ],
        ),

        /// ================= BODY =================
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        /// ===== User Card =====
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(
                              data!["name"],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "الحالة: ${statusTextByDays(daysLeft)}",
                            ),
                            trailing: Icon(
                              statusIconByDays(daysLeft),
                              color: statusColorByDays(daysLeft),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// ===== Subscription Card =====
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "تفاصيل الاشتراك",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text("📅 الانتهاء: ${data!["expiration"]}"),
                                Text("⏳ الأيام المتبقية: $daysLeft"),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: progressValueByDays(daysLeft),
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: AlwaysStoppedAnimation(
                                    statusColorByDays(daysLeft),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// ===== Grid Menu =====
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          children: [
                            _gridButton(
                              icon: Icons.system_update,
                              label: "تحديث التطبيق",
                              onTap: () =>
                                  AppUpdateService.manualCheck(context),
                            ),
                            _gridButton(
                              icon: Icons.payment,
                              label: "طلب تجديد",
                              loading: renewSending,
                              onTap: requestRenew,
                            ),
                            _gridButton(
                              icon: Icons.support_agent,
                              label: "تذكرة دعم",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TicketScreen(
                                      token: widget.token,
                                      type: 'support',
                                    ),
                                  ),
                                );
                              },
                            ),
                            _gridButton(
                              icon: Icons.message,
                              label: "واتساب",
                              onTap: openSupportWhatsapp,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  /// ===== Grid Button =====
  Widget _gridButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 36),
                    const SizedBox(height: 8),
                    Text(label),
                  ],
                ),
        ),
      ),
    );
  }
}
