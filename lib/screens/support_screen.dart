// lib/screens/support_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'add_days_screen.dart';
import '../services/api_service.dart';
import '../services/app_update_service.dart';
import '../models/ticket_model.dart';
import 'my_tickets_screen.dart';
import 'create_ticket_screen.dart';

class SupportScreen extends StatefulWidget {
  final String token;
  final Future<void> Function()? onRefreshUnread;

  const SupportScreen({
    super.key,
    required this.token,
    this.onRefreshUnread,
  });

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _isLoading = false;
  // ✅ إضافة مفتاح للتحكم في MyTicketsScreen
  final GlobalKey<MyTicketsScreenState> _ticketsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshData() async {
    if (widget.onRefreshUnread != null) {
      await widget.onRefreshUnread!();
    }
    // ✅ تحديث قائمة التذاكر
    _ticketsKey.currentState?.refreshTickets();
  }

  void _openCreateTicketDialog(TicketType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: CreateTicketScreen(
            token: widget.token,
            type: type,
            onTicketCreated: () {
              // ✅ تحديث قائمة التذاكر بعد إضافة تذكرة جديدة
              _ticketsKey.currentState?.refreshTickets();
              if (widget.onRefreshUnread != null) {
                widget.onRefreshUnread!();
              }
            },
          ),
        ),
      ),
    );
  }

  // ✅ دالة فتح شاشة إضافة أيام كـ BottomSheet
  void _openAddDaysBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: AddDaysScreen(
            token: widget.token,
          ),
        ),
      ),
    ).then((_) {
      // ✅ تحديث البيانات بعد العودة من إضافة الأيام
      _refreshData();
    });
  }

// whatsapp code - نسخة محسنة
void _openWhatsApp() async {
  try {
    // الرقم مع رمز الدولة بدون +
    var phone = "972569139191";
    var message = "مرحباً، أحتاج مساعدة في تطبيق 2Net";
    var encodedMessage = Uri.encodeComponent(message);
    
    // ✅ قائمة بجميع الروابط الممكنة (مرتبة حسب الأولوية)
    List<Map<String, dynamic>> urls = [
      {
        'url': Uri.parse("whatsapp://send?phone=$phone&text=$encodedMessage"),
        'mode': LaunchMode.externalApplication,
        'name': 'WhatsApp Intent'
      },
      {
        'url': Uri.parse("https://wa.me/$phone?text=$encodedMessage"),
        'mode': LaunchMode.externalApplication,
        'name': 'wa.me'
      },
      {
        'url': Uri.parse("https://api.whatsapp.com/send?phone=$phone&text=$encodedMessage"),
        'mode': LaunchMode.externalApplication,
        'name': 'API'
      },
      {
        'url': Uri.parse("https://web.whatsapp.com/send?phone=$phone&text=$encodedMessage"),
        'mode': LaunchMode.inAppWebView,
        'name': 'Web'
      },
    ];
    
    bool opened = false;
    
    // ✅ تجربة كل الروابط بالترتيب
    for (var item in urls) {
      if (await canLaunchUrl(item['url'])) {
        debugPrint('📱 محاولة فتح: ${item['name']}');
        await launchUrl(item['url'], mode: item['mode']);
        opened = true;
        break;
      }
    }
    
    // ✅ إذا فشلت كل الروابط
    if (!opened) {
      // محاولة فتح متجر Play
      var marketUrl = Uri.parse("market://details?id=com.whatsapp");
      if (await canLaunchUrl(marketUrl)) {
        // عرض حوار للمستخدم قبل فتح المتجر
        _showInstallDialog();
      } else {
        // آخر خيار: موقع واتساب
        await launchUrl(
          Uri.parse("https://www.whatsapp.com/download"),
          mode: LaunchMode.inAppWebView,
        );
      }
    }
    
  } catch (e) {
    debugPrint("❌ خطأ في فتح واتساب: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ حدث خطأ، حاول مرة أخرى'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ✅ دالة مساعدة لعرض حوار التثبيت
void _showInstallDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('واتساب غير مثبت'),
      content: const Text(
        'يجب تثبيت واتساب لاستخدام هذه الخدمة.\n'
        'هل تريد تنزيله الآن؟'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            var marketUrl = Uri.parse("market://details?id=com.whatsapp");
            if (await canLaunchUrl(marketUrl)) {
              await launchUrl(marketUrl);
            } else {
              await launchUrl(
                Uri.parse("https://play.google.com/store/apps/details?id=com.whatsapp"),
                mode: LaunchMode.externalApplication,
              );
            }
          },
          child: const Text('تنزيل واتساب'),
        ),
      ],
    ),
  );
}

  void _showAboutDialog() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('عن التطبيق'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('الإصدار', '${info.version} (${info.buildNumber})'),
            const SizedBox(height: 8),
            _buildInfoRow('السنة', DateTime.now().year.toString()),
            const SizedBox(height: 8),
            _buildInfoRow('المطور', '2Net'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              AppUpdateService.manualCheck(context);
            },
            icon: const Icon(Icons.update),
            label: const Text('تحقق من التحديث'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الدعم الفني'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
            ),
          ],
        ),
        
        body: Container(
          color: backgroundColor,
          child: Column(
            children: [
              // شاشة التذاكر مدمجة هنا مع المفتاح
              Expanded(
                child: MyTicketsScreen(
                  key: _ticketsKey,  // ✅ إضافة المفتاح للتحكم
                  token: widget.token,
                  onRefreshUnread: widget.onRefreshUnread,
                ),
              ),
            ],
          ),
        ),
        
        // أزرار الإجراءات السريعة
        bottomNavigationBar: _buildQuickActionsBar(),
        
        // زر إضافة تذكرة جديد
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openCreateTicketDialog(TicketType.support),
          icon: const Icon(Icons.add),
          label: const Text('تذكرة جديدة'),
          backgroundColor: Colors.blue.shade700,
        ),
      ),
    );
  }

  // ⚡ أزرار الإجراءات السريعة
  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // زر إضافة أيام - الآن يفتح BottomSheet
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.calendar_today,
                label: 'إضافة أيام',
                color: Colors.green,
                onTap: _openAddDaysBottomSheet,  // ✅ تغيير هنا
              ),
            ),
            const SizedBox(width: 8),
            
            // زر واتساب
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.message,
                label: 'واتساب',
                color: Colors.teal,
                onTap: _openWhatsApp,
              ),
            ),
            const SizedBox(width: 8),
            
            // زر عن التطبيق
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.info_outline,
                label: 'عن التطبيق',
                color: Colors.purple,
                onTap: _showAboutDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}