import 'package:flutter/material.dart';

class NotificationDetailsScreen extends StatelessWidget {
  final Map notification;

  const NotificationDetailsScreen({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("تفاصيل الإشعار"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification["title"],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                notification["body"],
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Divider(),
              const SizedBox(height: 8),
              Text(
                "📅 ${notification["created_at"]}",
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                "🔖 النوع: ${notification["type"]}",
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
