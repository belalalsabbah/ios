// FILE: lib/screens/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/push_service.dart';
import '../services/api_service.dart';
import '../services/xtream_service.dart';
import '../main.dart';
import 'fcm_test_simple.dart';
import 'status_screen.dart';
import 'invoices_screen.dart';
import 'notifications_screen.dart';
import 'support_screen.dart';
import 'my_tickets_screen.dart';
import 'ticket_details_screen.dart';
import 'admin_webview.dart';
import 'iptv/xtream_login_screen.dart';
import 'iptv/iptv_settings_screen.dart';
import 'iptv/new_iptv_screen.dart';

class MainNavigation extends StatefulWidget {
  final String token;
  final int selectedTab;
  final int? openTicketId;

  const MainNavigation({
    super.key,
    required this.token,
    this.selectedTab = 0,
    this.openTicketId,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _index;
  String _username = '';
  bool _isLoading = true;
  String _adminUrl = '';

  final _homeKey = GlobalKey<NavigatorState>();
  final _invoicesKey = GlobalKey<NavigatorState>();
  final _notifKey = GlobalKey<NavigatorState>();
  final _supportKey = GlobalKey<NavigatorState>();
  final _iptvKey = GlobalKey<NavigatorState>();

  int unreadCount = 0;
  bool _shouldOpenTicket = false;
  int? _ticketIdToOpen;
  
  bool _isXtreamLoggedIn = false;
  XtreamService? _xtreamService;

  GlobalKey<NavigatorState> get _currentNavKey {
    if (_index == 0) return _homeKey;
    if (_index == 1) return _invoicesKey;
    if (_index == 2) return _notifKey;
    if (_index == 3) return _supportKey;
    return _iptvKey;
  }

  @override
  void initState() {
    super.initState();
    
    _index = widget.selectedTab;
    
    if (widget.openTicketId != null) {
      debugPrint('📱 initState: openTicketId = ${widget.openTicketId}');
      _ticketIdToOpen = widget.openTicketId;
      _shouldOpenTicket = true;
    }
    
    _loadUsername();
    _detectNetworkAndSetUrl();
    PushService.init(widget.token);
    _loadUnreadFromLocal();
    refreshUnread();
    _loadXtreamData();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Foreground message: ${message.notification?.title}');
      refreshUnread();
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Message opened app: ${message.notification?.title}');
      _handleNotificationClick(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('🔔 App opened from terminated state: ${message.notification?.title}');
        _handleNotificationClick(message);
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (_shouldOpenTicket && _ticketIdToOpen != null) {
      debugPrint('📱 didChangeDependencies: فتح تذكرة $_ticketIdToOpen');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openTicketFromNotification(_ticketIdToOpen!);
      });
      _shouldOpenTicket = false;
    }
  }

  void _openTicketFromNotification(int ticketId) {
    debugPrint('📱 فتح تذكرة $ticketId من الإشعار');
    
    if (_index != 3) {
      setState(() {
        _index = 3;
      });
    }
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_supportKey.currentContext != null) {
        debugPrint('📱 فتح تفاصيل التذكرة $ticketId');
        Navigator.of(_supportKey.currentContext!).push(
          MaterialPageRoute(
            builder: (context) => TicketDetailsScreen(
              ticketId: ticketId,
              token: widget.token,
              onTicketUpdated: () {},
            ),
          ),
        );
      } else {
        debugPrint('❌ _supportKey.currentContext is null');
      }
    });
  }

  Future<void> _loadXtreamData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('xtream_url');
      final port = prefs.getString('xtream_port');
      final user = prefs.getString('xtream_user');
      final pass = prefs.getString('xtream_pass');
      final externalUrl = prefs.getString('xtream_external_url');
      final externalPort = prefs.getString('xtream_external_port');
      final useExternal = prefs.getBool('xtream_use_external') ?? false;
      
      if (url != null && port != null && user != null && pass != null) {
        _xtreamService = XtreamService(
          baseUrl: url,
          port: port,
          username: user,
          password: pass,
          externalBaseUrl: useExternal ? externalUrl : null,
          externalPort: useExternal ? externalPort : null,
        );
        _isXtreamLoggedIn = true;
        
        print('✅ تم تحميل بيانات Xtream بنجاح');
        print('📡 سيتم استخدام البروكسي للتشغيل: http://50.50.50.1/api/iptv_proxy.php');
      }
    } catch (e) {
      print('خطأ في تحميل بيانات Xtream: $e');
    }
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? '';
    });
  }

  Future<void> _detectNetworkAndSetUrl() async {
    String url = '';
    
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      
      print('📡 Device IP: $ip');
      
      if (ip != null && ip.startsWith('50.50.50.')) {
        url = 'http://50.50.50.1/api/admin.php';
        print('✅ داخل الشبكة - استخدم الرابط الداخلي');
      } else {
        url = 'http://213.6.142.189:45678/api/admin.php';
        print('✅ خارج الشبكة - استخدم الرابط الخارجي');
      }
    } catch (e) {
      print('❌ فشل كشف الشبكة: $e');
      url = 'http://213.6.142.189:45678/api/admin.php';
    }

    setState(() {
      _adminUrl = url;
      _isLoading = false;
    });
  }

  void _openTicketsDirectly() {
    _supportKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (_) => MyTicketsScreen(token: widget.token),
      ),
    );
  }

  void _handleNotificationClick(RemoteMessage message) {
    final type = message.data['type'];
    final action = message.data['action'];
    final ticketId = message.data['ticket_id'];
    
    if (type == 'open_tickets' || action == 'open_tickets_screen') {
      _switchTab(3);
      _shouldOpenTicket = true;
    }
    else if (type == 'ticket_reply' && ticketId != null) {
      _switchTab(3);
      _shouldOpenTicket = true;
    }
    else {
      _switchTab(2);
    }
    refreshUnread();
  }

  Future<void> refreshUnread() async {
    try {
      final res = await ApiService.getNotifications(widget.token);

      if (res["ok"] == true && res["items"] is List) {
        final items = res["items"] as List;
        
        final unread = items.where((e) {
          if (e["type"] == "renewed") {
            return false;
          }
          return e["is_read"] == 0;
        }).length;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt("notifications_unread", unread);

        if (!mounted) return;
        setState(() => unreadCount = unread);
      }
    } catch (_) {}
  }

  Future<void> _loadUnreadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      unreadCount = prefs.getInt("notifications_unread") ?? 0;
    });
  }

  void _switchTab(int i) {
    if (i == 5 && (_username == 'admin' || _username == 'belal')) {
      setState(() {
        _index = i;
      });
      return;
    }

    if (_index == i) {
      _currentNavKey.currentState?.popUntil((r) => r.isFirst);
      if (i == 2) refreshUnread();
      return;
    }

    setState(() => _index = i);

    if (i == 2) {
      refreshUnread();
    }
  }

  void _showFcmTest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FcmTestSimple()),
    );
  }

  Future<bool> _onWillPop() async {
    final nav = _currentNavKey.currentState;

    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
  }

  // ✅ إعادة تنظيم أزرار الـ AppBar: دمجها في قائمة منبثقة
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج'),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
              ListTile(
                leading: const Icon(Icons.science, color: Colors.orange),
                title: const Text('اختبار FCM'),
                onTap: () {
                  Navigator.pop(context);
                  _showFcmTest();
                },
              ),
              if (_username == 'belal')
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.grey),
                  title: const Text('إعدادات IPTV'),
                  onTap: () {
                    Navigator.pop(context);
                    _openIptvSettings();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        label: "الرئيسية",
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long),
        label: "الفواتير",
      ),
      BottomNavigationBarItem(
        icon: Stack(
          children: [
            const Icon(Icons.notifications),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        label: "الإشعارات",
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.support_agent),
        label: "الدعم",
      ),
      // ✅ إضافة اسم المستخدم في تبويب IPTV
      BottomNavigationBarItem(
        icon: const Icon(Icons.live_tv),
        label: _isXtreamLoggedIn ? 'IPTV (${_xtreamService?.username})' : 'IPTV',
      ),
    ];

    if (_username == 'admin' || _username == 'belal') {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings_input_component),
          label: "إدارة الشبكة",
        ),
      );
    }

    return items;
  }

  Future<void> _openIptvSettings() async {
    XtreamService? currentService;
    
    if (_isXtreamLoggedIn && _xtreamService != null) {
      currentService = _xtreamService;
    }
    
    final updatedService = await Navigator.push<XtreamService>(
      context,
      MaterialPageRoute(
        builder: (_) => IptvSettingsScreen(currentService: currentService),
      ),
    );
    
    if (updatedService != null) {
      setState(() {
        _xtreamService = updatedService;
        _isXtreamLoggedIn = true;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'تأكيد تسجيل الخروج',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('تسجيل خروج'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ApiService.logout(
      token: widget.token,
      context: context,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('username');
    
    await prefs.remove('xtream_url');
    await prefs.remove('xtream_port');
    await prefs.remove('xtream_user');
    await prefs.remove('xtream_pass');

    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final selectedColor = isDark ? Colors.lightBlue : Colors.blue;
    final unselectedColor = isDark ? Colors.grey[400]! : Colors.grey;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ✅ أيقونة القائمة (Menu) بدلاً من الأزرار المبعثرة
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
                  onPressed: _showOptionsMenu,
                  tooltip: 'خيارات',
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('الرئيسية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const Text('2Net - ISP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              
              // اسم المستخدم (يبقى كما هو)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _username,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
        ),
        body: Stack(
          children: [
            Offstage(
              offstage: _index != 0,
              child: Navigator(
                key: _homeKey,
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => StatusScreen(
                    token: widget.token,
                    onOpenNotifications: () => _switchTab(2),
                    onRefreshUnread: refreshUnread,
                    onOpenIptv: () => _switchTab(4),  // ✅ فتح IPTV
                  ),
                ),
              ),
            ),
            
            Offstage(
              offstage: _index != 1,
              child: Navigator(
                key: _invoicesKey,
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => InvoicesScreen(
                    token: widget.token,
                    onChanged: refreshUnread,
                  ),
                ),
              ),
            ),
            
            Offstage(
              offstage: _index != 2,
              child: Navigator(
                key: _notifKey,
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => NotificationsScreen(
                    token: widget.token,
                    onChanged: refreshUnread,
                  ),
                ),
              ),
            ),
            
            Offstage(
              offstage: _index != 3,
              child: Navigator(
                key: _supportKey,
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => SupportScreen(
                    token: widget.token,
                    onRefreshUnread: refreshUnread,
                  ),
                ),
              ),
            ),

            Offstage(
              offstage: _index != 4,
              child: Navigator(
                key: _iptvKey,
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) {
                    if (_isXtreamLoggedIn && _xtreamService != null) {
                      return NewIptvScreen(xtreamService: _xtreamService!);
                    } else {
                      return XtreamLoginScreen(
                        onLoginSuccess: (service) {
                          setState(() {
                            _xtreamService = service;
                            _isXtreamLoggedIn = true;
                          });
                        },
                      );
                    }
                  },
                ),
              ),
            ),

            if (_username == 'admin' || _username == 'belal')
              Offstage(
                offstage: _index != 5,
                child: AdminWebView(
                  url: _adminUrl,
                  title: 'إدارة الشبكة',
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: _switchTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: backgroundColor,
          selectedItemColor: selectedColor,
          unselectedItemColor: unselectedColor,
          elevation: 8,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
          ),
          items: _buildNavItems(),
        ),
      ),
    );
  }
}