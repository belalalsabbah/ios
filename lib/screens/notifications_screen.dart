// lib/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../models/notification_model.dart';
import 'notification_details_screen.dart';
import 'ticket_details_screen.dart'; // ✅ إضافة import للتذكرة

class NotificationsScreen extends StatefulWidget {
  final String token;
  final VoidCallback onChanged;

  const NotificationsScreen({
    super.key,
    required this.token,
    required this.onChanged,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppNotification> _allNotifications = [];
  List<AppNotification> _unreadNotifications = [];
  List<AppNotification> _readNotifications = [];
  
  bool _isLoading = true;
  String? _error;
  
  // متغيرات البحث والتصفية
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  
  // متغيرات التحديد المتعدد
  bool _isSelectionMode = false;
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getNotifications(widget.token);
      
      if (!mounted) return;

      if (response['ok'] == true) {
        final List<dynamic> items = response['items'] ?? [];
        
        setState(() {
          _allNotifications = items
              .map((json) => AppNotification.fromJson(json))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          _updateFilteredLists();
          _isLoading = false;
        });
        
        // تحديث العداد في MainNavigation
        widget.onChanged();
      } else {
        setState(() {
          _error = response['error'] ?? 'فشل تحميل الإشعارات';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ في الاتصال: $e';
        _isLoading = false;
      });
    }
  }

  void _updateFilteredLists() {
    // ✅ الكل: كل الإشعارات (مع الفواتير)
    _allNotifications = _allNotifications;
    
    // ✅ غير مقروءة: الإشعارات غير المقروءة (مع الفواتير)
    _unreadNotifications = _allNotifications.where((n) => !n.isRead).toList();
    
    // ✅ مقروءة: الإشعارات المقروءة ما عدا الفواتير
    _readNotifications = _allNotifications.where((n) {
      if (n.type == NotificationType.renewed) {
        return false;
      }
      return n.isRead;
    }).toList();
  }

  List<AppNotification> getFilteredNotifications() {
    List<AppNotification> source;
    
    switch (_tabController.index) {
      case 0: // الكل
        source = _allNotifications;
        break;
      case 1: // غير مقروءة
        source = _unreadNotifications;
        break;
      case 2: // مقروءة
        source = _readNotifications;
        break;
      default:
        source = _allNotifications;
    }

    // ✅ إخفاء الفواتير المقروءة من تبويب "الكل" و "المقروءة"
    if (_tabController.index == 0 || _tabController.index == 2) {
      source = source.where((n) {
        if (n.type == NotificationType.renewed && n.isRead) {
          return false;
        }
        return true;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      source = source.where((n) {
        return n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            n.body.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            n.type.displayName.contains(_searchQuery);
      }).toList();
    }

    return source;
  }

  Future<void> _markAsRead(int id) async {
    try {
      await ApiService.markNotificationRead(
        token: widget.token,
        notificationId: id,
      );
      
      setState(() {
        final index = _allNotifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          _allNotifications[index] = AppNotification(
            id: _allNotifications[index].id,
            type: _allNotifications[index].type,
            title: _allNotifications[index].title,
            body: _allNotifications[index].body,
            createdAt: _allNotifications[index].createdAt,
            isRead: true,
            data: _allNotifications[index].data,
          );
        }
        _updateFilteredLists();
      });
      
      widget.onChanged();
    } catch (e) {
      _showSnackBar('❌ فشل تحديث الحالة', isError: true);
    }
  }

  Future<void> _markAsUnread(int id) async {
    try {
      await ApiService.markNotificationUnread(
        token: widget.token,
        notificationId: id,
      );
      
      setState(() {
        final index = _allNotifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          _allNotifications[index] = AppNotification(
            id: _allNotifications[index].id,
            type: _allNotifications[index].type,
            title: _allNotifications[index].title,
            body: _allNotifications[index].body,
            createdAt: _allNotifications[index].createdAt,
            isRead: false,
            data: _allNotifications[index].data,
          );
        }
        _updateFilteredLists();
      });
      
      widget.onChanged();
    } catch (e) {
      _showSnackBar('❌ فشل تحديث الحالة', isError: true);
    }
  }

  Future<void> _deleteNotification(int id) async {
    try {
      await ApiService.deleteNotification(
        token: widget.token,
        notificationId: id,
      );
      
      setState(() {
        _allNotifications.removeWhere((n) => n.id == id);
        _updateFilteredLists();
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        }
      });
      
      widget.onChanged();
      _showSnackBar('✅ تم حذف الإشعار');
    } catch (e) {
      _showSnackBar('❌ فشل حذف الإشعار', isError: true);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.markAllNotificationsRead(widget.token);
      
      setState(() {
        _allNotifications = _allNotifications.map((n) {
          return AppNotification(
            id: n.id,
            type: n.type,
            title: n.title,
            body: n.body,
            createdAt: n.createdAt,
            isRead: true,
            data: n.data,
          );
        }).toList();
        _updateFilteredLists();
      });
      
      widget.onChanged();
      _showSnackBar('✅ تم تعليم الكل كمقروء');
    } catch (e) {
      _showSnackBar('❌ فشل تحديث الإشعارات', isError: true);
    }
  }

  Future<void> _deleteSelected() async {
    final confirm = await _showConfirmDialog(
      'حذف الإشعارات المحددة',
      'هل أنت متأكد من حذف ${_selectedIds.length} إشعار؟',
    );

    if (confirm != true) return;

    for (final id in _selectedIds) {
      try {
        await ApiService.deleteNotification(
          token: widget.token,
          notificationId: id,
        );
      } catch (e) {
        // تجاهل الأخطاء الفردية
      }
    }

    setState(() {
      _allNotifications.removeWhere((n) => _selectedIds.contains(n.id));
      _selectedIds.clear();
      _isSelectionMode = false;
      _updateFilteredLists();
    });

    widget.onChanged();
    _showSnackBar('✅ تم حذف الإشعارات المحددة');
  }

  Future<void> _markSelectedAsRead() async {
    for (final id in _selectedIds) {
      try {
        await ApiService.markNotificationRead(
          token: widget.token,
          notificationId: id,
        );
      } catch (e) {
        // تجاهل الأخطاء الفردية
      }
    }

    setState(() {
      for (final id in _selectedIds) {
        final index = _allNotifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          _allNotifications[index] = AppNotification(
            id: _allNotifications[index].id,
            type: _allNotifications[index].type,
            title: _allNotifications[index].title,
            body: _allNotifications[index].body,
            createdAt: _allNotifications[index].createdAt,
            isRead: true,
            data: _allNotifications[index].data,
          );
        }
      }
      _selectedIds.clear();
      _isSelectionMode = false;
      _updateFilteredLists();
    });

    widget.onChanged();
    _showSnackBar('✅ تم تعليم الإشعارات كمقروءة');
  }

  Future<void> _markSelectedAsUnread() async {
    for (final id in _selectedIds) {
      try {
        await ApiService.markNotificationUnread(
          token: widget.token,
          notificationId: id,
        );
      } catch (e) {
        // تجاهل الأخطاء الفردية
      }
    }

    setState(() {
      for (final id in _selectedIds) {
        final index = _allNotifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          _allNotifications[index] = AppNotification(
            id: _allNotifications[index].id,
            type: _allNotifications[index].type,
            title: _allNotifications[index].title,
            body: _allNotifications[index].body,
            createdAt: _allNotifications[index].createdAt,
            isRead: false,
            data: _allNotifications[index].data,
          );
        }
      }
      _selectedIds.clear();
      _isSelectionMode = false;
      _updateFilteredLists();
    });

    widget.onChanged();
    _showSnackBar('✅ تم تعليم الإشعارات كغير مقروءة');
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      
      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = getFilteredNotifications().map((n) => n.id).toSet();
      _isSelectionMode = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  // ✅ فتح تفاصيل الإشعار - مع دعم التذاكر
  void _openNotificationDetails(AppNotification notification) {
    // إذا كان الإشعار غير مقروء، حدده كمقروء
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }
    
    // ✅ إذا كان الإشعار من نوع ticket_reply، افتح التذكرة مباشرة
    if (notification.type == NotificationType.ticketReply) {
      final ticketId = notification.data?['ticket_id'];
      if (ticketId != null) {
        int? id = ticketId is int ? ticketId : int.tryParse(ticketId.toString());
        if (id != null && id > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailsScreen(
                ticketId: id,
                token: widget.token,
                onTicketUpdated: () {
                  _loadNotifications();
                  widget.onChanged();
                },
              ),
            ),
          ).then((_) {
            _loadNotifications();
            widget.onChanged();
          });
          return;
        }
      }
    }
    
    // باقي أنواع الإشعارات تفتح في شاشة التفاصيل العادية
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: NotificationDetailsScreen(notification: notification),
        ),
      ),
    ).then((_) {
      widget.onChanged();
      _loadNotifications();
    });
  }

  String _getTabName() {
    switch (_tabController.index) {
      case 0:
        return 'كل الإشعارات';
      case 1:
        return 'الإشعارات غير المقروءة';
      case 2:
        return 'الإشعارات المقروءة';
      default:
        return 'الإشعارات';
    }
  }

  List<Widget> _buildAppBarActions() {
    if (_isSelectionMode) {
      return [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
          tooltip: 'إلغاء',
        ),
        IconButton(
          icon: const Icon(Icons.select_all),
          onPressed: _selectAll,
          tooltip: 'تحديد الكل',
        ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteSelected,
            tooltip: 'حذف المحدد',
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: _markSelectedAsRead,
            tooltip: 'تعليم كمقروء',
          ),
        if (_selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.mark_email_unread),
            onPressed: _markSelectedAsUnread,
            tooltip: 'تعليم كغير مقروء',
          ),
      ];
    }

    return [
      IconButton(
        icon: Icon(_isSearching ? Icons.close : Icons.search),
        onPressed: () {
          setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) {
              _searchController.clear();
              _searchQuery = '';
            }
          });
        },
      ),
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: _loadNotifications,
      ),
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'mark_all_read') {
            _markAllAsRead();
          } else if (value == 'select_mode') {
            setState(() {
              _isSelectionMode = true;
            });
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'mark_all_read',
            child: Row(
              children: [
                Icon(Icons.mark_email_read),
                SizedBox(width: 8),
                Text('تعليم الكل كمقروء'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'select_mode',
            child: Row(
              children: [
                Icon(Icons.checklist),
                SizedBox(width: 8),
                Text('وضع التحديد'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildSearchBar() {
    if (!_isSearching) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'ابحث في الإشعارات...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildNotificationsList(Color cardColor, List<AppNotification> notifications) {
    final filteredNotifications = notifications.where((n) {
      if (n.type == NotificationType.renewed && n.isRead) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: Colors.blue.shade700,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = filteredNotifications[index];
          final isSelected = _selectedIds.contains(notification.id);
          
          return _buildNotificationCard(
            notification,
            cardColor,
            isSelected,
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    AppNotification notification,
    Color cardColor,
    bool isSelected,
  ) {
    final type = notification.type;
    final isTicketReply = notification.type == NotificationType.ticketReply;
    
    return GestureDetector(
      onTap: _isSelectionMode
          ? () => _toggleSelection(notification.id)
          : () => _openNotificationDetails(notification),
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _toggleSelection(notification.id);
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        child: Stack(
          children: [
            // بطاقة الإشعار
            Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? type.color.withOpacity(0.1)
                    : cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? type.color
                      : notification.isRead
                          ? Colors.grey.shade200
                          : type.color.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  if (!notification.isRead && !_isSelectionMode)
                    BoxShadow(
                      color: type.color.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // أيقونة النوع
                    Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: type.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: notification.isRenewed || notification.isExtendDays
                                ? Border.all(color: type.color, width: 2)
                                : null,
                          ),
                          child: Icon(
                            type.icon,
                            color: type.color,
                            size: 24,
                          ),
                        ),
                        if (notification.isExtendDays)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        if (notification.isRenewed)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: type.color,
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '₪',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        // ✅ إضافة أيقونة خاصة للتذاكر
                        if (isTicketReply)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.link,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // محتوى الإشعار
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // العنوان والنوع
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.isExtendDays
                                      ? 'تم تمديد الاشتراك +${notification.addedDays ?? ''} أيام'
                                      : notification.isRenewed
                                          ? 'فاتورة تجديد جديدة'
                                          : notification.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: notification.isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    color: notification.isRead
                                        ? Colors.grey.shade600
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: type.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: notification.isRenewed || notification.isExtendDays
                                      ? Border.all(color: type.color, width: 1)
                                      : null,
                                ),
                                child: Text(
                                  type.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: type.color,
                                    fontWeight: notification.isRenewed || notification.isExtendDays
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // نص الإشعار (مختصر)
                          Text(
                            notification.body,
                            style: TextStyle(
                              fontSize: 14,
                              color: notification.isRead
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // التاريخ والوقت + رابط التذكرة
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                notification.timeAgo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const Spacer(),
                              
                              // ✅ إضافة رابط "عرض التذكرة" للإشعارات من نوع ticket_reply
                              if (isTicketReply && notification.data?['ticket_id'] != null)
                                GestureDetector(
                                  onTap: () {
                                    final ticketId = notification.data?['ticket_id'];
                                    if (ticketId != null) {
                                      int? id = ticketId is int ? ticketId : int.tryParse(ticketId.toString());
                                      if (id != null && id > 0) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TicketDetailsScreen(
                                              ticketId: id,
                                              token: widget.token,
                                              onTicketUpdated: () {
                                                _loadNotifications();
                                                widget.onChanged();
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.link,
                                          size: 12,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'عرض التذكرة',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              
                              // مؤشر غير مقروء
                              if (!notification.isRead && !_isSelectionMode && !isTicketReply)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: type.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // علامة التحديد
            if (isSelected)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: type.color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_selectedIds.length} إشعار محدد',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_selectedIds.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.mark_email_read, color: Colors.blue),
                onPressed: _markSelectedAsRead,
                tooltip: 'تعليم كمقروء',
              ),
              IconButton(
                icon: const Icon(Icons.mark_email_unread, color: Colors.orange),
                onPressed: _markSelectedAsUnread,
                tooltip: 'تعليم كغير مقروء',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteSelected,
                tooltip: 'حذف',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_isLoading || _error != null || getFilteredNotifications().isEmpty) {
      return FloatingActionButton(
        onPressed: _loadNotifications,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.refresh),
      );
    }

    return FloatingActionButton.extended(
      onPressed: () {
        if (_isSelectionMode) {
          _clearSelection();
        } else {
          setState(() {
            _isSelectionMode = true;
          });
        }
      },
      icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
      label: Text(_isSelectionMode ? 'إلغاء' : 'تحديد'),
      backgroundColor: _isSelectionMode ? Colors.red : Colors.blue.shade700,
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل الإشعارات...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    String message;
    IconData icon;
    Color color;

    switch (_tabController.index) {
      case 1:
        message = _searchQuery.isNotEmpty
            ? 'لا توجد نتائج للبحث في الإشعارات غير المقروءة'
            : 'لا توجد إشعارات غير مقروءة';
        icon = _searchQuery.isNotEmpty ? Icons.search_off : Icons.mark_email_read;
        color = Colors.green;
        break;
      case 2:
        message = _searchQuery.isNotEmpty
            ? 'لا توجد نتائج للبحث في الإشعارات المقروءة'
            : 'لا توجد إشعارات مقروءة';
        icon = _searchQuery.isNotEmpty ? Icons.search_off : Icons.drafts;
        color = Colors.orange;
        break;
      default:
        message = _searchQuery.isNotEmpty
            ? 'لا توجد نتائج للبحث'
            : 'لا توجد إشعارات';
        icon = _searchQuery.isNotEmpty ? Icons.search_off : Icons.notifications_off;
        color = _searchQuery.isNotEmpty ? Colors.orange : Colors.blue;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: color.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: const Icon(Icons.clear),
              label: const Text('مسح البحث'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.grey[800]! : Colors.white;
    
    final filteredNotifications = getFilteredNotifications();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: _isSelectionMode
              ? Text('${_selectedIds.length} محدد')
              : const Text('الإشعارات'),
          bottom: _isSelectionMode
              ? null
              : TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications, size: 18),
                          const SizedBox(width: 4),
                          Text('الكل (${_allNotifications.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.mark_email_read, size: 18),
                          const SizedBox(width: 4),
                          Text('غير مقروءة (${_unreadNotifications.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.drafts, size: 18),
                          const SizedBox(width: 4),
                          Text('مقروءة (${_readNotifications.length})'),
                        ],
                      ),
                    ),
                  ],
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  onTap: (index) {
                    setState(() {});
                  },
                ),
          actions: _buildAppBarActions(),
        ),
        
        body: Container(
          color: backgroundColor,
          child: Column(
            children: [
              if (!_isSelectionMode) _buildSearchBar(),
              
              if (filteredNotifications.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${_getTabName()} - ${filteredNotifications.length} إشعار',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              
              Expanded(
                child: _isLoading
                    ? _buildLoadingWidget()
                    : _error != null
                        ? _buildErrorWidget()
                        : filteredNotifications.isEmpty
                            ? _buildEmptyWidget()
                            : _buildNotificationsList(cardColor, filteredNotifications),
              ),
            ],
          ),
        ),
        
        bottomNavigationBar: _isSelectionMode ? _buildSelectionBar() : null,
        
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }
}