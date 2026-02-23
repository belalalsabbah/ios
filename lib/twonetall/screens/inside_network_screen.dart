import 'package:flutter/material.dart';
import 'splash_screen.dart';

class InsideNetworkScreen extends StatelessWidget {
  final String message;
  const InsideNetworkScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تفعيل 2Net")),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 60),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => SplashScreen()),
                );
              },
              child: const Text("إعادة المحاولة"),
            ),
          ],
        ),
      ),
    );
  }
}
