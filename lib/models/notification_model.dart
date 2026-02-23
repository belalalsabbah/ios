// lib/models/notification_model.dart

import 'package:flutter/material.dart';

enum NotificationType {
  expireSoon,
  expired,
  renewed,           // ✅ تجديد كامل (فاتورة - شهر أو أكثر)
  extendDays,        // ✅ تمديد (إضافة أيام - 1-5 أيام)
  resetSubscription, // ✅ إعادة ضبط (تقصير - أيام سالبة)
  ticketReply,
  adminMessage,      // ✅ نوع جديد للرسائل من الدعم
  info,
  warning,
  success,
  error;

  static NotificationType fromString(String type) {
    switch (type) {
      case 'expire_soon':
        return NotificationType.expireSoon;
      case 'expired':
        return NotificationType.expired;
      case 'renewed':
        return NotificationType.renewed;
      case 'extend_days':
        return NotificationType.extendDays;
      case 'reset_subscription':
        return NotificationType.resetSubscription;
      case 'ticket_reply':
        return NotificationType.ticketReply;
      case 'admin_message': // ✅ النوع الجديد
        return NotificationType.adminMessage;
      case 'success':
        return NotificationType.success;
      case 'warning':
        return NotificationType.warning;
      case 'error':
        return NotificationType.error;
      default:
        return NotificationType.info;
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.expireSoon:
        return 'قرب الانتهاء';
      case NotificationType.expired:
        return 'منتهي';
      case NotificationType.renewed:
        return 'فاتورة تجديد';
      case NotificationType.extendDays:
        return 'تمديد اشتراك';
      case NotificationType.resetSubscription:
        return 'إعادة ضبط اشتراك';
      case NotificationType.ticketReply:
        return 'رد على تذكرة';
      case NotificationType.adminMessage: // ✅
        return 'رسالة من الدعم';
      case NotificationType.success:
        return 'نجاح';
      case NotificationType.warning:
        return 'تحذير';
      case NotificationType.error:
        return 'خطأ';
      default:
        return 'معلومات';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.expireSoon:
        return Icons.timer_off;
      case NotificationType.expired:
        return Icons.cancel;
      case NotificationType.renewed:
        return Icons.receipt;
      case NotificationType.extendDays:
        return Icons.add_circle_outline;
      case NotificationType.resetSubscription:
        return Icons.sync_problem;
      case NotificationType.ticketReply:
        return Icons.reply;
      case NotificationType.adminMessage: // ✅
        return Icons.message;
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.error:
        return Icons.error;
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.expireSoon:
        return Colors.orange;
      case NotificationType.expired:
        return Colors.red;
      case NotificationType.renewed:
        return Colors.purple;
      case NotificationType.extendDays:
        return Colors.teal;
      case NotificationType.resetSubscription:
        return Colors.amber;
      case NotificationType.ticketReply:
        return Colors.blue;
      case NotificationType.adminMessage: // ✅
        return Colors.indigo;
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class AppNotification {
  final int id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      type: NotificationType.fromString(json['type']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      isRead: (json['is_read'] ?? 0) == 1,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} يوم${difference.inDays > 1 ? 'اً' : ''}';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  String get formattedDate {
    return '${createdAt.year}/${createdAt.month}/${createdAt.day} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  // ✅ دوال للتحقق من النوع
  bool get isExpired => type == NotificationType.expired;
  bool get isRenewed => type == NotificationType.renewed;
  bool get isExtendDays => type == NotificationType.extendDays;
  bool get isResetSubscription => type == NotificationType.resetSubscription;
  bool get isExpireSoon => type == NotificationType.expireSoon;
  bool get isTicketReply => type == NotificationType.ticketReply;
  bool get isAdminMessage => type == NotificationType.adminMessage; // ✅ دالة جديدة
  
  // ✅ بيانات الفاتورة (للتجديد الكامل)
  String? get invoiceNumber => data?['invoice_number']?.toString();
  String? get invoiceAmount => data?['amount']?.toString();
  String? get invoicePeriod => data?['period']?.toString();
  String? get invoiceDate => data?['invoice_date']?.toString();
  String? get invoiceDueDate => data?['due_date']?.toString();
  String? get serviceName => data?['service_name']?.toString();
  String? get subscriberName => data?['subscriber_name']?.toString();
  String? get renewedBy => data?['renewed_by']?.toString();
  
  // ✅ بيانات إضافة الأيام (للتمديد)
  String? get addedDays => data?['days']?.toString();
  String? get oldExpiryDate => data?['old_expiry']?.toString();
  String? get newExpiryDate => data?['new_expiry']?.toString();
  String? get notes => data?['notes']?.toString();
  
  // ✅ بيانات إعادة الضبط (للأيام السالبة)
  String? get daysChanged => data?['days_changed']?.toString();
  
  // ✅ بيانات الرسالة من الدعم
  String? get adminName => data?['admin']?.toString();
  String? get messageType => data?['message_type']?.toString();
  String? get messageIcon => data?['icon']?.toString();
  
  // ✅ رسالة مخصصة حسب نوع الإشعار
  String get customMessage {
    if (isExtendDays) {
      return '✅ تم تمديد اشتراكك بإضافة ${addedDays ?? ''} أيام\n'
             '📅 تاريخ الانتهاء الجديد: ${newExpiryDate ?? '---'}\n'
             '⚠️ سيتم خصم هذه الأيام عند التجديد القادم';
    } else if (isRenewed) {
      String message = '🎉 تم تجديد اشتراكك بنجاح';
      if (invoiceAmount != null && invoiceAmount!.isNotEmpty) {
        message += '\n💰 المبلغ: $invoiceAmount شيكل';
      }
      if (invoiceNumber != null && invoiceNumber!.isNotEmpty) {
        message += '\n🧾 رقم الفاتورة: $invoiceNumber';
      }
      return message;
    } else if (isResetSubscription) {
      return '🔄 تم إعادة ضبط اشتراكك\n'
             '📅 تاريخ الانتهاء الجديد: ${newExpiryDate ?? '---'}\n'
             '⚠️ تم تعديل ${daysChanged ?? ''} يوم من اشتراكك';
    } else if (isExpired) {
      return '❌ انتهى اشتراكك\n'
             'يرجى التجديد للاستمرار في الخدمة';
    } else if (isExpireSoon) {
      return '⏰ اشتراكك على وشك الانتهاء\n'
             'يرجى التجديد قريباً';
    } else if (isAdminMessage) {
      return '📩 رسالة من الدعم الفني';
    }
    return body;
  }
}