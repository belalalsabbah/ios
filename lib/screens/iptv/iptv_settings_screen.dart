import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/xtream_service.dart';
import 'new_iptv_screen.dart';

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

  // ✅ دالة اختبار الاتصال فقط (بدون حفظ)
  Future<void> _testConnection() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = XtreamService(
        baseUrl: _urlController.text,
        port: _portController.text,
        username: _userController.text,
        password: _passController.text,
        externalBaseUrl: _useExternal ? _externalUrlController.text : null,
        externalPort: _useExternal ? _externalPortController.text : null,
      );

      final channels = await service.getLiveChannels(forceRefresh: true);
      
      if (channels.isEmpty) {
        throw Exception('لا توجد قنوات متاحة');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ اتصال ناجح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'فشل الاتصال: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveAndTest() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = XtreamService(
        baseUrl: _urlController.text,
        port: _portController.text,
        username: _userController.text,
        password: _passController.text,
        externalBaseUrl: _useExternal ? _externalUrlController.text : null,
        externalPort: _useExternal ? _externalPortController.text : null,
      );

      final channels = await service.getLiveChannels(forceRefresh: true);
      
      if (channels.isEmpty) {
        throw Exception('لا توجد قنوات متاحة');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('xtream_url', _urlController.text);
      await prefs.setString('xtream_port', _portController.text);
      await prefs.setString('xtream_user', _userController.text);
      await prefs.setString('xtream_pass', _passController.text);
      await prefs.setString('xtream_external_url', _externalUrlController.text);
      await prefs.setString('xtream_external_port', _externalPortController.text);
      await prefs.setBool('xtream_use_external', _useExternal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ الإعدادات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, service);
      }
    } catch (e) {
      setState(() {
        _error = 'فشل الاتصال: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ✅ دالة مسح الكاش
  Future<void> _clearCache() async {
    if (widget.currentService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد خدمة نشطة لمسح كاشها')),
      );
      return;
    }

    setState(() => _loading = true);
    await widget.currentService!.clearCache();
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم مسح الكاش'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // دعم الوضع الداكن (Dark Mode)
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: isDark ? Colors.deepPurple.shade900.withOpacity(0.2) : Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isDark ? Colors.deepPurple.shade700 : Colors.deepPurple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'معلومات الدخول الأساسية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _urlController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'رابط السيرفر',
                      hintText: 'iptv.pdata.ps',
                      prefixIcon: const Icon(Icons.link, color: Colors.deepPurple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: isDark,
                      fillColor: isDark ? Colors.grey.shade800 : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'المنفذ الداخلي',
                      hintText: '80',
                      prefixIcon: const Icon(Icons.settings_ethernet, color: Colors.deepPurple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: isDark,
                      fillColor: isDark ? Colors.grey.shade800 : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _userController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: const Icon(Icons.person, color: Colors.deepPurple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: isDark,
                      fillColor: isDark ? Colors.grey.shade800 : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _passController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: isDark,
                      fillColor: isDark ? Colors.grey.shade800 : null,
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
                color: isDark ? Colors.orange.shade900.withOpacity(0.2) : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isDark ? Colors.orange.shade700 : Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.public, color: isDark ? Colors.orange.shade200 : Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'إعدادات الوصول من الخارج',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.orange.shade200 : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  SwitchListTile(
                    title: Text('استخدام رابط خارجي', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    subtitle: Text('للتشغيل من خارج الشبكة', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                    value: _useExternal,
                    activeColor: Colors.orange.shade700,
                    onChanged: (value) {
                      setState(() {
                        _useExternal = value;
                      });
                    },
                  ),
                  
                  if (_useExternal) ...[
                    const Divider(color: Colors.grey),
                    
                    TextField(
                      controller: _externalUrlController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'الرابط الخارجي',
                        hintText: '213.6.142.189',
                        prefixIcon: const Icon(Icons.public, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: isDark,
                        fillColor: isDark ? Colors.grey.shade800 : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: _externalPortController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'المنفذ الخارجي',
                        hintText: '45677',
                        prefixIcon: const Icon(Icons.settings_ethernet, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: isDark,
                        fillColor: isDark ? Colors.grey.shade800 : null,
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
                  color: isDark ? Colors.red.shade900.withOpacity(0.2) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: isDark ? Colors.red.shade200 : Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: isDark ? Colors.red.shade200 : Colors.red.shade700),
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
                    onPressed: _loading ? null : _testConnection,
                    icon: const Icon(Icons.sync),
                    label: const Text('اختبار فقط'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('مسح الكاش'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
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
    _externalPortController.dispose();
    super.dispose();
  }
}