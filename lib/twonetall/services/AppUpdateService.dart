import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class AppUpdateService {

  static const String checkUrl =
      "http://50.50.50.1/api/check_update.php";

  static Future<void> check(BuildContext context) async {
    try {
      final res = await http.get(Uri.parse(checkUrl));
      if (res.statusCode != 200) return;

      final data = json.decode(res.body);
      if (data["ok"] != true) return;

      _showUpdateDialog(
        context,
        apkUrl: data["apk_url"],
        force: data["force"] == true,
      );
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String apkUrl,
    required bool force,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (_) => AlertDialog(
        title: const Text("🔄 تحديث التطبيق"),
        content: const Text(
          "يوجد تحديث جديد.\nسيتم تنزيله وتثبيته الآن.",
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("لاحقاً"),
            ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _downloadAndInstall(apkUrl);
            },
            child: const Text("تحديث الآن"),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(String apkUrl) async {
    final dir = await getExternalFilesDirectory();
    if (dir == null) return;

    final apkPath = "${dir.path}/2net_update.apk";

    final dio = Dio();
    await dio.download(apkUrl, apkPath);

    await OpenFilex.open(apkPath);
  }
}
