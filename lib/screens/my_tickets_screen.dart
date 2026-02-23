// lib/screens/my_tickets_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/ticket_model.dart';
import 'ticket_details_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  final String token;
  final Future<void> Function()? onRefreshUnread;

  const MyTicketsScreen({
    super.key,
    required this.token,
    this.onRefreshUnread,
  });

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String? _error;
  
  // متغيرات للبحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTickets();
    
    // إضافة مستمع لتغيير التبويب
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // تحديث الواجهة عند تغيير التبويب
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getMyTickets(widget.token);
      
      if (!mounted) return;

      if (response['ok'] == true) {
        final List<dynamic> items = response['items'] ?? [];
        setState(() {
          _tickets = items.map((json) => Ticket.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['error'] ?? 'فشل تحميل التذاكر';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'خطأ في الاتصال: $e';
        _isLoading = false;
      });
    }
  }

  // ✅ دالة تصفية التذاكر حسب التبويب المحدد
  List<Ticket> get _filteredTickets {
    // أولا: تصفية حسب التبويب
    List<Ticket> filteredByTab;
    
    switch (_tabController.index) {
      case 0: // الكل
        filteredByTab = _tickets;
        break;
      case 1: // المفتوحة
        filteredByTab = _tickets.where((t) => t.isOpen).toList();
        break;
      case 2: // المغلقة
        filteredByTab = _tickets.where((t) => t.isClosed).toList();
        break;
      default:
        filteredByTab = _tickets;
    }
    
    // ثانيا: تطبيق البحث إذا كان موجود
    if (_searchQuery.isNotEmpty) {
      return filteredByTab.where((ticket) {
        return ticket.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               ticket.type.displayName.contains(_searchQuery);
      }).toList();
    }
    
    return filteredByTab;
  }

  Future<void> _refreshData() async {
    await _loadTickets();
    if (widget.onRefreshUnread != null) {
      await widget.onRefreshUnread!();
    }
  }

  // فتح تفاصيل التذكرة في BottomSheet
  void _openTicketDetails(Ticket ticket) {
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
          child: TicketDetailsScreen(
            ticketId: ticket.id,
            token: widget.token,
            onTicketUpdated: _refreshData,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.grey[800]! : Colors.white;

    return Column(
      children: [
        // شريط التبويبات
        Container(
          color: Colors.blue.shade700,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'الكل'),
              Tab(text: 'مفتوحة'),
              Tab(text: 'مغلقة'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
          ),
        ),
        
        // شريط البحث
        _buildSearchBar(),
        
        // ✅ عرض عدد التذاكر في التبويب الحالي (اختياري)
        if (_filteredTickets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'عرض ${_filteredTickets.length} تذكرة',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        
        // قائمة التذاكر
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorWidget()
                  : _filteredTickets.isEmpty
                      ? _buildEmptyWidget()
                      : _buildTicketsList(cardColor),
        ),
      ],
    );
  }

  // شريط البحث
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'ابحث في التذاكر...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  // قائمة التذاكر
  Widget _buildTicketsList(Color cardColor) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.blue.shade700,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredTickets.length,
        itemBuilder: (context, index) {
          final ticket = _filteredTickets[index];
          return _buildTicketCard(ticket, cardColor);
        },
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket, Color cardColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: ticket.isOpen ? Colors.orange.shade200 : Colors.green.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openTicketDetails(ticket),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس البطاقة
              Row(
                children: [
                  // أيقونة النوع
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ticket.type.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      ticket.type.icon,
                      color: ticket.type.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // العنوان والتاريخ
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.type.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: ticket.type.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(ticket.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // حالة التذكرة
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ticket.isOpen
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ticket.isOpen ? Colors.orange : Colors.green,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      ticket.isOpen ? 'مفتوحة' : 'مغلقة',
                      style: TextStyle(
                        color: ticket.isOpen ? Colors.orange : Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // نص الرسالة
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ticket.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.5),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // عدد الردود
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.reply,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${ticket.repliesCount} ردود',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  if (ticket.replies.isNotEmpty)
                    Expanded(
                      child: Text(
                        'آخر رد: ${_formatTimeAgo(ticket.replies.last.createdAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // واجهة الخطأ
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
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // واجهة فارغة حسب التبويب
  Widget _buildEmptyWidget() {
    String message;
    IconData icon;
    Color color;

    switch (_tabController.index) {
      case 1: // المفتوحة
        message = _searchQuery.isNotEmpty
            ? 'لا توجد نتائج للبحث في التذاكر المفتوحة'
            : 'لا توجد تذاكر مفتوحة';
        icon = _searchQuery.isNotEmpty ? Icons.search_off : Icons.lock_open;
        color = Colors.orange;
        break;
      case 2: // المغلقة
        message = _searchQuery.isNotEmpty
            ? 'لا توجد نتائج للبحث في التذاكر المغلقة'
            : 'لا توجد تذاكر مغلقة';
        icon = _searchQuery.isNotEmpty ? Icons.search_off : Icons.check_circle;
        color = Colors.green;
        break;
      default: // الكل
        message = _searchQuery.isNotEmpty
            ? 'لا توجد نتائج للبحث'
            : 'لا توجد تذاكر بعد';
        icon = _searchQuery.isNotEmpty ? Icons.search_off : Icons.confirmation_number;
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

  // دوال مساعدة للتاريخ
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }
}