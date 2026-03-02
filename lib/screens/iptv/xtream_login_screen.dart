import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/xtream_service.dart';
import 'new_iptv_screen.dart';

class XtreamLoginScreen extends StatefulWidget {
  final Function(XtreamService)? onLoginSuccess;
  
  const XtreamLoginScreen({super.key, this.onLoginSuccess});

  @override
  State<XtreamLoginScreen> createState() => _XtreamLoginScreenState();
}

class _XtreamLoginScreenState extends State<XtreamLoginScreen> {
  bool _loading = false;
  String? _error;
  
  // البيانات الثابتة (مخفية)
  final String _serverUrl = 'iptv.pdata.ps';
  final String _port = '80';
  final String _username = 'belal';
  final String _password = '20202020';
  final String _externalUrl = '213.6.142.189';
  final String _externalPort = '45677'; // ✅ منفذ واحد للكل
  final bool _useExternal = true;

  @override
  void initState() {
    super.initState();
    _saveDefaultData();
  }

  Future<void> _saveDefaultData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // حفظ البيانات فقط إذا لم تكن موجودة مسبقاً
      if (prefs.getString('xtream_url') == null) {
        await prefs.setString('xtream_url', _serverUrl);
        await prefs.setString('xtream_port', _port);
        await prefs.setString('xtream_user', _username);
        await prefs.setString('xtream_pass', _password);
        await prefs.setString('xtream_external_url', _externalUrl);
        await prefs.setString('xtream_external_port', _externalPort); // ✅ منفذ واحد
        await prefs.setBool('xtream_use_external', _useExternal);
        print('✅ تم حفظ بيانات الدخول الافتراضية');
      }
    } catch (e) {
      print('⚠️ خطأ في حفظ البيانات: $e');
    }
  }

 Future<void> _login() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    print('🔄 جاري تسجيل الدخول إلى IPTV...');
    
    final service = XtreamService(
      baseUrl: _serverUrl,           // iptv.pdata.ps
      port: _port,                    // 80
      username: _username,            // belal
      password: _password,            // 20202020
      externalBaseUrl: _useExternal ? _externalUrl : null,   // 213.6.142.189 (للاستخدام الخارجي)
      externalPort: _useExternal ? _externalPort : null,     // 45677 (للاستخدام الخارجي)
    );

    await Future.delayed(const Duration(milliseconds: 500));

    print('📡 جاري جلب القنوات...');
    final channels = await service.getLiveChannels(forceRefresh: true);
    
    if (channels.isEmpty) {
      throw Exception('لا توجد قنوات متاحة');
    }

    print('✅ تم تحميل ${channels.length} قناة بنجاح');

    Future(() async {
      await service.getMovies(forceRefresh: true);
      await service.getSeries(forceRefresh: true);
      print('✅ تم تحميل باقي المحتوى في الخلفية');
    });

    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!(service);
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(context, '/main');
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NewIptvScreen(xtreamService: service),
          ),
        );
      }
    }

  } catch (e) {
    print('❌ خطأ في تسجيل الدخول: $e');
    setState(() {
      _error = 'فشل الاتصال بالسيرفر: $e';
    });
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPTV'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade700,
              Colors.deepPurple.shade300,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.live_tv,
                      size: 50,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text(
                    '2Net IPTV',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  const Text(
                    'اضغط على زر الدخول للوصول إلى القنوات والأفلام',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 30),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.deepPurple, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'معلومات الاتصال',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const SizedBox(width: 28),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'السيرفر: $_serverUrl',
                                    style: TextStyle(color: Colors.deepPurple.shade700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'المستخدم: $_username',
                                    style: TextStyle(color: Colors.deepPurple.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 25),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _login,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.login, size: 20),
                      label: Text(
                        _loading ? 'جاري تسجيل الدخول...' : 'دخول',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                            ),
                          ),
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
}