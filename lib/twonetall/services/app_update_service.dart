import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;

class AppUpdateService {
  static const String checkUrl =
      "http://50.50.50.1/api/check_update.php";

  static CancelToken? _cancelToken;

  /// 🔍 فحص يدوي (زر فحص تحديث)
  static Future<void> manualCheck(BuildContext context) async {
    try {
      final res = await http.get(Uri.parse(checkUrl));
      if (res.statusCode != 200) {
        _toast(context, "فشل الاتصال بالسيرفر");
        return;
      }

      final data = json.decode(res.body);
      if (data["ok"] != true) {
        _toast(context, "لا يوجد تحديث");
        return;
      }

      final String apkUrl = data["apk_url"];
      final String message =
          data["message"] ?? "يوجد تحديث جديد للتطبيق";

      _showUpdateDialog(context, apkUrl, message);
    } catch (_) {
      _toast(context, "خطأ أثناء فحص التحديث");
    }
  }

  /// 🧾 Dialog تأكيد التحديث
  static void _showUpdateDialog(
    BuildContext context,
    String apkUrl,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🔄 تحديث التطبيق"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAndInstall(context, apkUrl);
            },
            child: const Text("تحميل التحديث"),
          ),
        ],
      ),
    );
  }

  /// ⬇️ تحميل APK + شريط تقدم + زر إلغاء
  static Future<void> _downloadAndInstall(
    BuildContext context,
    String apkUrl,
  ) async {
    final progress = ValueNotifier<double>(0);
    _cancelToken = CancelToken();

    late OverlayEntry overlay;

    overlay = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black54,
        child: Center(
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, value, __) => Container(
              width: 280,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "⏬ جارٍ تحميل التحديث",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 12),
                  Text("${(value * 100).toStringAsFixed(0)}%"),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      _cancelToken?.cancel("user_cancel");
                      overlay.remove();
                    },
                    child: const Text(
                      "إلغاء التحديث",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = "${dir.path}/2net_update.apk";

      await Dio().download(
        apkUrl,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progress.value = received / total;
          }
        },
        deleteOnError: true,
      );

      overlay.remove();
      await OpenFilex.open(filePath);
    } on DioException catch (e) {
      overlay.remove();
      if (!CancelToken.isCancel(e)) {
        _toast(context, "فشل تحميل التحديث");
      }
    } catch (_) {
      overlay.remove();
      _toast(context, "خطأ غير متوقع");
    }
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
