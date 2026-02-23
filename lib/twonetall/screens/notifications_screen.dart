import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'notification_details_screen.dart';
import 'main_navigation.dart';
class NotificationsScreen extends StatefulWidget {
  final String token;
  const NotificationsScreen({super.key, required this.token});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List items = [];
  bool loading = true;
  DateTime? lastOpenedAt;

  @override
  void initState() {
    super.initState();
    loadLastOpened();
    load();
  }

  Future<void> loadLastOpened() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString("notifications_last_opened");
    if (ts != null) {
      lastOpenedAt = DateTime.tryParse(ts);
    }
  }

  Future<void> saveLastOpenedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      "notifications_last_opened",
      DateTime.now().toIso8601String(),
    );
  }

  bool isUnread(String createdAt) {
    if (lastOpenedAt == null) return true;
    final created = DateTime.tryParse(createdAt);
    if (created == null) return false;
    return created.isAfter(lastOpenedAt!);
  }

  Future<void> load() async {
    final res = await ApiService.getNotifications(widget.token);
    if (res["ok"] == true) {
      setState(() {
        items = res["items"] ?? [];
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  Color getColor(String type) {
    switch (type) {
      case "expire_soon":
        return Colors.orange;
      case "expired":
        return Colors.red;
      case "renewed":
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  IconData getIcon(String type) {
    switch (type) {
      case "expire_soon":
        return Icons.warning_amber_rounded;
      case "expired":
        return Icons.cancel;
      case "renewed":
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await saveLastOpenedNow();
        Navigator.pop(context, true);
        return false;
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("الإشعارات"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                await saveLastOpenedNow();
                Navigator.pop(context, true);
              },
            ),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const Center(child: Text("لا توجد إشعارات"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final n = items[i];
                        final color = getColor(n["type"]);
                        final unread = isUnread(n["created_at"]);

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NotificationDetailsScreen(
                                  notification: n,
                                ),
                              ),
                            );
                          },
                          child: Card(
                            margin:
                                const EdgeInsets.only(bottom: 12),
                            elevation: unread ? 4 : 1,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: unread
                                    ? color.withOpacity(0.08)
                                    : null,
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color: color, width: 1.2),
                              ),
                              child: Row(
                                children: [
                                  Icon(getIcon(n["type"]),
                                      size: 36, color: color),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              n["title"],
                                              style:
                                                  const TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                            if (unread)
                                              Container(
                                                margin:
                                                    const EdgeInsets
                                                        .only(
                                                        right: 6),
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration:
                                                    BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              6),
                                                ),
                                                child: const Text(
                                                  "جديد",
                                                  style: TextStyle(
                                                      color:
                                                          Colors.white,
                                                      fontSize: 10),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(n["body"]),
                                        const SizedBox(height: 8),
                                        Text(
                                          n["created_at"],
                                          style: TextStyle(
                                            color:
                                                Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
