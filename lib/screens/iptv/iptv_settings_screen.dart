import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/xtream_service.dart';
import 'iptv_screen.dart';

class IptvSettingsScreen extends StatefulWidget {
  final XtreamService? currentService;
  
  const IptvSettingsScreen({super.key, this.currentService});

  @override
  State<IptvSettingsScreen> createState() => _IptvSettingsScreenState();
}

class _IptvSettingsScreenState extends State<IptvSettingsScreen> {
  final _urlController = TextEditingController(text: 'iptv.pdata.ps');
  final _portController = TextEditingController(text: '80');
  final _userController = TextEditingController(text: 'belal');
  final _passController = TextEditingController(text: '20202020');
  final _externalUrlController = TextEditingController(text: '213.6.142.189');
  final _externalPortController = TextEditingController(text: '45677'); // ✅ منفذ واحد
  
  bool _loading = false;
  bool _useExternal = true;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _urlController.text = prefs.getString('xtream_url') ?? 'iptv.pdata.ps';
      _portController.text = prefs.getString('xtream_port') ?? '80';
      _userController.text = prefs.getString('xtream_user') ?? 'belal';
      _passController.text = prefs.getString('xtream_pass') ?? '20202020';
      _externalUrlController.text = prefs.getString('xtream_external_url') ?? '213.6.142.189';
      _externalPortController.text = prefs.getString('xtream_external_port') ?? '45677'; // ✅ منفذ واحد
      _useExternal = prefs.getBool('xtream_use_external') ?? true;
    });
  }

  Future<void> _saveAndTest() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // إنشاء الخدمة للاختبار
      final service = XtreamService(
        baseUrl: _urlController.text,
        port: _portController.text,
        username: _userController.text,
        password: _passController.text,
        externalBaseUrl: _useExternal ? _externalUrlController.text : null,
        externalPort: _useExternal ? _externalPortController.text : null, // ✅ منفذ واحد
      );

      // اختبار جلب القنوات
      final channels = await service.getLiveChannels(forceRefresh: true);
      
      if (channels.isEmpty) {
        throw Exception('لا توجد قنوات متاحة');
      }

      // حفظ البيانات
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('xtream_url', _urlController.text);
      await prefs.setString('xtream_port', _portController.text);
      await prefs.setString('xtream_user', _userController.text);
      await prefs.setString('xtream_pass', _passController.text);
      await prefs.setString('xtream_external_url', _externalUrlController.text);
      await prefs.setString('xtream_external_port', _externalPortController.text); // ✅ منفذ واحد
      await prefs.setBool('xtream_use_external', _useExternal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ الإعدادات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        // العودة للشاشة السابقة
        Navigator.pop(context, service);
      }

    } catch (e) {
      setState(() {
        _error = 'فشل الاتصال: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات IPTV'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _loading ? null : _saveAndTest,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔵 معلومات الدخول الأساسية
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.deepPurple.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'معلومات الدخول الأساسية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // رابط السيرفر
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'رابط السيرفر',
                      hintText: 'iptv.pdata.ps',
                      prefixIcon: const Icon(Icons.link, color: Colors.deepPurple),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // المنفذ
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'المنفذ الداخلي',
                      hintText: '80',
                      prefixIcon: const Icon(Icons.settings_ethernet, color: Colors.deepPurple),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // اسم المستخدم
                  TextField(
                    controller: _userController,
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: const Icon(Icons.person, color: Colors.deepPurple),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // كلمة المرور
                  TextField(
                    controller: _passController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock, color: Colors.deepPurple),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.deepPurple,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🟠 إعدادات الوصول من الخارج
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.public, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'إعدادات الوصول من الخارج',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // تفعيل الرابط الخارجي
                  SwitchListTile(
                    title: const Text('استخدام رابط خارجي'),
                    subtitle: const Text('للتشغيل من خارج الشبكة'),
                    value: _useExternal,
                    activeColor: Colors.orange.shade700,
                    onChanged: (value) {
                      setState(() {
                        _useExternal = value;
                      });
                    },
                  ),
                  
                  if (_useExternal) ...[
                    const Divider(),
                    
                    // الرابط الخارجي
                    TextField(
                      controller: _externalUrlController,
                      decoration: InputDecoration(
                        labelText: 'الرابط الخارجي',
                        hintText: '213.6.142.189',
                        prefixIcon: const Icon(Icons.public, color: Colors.orange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // المنفذ الخارجي (موحد)
                    TextField(
                      controller: _externalPortController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'المنفذ الخارجي',
                        hintText: '45677',
                        prefixIcon: const Icon(Icons.settings_ethernet, color: Colors.orange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // عرض الخطأ إن وجد
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // أزرار الإجراءات
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _saveAndTest,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ واختبار'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('إلغاء'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    _externalUrlController.dispose();
    _externalPortController.dispose(); // ✅ فقط هذا
    super.dispose();
  }
}