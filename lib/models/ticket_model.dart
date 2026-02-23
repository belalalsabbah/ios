// lib/models/ticket_model.dart

import 'package:flutter/material.dart'; // ✅ إضافة هذا الاستيراد المهم

enum TicketType {
  support,
  renew,
  other;

  static TicketType fromString(String type) {
    switch (type) {
      case 'support':
        return TicketType.support;
      case 'renew':
        return TicketType.renew;
      default:
        return TicketType.other;
    }
  }

  String get displayName {
    switch (this) {
      case TicketType.support:
        return 'دعم فني';
      case TicketType.renew:
        return 'إضافة أيام';
      case TicketType.other:
        return 'أخرى';
    }
  }

  IconData get icon {
    switch (this) {
      case TicketType.support:
        return Icons.support_agent;
      case TicketType.renew:
        return Icons.calendar_today;
      case TicketType.other:
        return Icons.help_outline;
    }
  }

  Color get color {
    switch (this) {
      case TicketType.support:
        return Colors.blue;
      case TicketType.renew:
        return Colors.green;
      case TicketType.other:
        return Colors.orange;
    }
  }
}

class Ticket {
  final int id;
  final TicketType type;
  final String message;
  final String status;
  final DateTime createdAt;
  final List<TicketReply> replies;
  final int repliesCount;

  Ticket({
    required this.id,
    required this.type,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.replies,
    required this.repliesCount,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      type: TicketType.fromString(json['type'] ?? 'other'),
      message: json['message'] ?? '',
      status: json['status'] ?? 'closed',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      replies: (json['replies'] as List? ?? [])
          .map((r) => TicketReply.fromJson(r))
          .toList(),
      repliesCount: json['replies_count'] ?? 0,
    );
  }

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
}

class TicketReply {
  final String admin;
  final String reply;
  final DateTime createdAt;
  final bool isUser;
  final String senderName;

  TicketReply({
    required this.admin,
    required this.reply,
    required this.createdAt,
    required this.isUser,
    required this.senderName,
  });

  factory TicketReply.fromJson(Map<String, dynamic> json) {
    return TicketReply(
      admin: json['admin'] ?? json['admin_username'] ?? '',
      reply: json['reply'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      isUser: json['is_user'] ?? false,
      senderName: json['sender_name'] ?? (json['is_user'] == true ? 'أنت' : 'الدعم الفني'),
    );
  }
}