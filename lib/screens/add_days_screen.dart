import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddDaysScreen extends StatefulWidget {
  final String token;

  const AddDaysScreen({super.key, required this.token});

  @override
  State<AddDaysScreen> createState() => _AddDaysScreenState();
}

class _AddDaysScreenState extends State<AddDaysScreen> {
  // متغيرات الحالة
  int? _selectedDays;
  bool _sending = false;
  String? _errorMessage;
  
  // وحدات التحكم
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // خيارات الأيام
  final List<int> _daysOptions = [1, 2, 3, 4, 5];
  
  // متغير للسحب للإغلاق
  final GlobalKey _scaffoldKey = GlobalKey();
  double _dragOffset = 0;
  static const double _closeThreshold = 150;
  bool _isDragging = false;

  @override
  void dispose() {
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _noteMessage {
    if (_selectedDays == null) return "";
    if (_selectedDays == 1) return "✅ هذا اليوم مجاني";
    return "⚠️ سيتم خصم هذه الأيام عند التجديد";
  }

  Color get _noteColor {
    if (_selectedDays == null) return Colors.transparent;
    if (_selectedDays == 1) return Colors.green;
    return Colors.orange;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // فقط إذا كان السحب للأسفل وليس في منطقة النص
    if (details.delta.dy > 0 && _scrollController.position.pixels <= 0) {
      setState(() {
        _dragOffset += details.delta.dy;
        _isDragging = true;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragOffset > _closeThreshold) {
      Navigator.pop(context);
    } else {
      setState(() {
        _dragOffset = 0;
        _isDragging = false;
      });
    }
  }

  Future<void> _submit() async {
    // التحقق من اختيار الأيام
    if (_selectedDays == null) {
      setState(() => _errorMessage = "❌ الرجاء اختيار عدد الأيام");
      return;
    }

    if (_sending) return;

    setState(() {
      _sending = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.addDays(
        token: widget.token,
        days: _selectedDays.toString(),
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      if (res["ok"] == true) {
        _showSuccessDialog(res["message"] ?? "✅ تمت الإضافة بنجاح");
      } else {
        setState(() {
          _errorMessage = res["message"] ?? "❌ فشل التنفيذ";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "❌ فشل الاتصال بالسيرفر";
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('تم بنجاح'),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text(
              'موافق',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text("إضافة أيام"),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            // منع السحب للإغلاق أثناء التمرير
            if (scrollNotification is ScrollStartNotification) {
              setState(() => _isDragging = false);
            }
            return false;
          },
          child: GestureDetector(
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            onVerticalDragCancel: () {
              setState(() {
                _dragOffset = 0;
                _isDragging = false;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // خلفية السحب للإغلاق
                if (_dragOffset > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _dragOffset.clamp(0, _closeThreshold + 50),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _dragOffset > _closeThreshold
                                ? Colors.red.withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _dragOffset > 30 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _dragOffset > _closeThreshold
                                    ? Icons.check_circle
                                    : Icons.arrow_upward,
                                color: _dragOffset > _closeThreshold
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _dragOffset > _closeThreshold
                                    ? 'اترك للإغلاق'
                                    : 'اسحب للأسفل للإغلاق',
                                style: TextStyle(
                                  color: _dragOffset > _closeThreshold
                                      ? Colors.red
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // المحتوى الرئيسي مع تحريك للأسفل عند السحب
                Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: Container(
                    color: backgroundColor,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: _isDragging 
                          ? const NeverScrollableScrollPhysics()
                          : const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // بطاقة المعلومات
                          _buildInfoCard(),
                          
                          const SizedBox(height: 24),

                          // اختيار عدد الأيام
                          _buildDaysSelector(),
                          
                          const SizedBox(height: 16),

                          // رسالة توضيحية
                          if (_selectedDays != null) _buildInfoMessage(),
                          
                          const SizedBox(height: 24),

                          // حقل الملاحظات (بسيط)
                          _buildNotesField(),
                          
                          const SizedBox(height: 16),

                          // رسالة الخطأ
                          if (_errorMessage != null) _buildErrorWidget(),
                          
                          const SizedBox(height: 16),

                          // زر الإرسال
                          _buildSubmitButton(),
                          
                          const SizedBox(height: 30),
                          
                          // تلميح السحب للإغلاق
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey.shade400,
                                  size: 30,
                                ),
                                Text(
                                  'اسحب للأسفل للإغلاق',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "معلومات هامة",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "• يوم واحد مجاني كل شهر\n"
            "• الأيام الإضافية يتم خصمها عند التجديد\n"
            "• يمكنك إضافة حتى 5 أيام في الشهر",
            style: TextStyle(fontSize: 14, height: 1.8),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "اختر عدد الأيام:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _daysOptions.map((days) {
            final isSelected = _selectedDays == days;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDays = days;
                  _errorMessage = null;
                });
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            days == 1 ? Colors.green : Colors.orange,
                            days == 1 ? Colors.green.shade300 : Colors.orange.shade300,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (days == 1 ? Colors.green : Colors.orange)
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (days == 1 ? Colors.green : Colors.orange)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$days",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      days == 1 ? "يوم" : "أيام",
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInfoMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _noteColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _noteColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _selectedDays == 1 ? Icons.check_circle : Icons.warning_amber_rounded,
            color: _noteColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _noteMessage,
              style: TextStyle(
                color: _noteColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ملاحظات (اختياري):",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'اكتب أي ملاحظات إضافية هنا...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${_notesController.text.length}/500',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _sending ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _sending
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'جاري الإرسال...',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              )
            : const Text(
                'إرسال الطلب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}