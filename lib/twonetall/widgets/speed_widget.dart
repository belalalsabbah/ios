import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class SpeedWidget extends StatefulWidget {
  const SpeedWidget({super.key});

  @override
  State<SpeedWidget> createState() => _SpeedWidgetState();
}

class _SpeedWidgetState extends State<SpeedWidget> {
  double speedMbps = 0;
  bool testing = false;

  Future<void> testSpeed() async {
    setState(() => testing = true);

    final stopwatch = Stopwatch()..start();

    try {
      await Dio().get(
        "https://speed.cloudflare.com/__down?bytes=2000000",
        options: Options(responseType: ResponseType.bytes),
      );
    } catch (_) {}

    stopwatch.stop();

    final seconds = stopwatch.elapsedMilliseconds / 1000;
    final mbps = (2 / seconds) * 8;

    setState(() {
      speedMbps = mbps;
      testing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "📶 سرعة الإنترنت",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            testing
                ? const CircularProgressIndicator()
                : Text(
                    "${speedMbps.toStringAsFixed(1)} Mbps",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: testing ? null : testSpeed,
              child: const Text("قياس السرعة"),
            ),
          ],
        ),
      ),
    );
  }
}
