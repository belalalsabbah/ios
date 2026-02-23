import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../main.dart'; // 🔑 rootNavigatorKey

class AppUpdateService {
  // =========================
  // URL السيرفر المحلي
  // =========================
  static const String localCheckUrl =
      "http://50.50.50.1/api/check_update.php";

  // URL تحديث Google Drive (رابط مباشر)
 static const String gDriveApkUrl =
    "https://drive.google.com/uc?export=download&id=17ovIJ9Hc0FSZ4VhFlcMCgTf-Ub0XeSAT";


  static CancelToken? _cancelToken;
  static String? _downloadedFilePath;
  static bool _isDownloading = false;
  static final ValueNotifier<double> _bgProgress = ValueNotifier(0);

  // =========================
  // 🔄 AUTO CHECK عند التشغيل
  // =========================
  static Future<void> autoCheck(BuildContext context) async {
    if (_isDownloading) return;

    try {
      // أولًا فحص السيرفر المحلي
      final res = await http.get(Uri.parse(localCheckUrl));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data["ok"] == true) {
          await _handleUpdateResponse(context, data["build"], data["apk_url"], data["message"]);
          return;
        }
      }

      // لو ما وجد تحديث على المحلي → جرب Google Drive
      final gDriveData = await _checkGDriveVersion();
      if (gDriveData != null) {
        await _handleUpdateResponse(context, gDriveData["build"], gDriveApkUrl, gDriveData["message"]);
      }

    } catch (_) {}
  }

  // =========================
  // 🧩 معالجة الاستجابة للتحقق من Build
  // =========================
  static Future<void> _handleUpdateResponse(
      BuildContext context,
      int serverBuild,
      String apkUrl,
      String message,
      ) async {
    final info = await PackageInfo.fromPlatform();
    final int currentBuild = int.tryParse(info.buildNumber) ?? 0;

    if (serverBuild <= currentBuild) {
      _toast(context, "التطبيق محدث ✔");
      return;
    }

    _toast(context, "🔄 تم العثور على تحديث، جاري التحميل...");
    silentDownload(apkUrl, message);
  }

  // =========================
  // 🔍 فحص إصدار Google Drive (يمكن حفظه في ملف JSON أو هنا مباشرة)
  // =========================
  static Future<Map<String, dynamic>?> _checkGDriveVersion() async {
    try {
      // هذا مثال: افترضنا وجود JSON صغير على Google Drive أو معرفة رقم build مسبق
      // إذا كان عندك طريقة للحصول على build dynamically يمكن تعديل هنا
      return {
        "build": 105, // ضع آخر build متاح على Google Drive
        "message": "يوجد تحديث جديد من Google Drive"
      };
    } catch (_) {
      return null;
    }
  }

  // =========================
  // ⬇️ تحميل بصمت
  // =========================
  static Future<void> silentDownload(
      String apkUrl,
      String message,
      ) async {
    if (_isDownloading) return;
    _isDownloading = true;

    _bgProgress.value = 0;

    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(days: 1),
          content: ValueListenableBuilder<double>(
            valueListenable: _bgProgress,
            builder: (_, value, __) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("⬇️ جارٍ تنزيل تحديث 2Net"),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: value),
                const SizedBox(height: 4),
                Text("${(value * 100).toStringAsFixed(0)}%"),
              ],
            ),
          ),
        ),
      );
    }

    try {
      final dir = await getExternalStorageDirectory();
      final filePath = "${dir!.path}/2net_update.apk";

      await Dio().download(
        apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _bgProgress.value = received / total;
          }
        },
      );

      _downloadedFilePath = filePath;
      _isDownloading = false;

      if (context != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      _showInstallPopup(message);
    } catch (_) {
      _isDownloading = false;
      if (context != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    }
  }

  // =========================
  // 📲 نافذة التثبيت (GLOBAL)
  // =========================
  static void _showInstallPopup(String message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("🔄 تحديث جاهز"),
        content: Text(message),
        actions: [
          // ⏭ تجاهل الآن
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("لاحقًا"),
          ),

          // ⬇️ تثبيت
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_downloadedFilePath != null) {
                OpenFilex.open(_downloadedFilePath!);
              }
            },
            child: const Text("تثبيت الآن"),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔍 فحص يدوي
  // =========================
  static Future<void> manualCheck(BuildContext context) async {
    try {
      // أولًا المحلي
      final res = await http.get(Uri.parse(localCheckUrl));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data["ok"] == true) {
          await _handleUpdateResponse(context, data["build"], data["apk_url"], data["message"]);
          return;
        }
      }

      // Google Drive
      final gDriveData = await _checkGDriveVersion();
      if (gDriveData != null) {
        await _handleUpdateResponse(context, gDriveData["build"], gDriveApkUrl, gDriveData["message"]);
      }

    } catch (_) {
      _toast(context, "خطأ أثناء فحص التحديث");
    }
  }

  // =========================
  // 🧾 Dialog يدوي
  // =========================
  static void _showUpdateDialog(
      BuildContext context,
      String apkUrl,
      String message,
      ) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        title: const Text("🔄 تحديث التطبيق"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _downloadAndInstall(context, apkUrl);
            },
            child: const Text("تحميل التحديث"),
          ),
        ],
      ),
    );
  }

  // =========================
  // ⬇️ تحميل مع Progress
  // =========================
  static Future<void> _downloadAndInstall(
      BuildContext context,
      String apkUrl,
      ) async {
    final progress = ValueNotifier<double>(0);
    _cancelToken = CancelToken();

    final messenger = ScaffoldMessenger.of(context);

    final snack = SnackBar(
      duration: const Duration(days: 1),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, value, __) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("⬇️ جارٍ تحميل تحديث 2Net"),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: value),
            const SizedBox(height: 6),
            Text("${(value * 100).toStringAsFixed(0)}%"),
          ],
        ),
      ),
      action: SnackBarAction(
        label: "إلغاء",
        textColor: Colors.red,
        onPressed: () {
          _cancelToken?.cancel();
        },
      ),
    );

    messenger.clearSnackBars();
    messenger.showSnackBar(snack);

    try {
      final dir = await getExternalStorageDirectory();
      final filePath = "${dir!.path}/2net_update.apk";

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

      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          content: const Text("✅ تم تحميل التحديث"),
          action: SnackBarAction(
            label: "تثبيت",
            onPressed: () {
              OpenFilex.open(filePath);
            },
          ),
        ),
      );
    } on DioException catch (e) {
      messenger.clearSnackBars();

      if (CancelToken.isCancel(e)) {
        _toast(context, "تم إلغاء التحديث");
      } else {
        _toast(context, "فشل تحميل التحديث");
      }
    } catch (_) {
      messenger.clearSnackBars();
      _toast(context, "خطأ غير متوقع");
    }
  }

  // =========================
  // 🔔 Toast
  // =========================
  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}
