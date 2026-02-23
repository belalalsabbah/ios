import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // لازم تضيف هاد import
import '../services/api_service.dart';
import '../services/token_store.dart';
import '../services/push_service.dart';
import 'splash_screen.dart';

/// ================== Helpers ==================

Color statusColorByDays(int days) {
  if (days <= 0) return const Color(0xFFEF5350);
  if (days <= 10) return const Color(0xFFFFA726);
  if (days <= 20) return const Color(0xFFFFB74D);
  return const Color(0xFF66BB6A);
}

List<Color> statusGradientColors(int days) {
  if (days <= 0) {
    return [const Color(0xFFEF5350), const Color(0xFFFF7043)];
  } else if (days <= 10) {
    return [const Color(0xFFFFA726), const Color(0xFFFFB74D)];
  } else if (days <= 20) {
    return [const Color(0xFFFFB74D), const Color(0xFFFFCC80)];
  } else {
    return [const Color(0xFF66BB6A), const Color(0xFF81C784)];
  }
}

IconData statusIconByDays(int days) {
  if (days <= 0) return Icons.cancel_outlined;
  if (days <= 10) return Icons.warning_amber_rounded;
  return Icons.check_circle_outline;
}

String statusTextByDays(int days) {
  if (days <= 0) return "منتهي";
  if (days <= 10) return "قارب على الانتهاء";
  return "فعال";
}

/// ===========================================================

class StatusScreen extends StatefulWidget {
  final String token;
  final VoidCallback onOpenNotifications;
  final Future<void> Function() onRefreshUnread;

  const StatusScreen({
    super.key,
    required this.token,
    required this.onOpenNotifications,
    required this.onRefreshUnread,
  });

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;
  int notificationsCount = 0;

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Expansion panels state - all collapsed by default
  bool _isSubscriptionExpanded = false;
  bool _isQuickFactsExpanded = false;
  bool _isMotivationalExpanded = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..forward();

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuad,
    ));

    load();
    loadNotificationsCount();
    PushService.init(widget.token);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  /// ================= API =================

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
        _progressController.forward(from: 0);
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

  Future<void> loadNotificationsCount() async {
    try {
      final res = await ApiService.getNotifications(widget.token);
      if (res["ok"] == true) {
        setState(() {
          notificationsCount = res["unread"] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> onRefresh() async {
    _slideController.reset();
    _slideController.forward();
    _progressController.reset();
    await load();
    await loadNotificationsCount();
    await widget.onRefreshUnread();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '--';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  // ✅ دالة مشاركة الاشتراك عبر واتساب
  Future<void> _shareSubscriptionToWhatsApp() async {
    try {
      if (data == null) {
        _showMessage('لا توجد بيانات للمشاركة');
        return;
      }

      final userName = data?["name"] ?? 'مستخدم';
      final expireDate = data?["expiration"];
      final daysLeft = data?["days_left"] ?? 0;
      final price = data?["unitprice"] ?? '0';
      final renewDate = data?["renew_date"];
      
      String formattedExpire = _formatDate(expireDate);
      String formattedRenew = _formatDate(renewDate);
      
      final message = '''
📋 *تفاصيل اشتراكي في 2Net*

👤 *اسم المشترك:* $userName
📅 *آخر تجديد:* $formattedRenew
📅 *تاريخ الانتهاء:* $formattedExpire
⏱️ *الأيام المتبقية:* $daysLeft يوم
💰 *سعر الاشتراك:* $price شيكل
📊 *الحالة:* ${statusTextByDays(daysLeft)}

✅ للمزيد من المعلومات، يرجى التواصل مع الدعم الفني
''';

      final whatsappUrl = 'whatsapp://send?text=${Uri.encodeFull(message)}';
      
      try {
        if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
          await launchUrl(Uri.parse(whatsappUrl));
        } else {
          await Share.share(message, subject: 'تفاصيل اشتراكي');
        }
      } catch (e) {
        await Share.share(message, subject: 'تفاصيل اشتراكي');
      }
      
    } catch (e) {
      _showMessage('حدث خطأ في المشاركة');
      print('خطأ في المشاركة: $e');
    }
  }

  // ✅ دالة مساعدة لعرض رسائل سريعة
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = data?["unitprice"]?.toString() ?? '0';
    final renewDate = data?["renew_date"];
    final expireDate = data?["expiration"];
    final int totalDays = data?["total_days"] ?? 0;
    final int daysLeft = data?["days_left"] ?? 0;
    final String userName = data?["name"] ?? 'مستخدم';
    
    final double progress = totalDays > 0 ? (daysLeft / totalDays).clamp(0.0, 1.0) : 0.0;
    final statusColor = statusColorByDays(daysLeft);
    final List<Color> gradientColorsList = statusGradientColors(daysLeft);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: widget.onOpenNotifications,
                      splashRadius: 24,
                    ),
                  ),
                  if (notificationsCount > 0)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          notificationsCount > 9 ? '9+' : notificationsCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: loading
              ? _buildLoadingWidget(gradientColorsList)
              : error != null
                  ? _buildErrorWidget()
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            gradientColorsList.first.withOpacity(0.9),
                            gradientColorsList.last.withOpacity(0.7),
                            Colors.grey.shade50,
                          ],
                          stops: const [0.0, 0.3, 1.0],
                        ),
                      ),
                      child: RefreshIndicator(
                        onRefresh: onRefresh,
                        color: statusColor,
                        backgroundColor: Colors.white,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  const SizedBox(height: kToolbarHeight + 20),
                                  
                                  FadeTransition(
                                    opacity: _pulseAnimation,
                                    child: SlideTransition(
                                      position: _slideAnimation,
                                      child: _buildStatusCard(
                                        userName,
                                        daysLeft,
                                        statusColor,
                                        gradientColorsList,
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  _buildActionButtons(statusColor), // ✅ هنا تم تعديله
                                  
                                  const SizedBox(height: 20),
                                  
                                  _buildExpandableSection(
                                    title: 'تفاصيل الاشتراك',
                                    icon: Icons.subscriptions,
                                    gradientColors: gradientColorsList,
                                    isExpanded: _isSubscriptionExpanded,
                                    onExpansionChanged: (expanded) {
                                      setState(() {
                                        _isSubscriptionExpanded = expanded;
                                      });
                                    },
                                    child: _buildSubscriptionCard(
                                      totalDays,
                                      daysLeft,
                                      progress,
                                      statusColor,
                                      gradientColorsList,
                                      price,
                                      renewDate,
                                      expireDate,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  _buildExpandableSection(
                                    title: 'إحصائيات سريعة',
                                    icon: Icons.analytics_outlined,
                                    gradientColors: gradientColorsList,
                                    isExpanded: _isQuickFactsExpanded,
                                    onExpansionChanged: (expanded) {
                                      setState(() {
                                        _isQuickFactsExpanded = expanded;
                                      });
                                    },
                                    child: _buildQuickFactsCard(
                                      totalDays,
                                      daysLeft,
                                      progress,
                                      statusColor,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  _buildExpandableSection(
                                    title: 'توصيات',
                                    icon: Icons.tips_and_updates_outlined,
                                    gradientColors: gradientColorsList,
                                    isExpanded: _isMotivationalExpanded,
                                    onExpansionChanged: (expanded) {
                                      setState(() {
                                        _isMotivationalExpanded = expanded;
                                      });
                                    },
                                    child: _buildMotivationalMessage(daysLeft),
                                  ),
                                  
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget(List<Color> gradientColors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            gradientColors.first.withOpacity(0.9),
            gradientColors.last.withOpacity(0.7),
            Colors.grey.shade50,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 1 + (value * 0.1),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 25),
            Text(
              'جاري تحميل البيانات...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Color statusColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.refresh_rounded,
              label: 'تحديث',
              color: statusColor,
              onTap: onRefresh,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.share_rounded,
              label: 'مشاركة',
              color: statusColor,
              onTap: _shareSubscriptionToWhatsApp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... باقي الدوال كما هي (لم يتغير شيء) ...
  Widget _buildExpandableSection({required String title, required IconData icon, required List<Color> gradientColors, required bool isExpanded, required Function(bool) onExpansionChanged, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: isExpanded,
          onExpansionChanged: onExpansionChanged,
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (isExpanded)
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isExpanded ? FontWeight.bold : FontWeight.w600,
              color: isExpanded ? gradientColors.first : Colors.black87,
            ),
          ),
          trailing: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isExpanded 
                  ? gradientColors.first.withOpacity(0.1)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: isExpanded ? gradientColors.first : Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    String userName,
    int daysLeft,
    Color statusColor,
    List<Color> gradientColors,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.8, end: 1),
                duration: const Duration(milliseconds: 500),
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        statusIconByDays(daysLeft),
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        statusTextByDays(daysLeft),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الأيام المتبقية',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        daysLeft.toString(),
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          height: 0.9,
                          shadows: [
                            Shadow(
                              color: statusColor.withOpacity(0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'يوم',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Transform.rotate(
                    angle: value * 0.1,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: statusColor.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.timer_outlined,
                        color: statusColor,
                        size: 45,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    int totalDays,
    int daysLeft,
    double progress,
    Color statusColor,
    List<Color> gradientColors,
    String price,
    String? renewDate,
    String? expireDate,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildCircularProgress(
                progress,
                daysLeft,
                totalDays,
                statusColor,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressStat(
                    'الأيام المتبقية',
                    daysLeft,
                    totalDays,
                    statusColor,
                  ),
                  const SizedBox(height: 15),
                  _buildProgressStat(
                    'الأيام المستخدمة',
                    totalDays - daysLeft,
                    totalDays,
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 25),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.price_change_outlined,
                'سعر الاشتراك',
                '$price شيكل',
                statusColor,
              ),
              const SizedBox(height: 15),
              _buildInfoRow(
                Icons.event_repeat_outlined,
                'آخر تجديد',
                _formatDate(renewDate),
                statusColor,
              ),
              const SizedBox(height: 15),
              _buildInfoRow(
                Icons.event_busy_outlined,
                'تاريخ الانتهاء',
                _formatDate(expireDate),
                statusColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircularProgress(
    double progress,
    int daysLeft,
    int totalDays,
    Color color,
  ) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          CustomPaint(
            painter: _CircularProgressPainter(
              progress: progress,
              color: color,
              backgroundColor: Colors.grey.shade200,
            ),
            child: Container(),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress * 100),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, value, child) {
                    return Text(
                      '${value.round()}%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'متبقي',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, int value, int total, Color color) {
    final percent = total > 0 ? value / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFactsCard(
    int totalDays,
    int daysLeft,
    double progress,
    Color statusColor,
  ) {
    final usedDays = totalDays - daysLeft;
    final usedPercent = totalDays > 0 ? usedDays / totalDays : 0.0;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFactItem(
              Icons.calendar_today_outlined,
              'إجمالي',
              totalDays.toString(),
              'يوم',
              statusColor,
            ),
            _buildFactItem(
              Icons.access_time_outlined,
              'متبقي',
              daysLeft.toString(),
              'يوم',
              statusColor,
            ),
            _buildFactItem(
              Icons.check_circle_outlined,
              'مستخدم',
              usedDays.toString(),
              'يوم',
              usedPercent > 0.7 ? Colors.orange : statusColor,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'نسبة الاستهلاك',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: usedPercent * 100),
                    duration: const Duration(milliseconds: 1000),
                    builder: (context, value, child) {
                      return Text(
                        '${value.round()}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: usedPercent > 0.7 ? Colors.orange : statusColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: usedPercent,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    usedPercent > 0.7 ? Colors.orange : statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFactItem(
    IconData icon,
    String label,
    String value,
    String unit,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationalMessage(int daysLeft) {
    String message;
    IconData icon;
    Color color;
    String title;
    
    if (daysLeft <= 0) {
      title = "اشتراك منتهي";
      message = "انتهى اشتراكك، يرجى التجديد فوراً للاستمرار في استخدام الخدمة";
      icon = Icons.error_outline_rounded;
      color = Colors.red;
    } else if (daysLeft <= 5) {
      title = "تنبيه هام";
      message = "الأيام المتبقية قليلة! بادر بتجديد اشتراكك قريباً";
      icon = Icons.warning_amber_rounded;
      color = Colors.orange;
    } else if (daysLeft <= 10) {
      title = "تذكير";
      message = "متبقي $daysLeft يوم على انتهاء الاشتراك. يمكنك التجديد الآن";
      icon = Icons.info_outline_rounded;
      color = Colors.blue;
    } else {
      title = "اشتراك نشط";
      message = "اشتراكك نشط. استمتع بخدماتنا المتكاملة";
      icon = Icons.check_circle_outline_rounded;
      color = Colors.green;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 46),
          child: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade300, Colors.red.shade100],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 70,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 25),
            Text(
              error!,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade300,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonSnackbar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature قريباً'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Custom painter for circular progress
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.15;
    
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);
    
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}