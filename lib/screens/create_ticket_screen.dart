// lib/screens/create_ticket_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/ticket_model.dart';

class CreateTicketScreen extends StatefulWidget {
  final String token;
  final TicketType type;
  final VoidCallback onTicketCreated;

  const CreateTicketScreen({
    super.key,
    required this.token,
    required this.type,
    required this.onTicketCreated,
  });

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    _daysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    // التحقق من المدخلات
    if (widget.type == TicketType.renew) {
      if (_daysController.text.trim().isEmpty) {
        setState(() => _error = '❌ الرجاء إدخال عدد الأيام');
        return;
      }
      
      final days = int.tryParse(_daysController.text.trim());
      if (days == null || days <= 0) {
        setState(() => _error = '❌ عدد الأيام غير صحيح');
        return;
      }
      
      if (days > 5) {
        setState(() => _error = '❌ الحد الأقصى 5 أيام في الشهر');
        return;
      }
    } else {
      if (_messageController.text.trim().isEmpty) {
        setState(() => _error = '❌ الرجاء كتابة رسالتك');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      late Map<String, dynamic> response;
      
      if (widget.type == TicketType.renew) {
        // إضافة أيام
        response = await ApiService.addDays(
          token: widget.token,
          days: _daysController.text.trim(),
          notes: _notesController.text.trim(),
        );
      } else {
        // إنشاء تذكرة دعم
        response = await ApiService.createTicket(
          token: widget.token,
          type: widget.type == TicketType.support ? 'support' : 'other',
          message: _messageController.text.trim(),
        );
      }

      if (!mounted) return;

      if (response['ok'] == true) {
        // نجاح
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.type == TicketType.renew
                    ? '✅ تم إرسال طلب إضافة الأيام بنجاح'
                    : '✅ تم إرسال تذكرة الدعم بنجاح',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          // إغلاق الشاشة وتحديث القائمة
          Navigator.pop(context);
          widget.onTicketCreated();
        }
      } else {
        setState(() {
          _error = response['message'] ?? '❌ فشل الإرسال';
        });
      }
    } catch (e) {
      setState(() {
        _error = '❌ خطأ في الاتصال: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.type == TicketType.renew ? 'إضافة أيام' : 'تذكرة دعم'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // أيقونة النوع
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: widget.type.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.type.icon,
                    size: 40,
                    color: widget.type.color,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // حقول الإدخال حسب النوع
              if (widget.type == TicketType.renew) ...[
                _buildLabel('عدد الأيام'),
                const SizedBox(height: 8),
                TextField(
                  controller: _daysController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'مثال: 3',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '• يوم واحد مجاني كل شهر\n'
                    '• الحد الأقصى 5 أيام في الشهر',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildLabel('ملاحظات (اختياري)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'أي ملاحظات إضافية...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                _buildLabel('رسالتك'),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'اكتب مشكلتك أو استفسارك هنا...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // رسالة الخطأ
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
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
              
              const SizedBox(height: 24),
              
              // زر الإرسال
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.type.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.type == TicketType.renew
                              ? 'إرسال الطلب'
                              : 'إرسال التذكرة',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}