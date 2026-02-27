// FILE: lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:media_kit/media_kit.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/ticket_details_screen.dart';
import 'screens/main_navigation.dart';
import 'services/push_service.dart';
import 'services/token_store.dart';

/// 🔑 هذا المفتاح العالمي يسمح لنا بإظهار Dialog من أي مكان
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// ===============================
/// Theme Service (Dark / Light)
/// ===============================
class ThemeService extends ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }

  void setDark(bool value) {
    _isDark = value;
    notifyListeners();
  }
}

/// ===============================
/// MAIN
/// ===============================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 🎬 تهيئة MediaKit
  MediaKit.ensureInitialized();

  /// 🔥 تهيئة Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /// تهيئة الإشعارات المحلية
  await PushService.initLocalNotifications();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const MyApp(),
    ),
  );
}

/// ===============================
/// ROOT APP
/// ===============================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _initialToken;

  @override
  void initState() {
    super.initState();
    
    // تحميل التوكن المخزن
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await TokenStore.load();
    setState(() {
      _initialToken = token;
    });
    
    // إذا كان هناك توكن، قم بتهيئة PushService
    if (token != null && token.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        PushService.init(token);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, theme, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '2Net Customer',

          // 🔑 ربط المفتاح هنا
          navigatorKey: rootNavigatorKey,

          /// 🌞 Light Theme
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.grey.shade100,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),

          /// 🌙 Dark Theme
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
          ),

          /// 🔄 Theme Mode
          themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,

          /// 📱 تعريف Routes
          routes: {
            '/login': (context) => const LoginScreen(),
            '/notifications': (context) => NotificationsScreen(
              token: _initialToken ?? '',
              onChanged: () {},
            ),
          },
          
          onGenerateRoute: (settings) {
            // ✅ معالجة route التذكرة
            if (settings.name == '/ticket-details') {
              final args = settings.arguments;
              
              // إذا كانت arguments عبارة عن int (رقم التذكرة)
              if (args is int) {
                return MaterialPageRoute(
                  builder: (context) => TicketDetailsScreen(
                    ticketId: args,
                    token: _initialToken ?? '',
                    onTicketUpdated: () {},
                  ),
                );
              }
              
              // إذا كانت arguments عبارة عن Map (قد يأتي من الإشعار)
              if (args is Map) {
                final ticketId = args['ticketId'] ?? args['openTicketId'];
                if (ticketId != null) {
                  int? id = ticketId is int ? ticketId : int.tryParse(ticketId.toString());
                  if (id != null && id > 0) {
                    return MaterialPageRoute(
                      builder: (context) => TicketDetailsScreen(
                        ticketId: id,
                        token: _initialToken ?? '',
                        onTicketUpdated: () {},
                      ),
                    );
                  }
                }
              }
              
              // في حالة الخطأ
              return MaterialPageRoute(
                builder: (context) => const Scaffold(
                  body: Center(
                    child: Text(
                      'خطأ: معرف التذكرة غير صحيح',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  ),
                ),
              );
            }
            
            // ✅ معالجة route الرئيسية
            if (settings.name == '/main') {
              final args = settings.arguments as Map?;
              final selectedTab = args?['selectedTab'] ?? 0;
              final openTicketId = args?['openTicketId'];
              
              debugPrint('📱 main route - openTicketId: $openTicketId');
              
              return MaterialPageRoute(
                builder: (context) => MainNavigation(
                  token: _initialToken ?? '',
                  selectedTab: selectedTab,
                  openTicketId: openTicketId,
                ),
              );
            }
            
            return null;
          },

          home: const SplashScreen(),
        );
      },
    );
  }
}