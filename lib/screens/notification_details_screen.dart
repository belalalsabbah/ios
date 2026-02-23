// lib/screens/notification_details_screen.dart

import 'package:flutter/material.dart';
import '../models/notification_model.dart';

class NotificationDetailsScreen extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailsScreen({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    final type = notification.type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = notification.data ?? {};

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(type.displayName),
          backgroundColor: type.color,
          foregroundColor: Colors.white,
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
              // رأس الإشعار
              _buildHeader(type, isDark),
              
              const SizedBox(height: 20),
              
              // رسالة مخصصة حسب نوع الإشعار
              if (!notification.isRenewed) _buildCustomMessage(data),
              
              // ✅ عرض رسالة الدعم
              if (notification.type == NotificationType.adminMessage) 
                _buildAdminMessageCard(data),
              
              // بطاقة التمديد (لإضافة الأيام)
              if (notification.isExtendDays) _buildExtendDaysCard(data),
              
              // بطاقة إعادة الضبط (للتقصير)
              if (notification.type == NotificationType.resetSubscription) 
                _buildResetCard(data),
              
              const SizedBox(height: 20),
              
              // معلومات إضافية
              _buildInfoCard(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // رأس الإشعار
  // =========================
  Widget _buildHeader(NotificationType type, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: type.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: type.color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: type.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              type.icon,
              size: 50,
              color: type.color,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: type.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              type.displayName,
              style: TextStyle(
                color: type.color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            notification.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // =========================
  // رسالة مخصصة حسب النوع
  // =========================
  Widget _buildCustomMessage(Map<String, dynamic> data) {
    String message = notification.body;
    
    if (notification.isExtendDays) {
      message = "✅ تم إضافة ${data['days'] ?? ''} أيام إلى اشتراكك\n"
               "📅 تاريخ الانتهاء الجديد: ${data['new_expiry'] ?? '---'}";
    } else if (notification.isExpired) {
      message = "❌ انتهى اشتراكك\n"
               "يرجى التجديد للاستمرار في الخدمة";
    } else if (notification.isExpireSoon) {
      message = "⏰ اشتراكك على وشك الانتهاء\n"
               "يرجى التجديد قريباً";
    } else if (notification.type == NotificationType.resetSubscription) {
      message = "🔄 تم إعادة ضبط اشتراكك\n"
               "📅 تاريخ الانتهاء الجديد: ${data['new_expiry'] ?? '---'}";
    } else if (notification.type == NotificationType.ticketReply) {
      message = "📬 رد جديد على تذكرتك";
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.type.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: notification.type.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            notification.isExtendDays ? Icons.add_circle :
            notification.isExpired ? Icons.error :
            notification.isExpireSoon ? Icons.warning :
            notification.type == NotificationType.resetSubscription ? Icons.sync :
            notification.type == NotificationType.ticketReply ? Icons.reply :
            Icons.info_outline,
            size: 24,
            color: notification.type.color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: notification.type.color,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // ✅ بطاقة رسالة الدعم الفني
  // =========================
  Widget _buildAdminMessageCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            notification.type.color.withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: notification.type.color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: notification.type.color.withOpacity(0.1),
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
                  color: notification.type.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.message,
                  color: notification.type.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رسالة من الدعم الفني',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: notification.type.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // محتوى الرسالة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              notification.body,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // معلومات إضافية عن الرسالة
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                notification.timeAgo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const Spacer(),
              if (data['admin'] != null)
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'من: ${data['admin']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          if (data['message_type'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _getMessageTypeColor(data['message_type']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getMessageTypeColor(data['message_type']).withOpacity(0.3)),
              ),
              child: Text(
                'نوع الرسالة: ${_getMessageTypeText(data['message_type'])}',
                style: TextStyle(
                  fontSize: 12,
                  color: _getMessageTypeColor(data['message_type']),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================
  // بطاقة التمديد (إضافة أيام)
  // =========================
  Widget _buildExtendDaysCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            notification.type.color.withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: notification.type.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: notification.type.color,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'تفاصيل التمديد',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: notification.type.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem(Icons.add_circle, 'الأيام المضافة', '${data['days'] ?? '---'} أيام'),
          if (data['old_expiry'] != null)
            _buildInfoItem(Icons.event_busy, 'من تاريخ', _formatDate(data['old_expiry'])),
          if (data['new_expiry'] != null)
            _buildInfoItem(Icons.event_available, 'إلى تاريخ', _formatDate(data['new_expiry'])),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'سيتم خصم هذه الأيام عند التجديد القادم',
                    style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // بطاقة إعادة الضبط (تقصير)
  // =========================
  Widget _buildResetCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            notification.type.color.withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: notification.type.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync, color: notification.type.color, size: 24),
              const SizedBox(width: 8),
              Text(
                'إعادة ضبط الاشتراك',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: notification.type.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (data['old_expiry'] != null)
            _buildInfoItem(Icons.event_busy, 'من تاريخ', _formatDate(data['old_expiry'])),
          if (data['new_expiry'] != null)
            _buildInfoItem(Icons.event_available, 'إلى تاريخ', _formatDate(data['new_expiry'])),
          if (data['days_changed'] != null)
            _buildInfoItem(Icons.trending_down, 'الأيام المقتطعة', '${data['days_changed']} يوم'),
        ],
      ),
    );
  }

  // =========================
  // عنصر معلومات مبسط
  // =========================
  Widget _buildInfoItem(IconData icon, String label, String value) {
    if (value.isEmpty || value == 'null' || value == '---') {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // بطاقة المعلومات الإضافية
  // =========================
  Widget _buildInfoCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            context,
            Icons.access_time,
            'تاريخ الإرسال',
            notification.formattedDate,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.info,
            'الحالة',
            notification.isRead ? 'مقروء' : 'غير مقروء',
            valueColor: notification.isRead ? Colors.green : notification.type.color,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, {Color? valueColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: valueColor ?? (isDark ? Colors.white : Colors.black87),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // =========================
  // دوال مساعدة
  // =========================
  String _formatDate(String dateStr) {
    try {
      if (dateStr.contains(' ')) dateStr = dateStr.split(' ')[0];
      final date = DateTime.parse(dateStr);
      return '${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getMessageTypeColor(String? type) {
    switch (type) {
      case 'info':
        return Colors.blue;
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return notification.type.color;
    }
  }

  String _getMessageTypeText(String? type) {
    switch (type) {
      case 'info':
        return 'معلومات';
      case 'success':
        return 'نجاح';
      case 'warning':
        return 'تحذير';
      case 'error':
        return 'خطأ';
      default:
        return 'عامة';
    }
  }
}