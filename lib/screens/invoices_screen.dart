// lib/screens/invoices_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;  // ✅ استيراد كامل مع اسم مستعار
import '../services/api_service.dart';
import '../models/notification_model.dart';

class InvoicesScreen extends StatefulWidget {
  final String token;
  final VoidCallback onChanged;

  const InvoicesScreen({
    super.key,
    required this.token,
    required this.onChanged,
  });

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> with TickerProviderStateMixin {
  List<AppNotification> _invoices = [];
  bool _isLoading = true;
  String? _error;
  
  // متغيرات البحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
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
          _invoices = items
              .map((json) => AppNotification.fromJson(json))
              .where((n) => n.type == NotificationType.renewed)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          _isLoading = false;
        });
        
        widget.onChanged();
      } else {
        setState(() {
          _error = response['error'] ?? 'فشل تحميل الفواتير';
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

  List<AppNotification> get _filteredInvoices {
    if (_searchQuery.isEmpty) return _invoices;
    
    return _invoices.where((invoice) {
      final data = invoice.data ?? {};
      final invoiceNumber = data['invoice_number']?.toString().toLowerCase() ?? '';
      final subscriberName = data['subscriber_name']?.toString().toLowerCase() ?? '';
      final amount = data['total_amount']?.toString() ?? '';
      
      return invoiceNumber.contains(_searchQuery.toLowerCase()) ||
             subscriberName.contains(_searchQuery.toLowerCase()) ||
             amount.contains(_searchQuery);
    }).toList();
  }

  Future<void> _refreshData() async {
    await _loadInvoices();
  }

  void _openInvoiceDetails(AppNotification invoice) {
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
          child: _InvoiceDetailsContent(
            invoice: invoice,
            scrollController: controller,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    return Directionality(
     textDirection: ui.TextDirection.rtl,  // ✅ استخدام ui.TextDirection
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الفواتير'),
          elevation: 0,
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          actions: [
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
              onPressed: _loadInvoices,
            ),
          ],
        ),
        body: Container(
          color: backgroundColor,
          child: Column(
            children: [
              if (_isSearching) _buildSearchBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingWidget()
                    : _error != null
                        ? _buildErrorWidget()
                        : _filteredInvoices.isEmpty
                            ? _buildEmptyWidget()
                            : _buildInvoicesList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'ابحث برقم الفاتورة أو اسم المشترك...',
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

  Widget _buildInvoicesList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.green.shade700,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredInvoices.length,
        itemBuilder: (context, index) {
          final invoice = _filteredInvoices[index];
          return _buildInvoiceCard(invoice);
        },
      ),
    );
  }

  Widget _buildInvoiceCard(AppNotification invoice) {
    final data = invoice.data ?? {};
    
    String periodText = data['period_text'] ?? '---';
    if (periodText.contains('يوم')) {
      final daysMatch = RegExp(r'(\d+)').firstMatch(periodText);
      if (daysMatch != null) {
        final days = int.parse(daysMatch.group(1)!);
        final months = (days / 30).ceil();
        periodText = '$months شهر';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => _openInvoiceDetails(invoice),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس البطاقة
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'فاتورة تجديد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['invoice_number']?.toString() ?? '---',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      '${data['total_amount'] ?? '0'} ₪',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // تفاصيل الفاتورة
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'المشترك:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['subscriber_name']?.toString() ?? '---',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'المدة:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            periodText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'التاريخ:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDate(invoice.createdAt.toString()),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // مؤشرات إضافية
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.visibility, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'اضغط للتفاصيل',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
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

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل الفواتير...',
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
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadInvoices,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.green.shade200),
          const SizedBox(height: 16),
          const Text(
            'لا توجد فواتير بعد',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'عند تجديد اشتراكك، ستظهر الفواتير هنا',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      if (dateStr.isEmpty) return '---';
      final date = DateTime.parse(dateStr);
      return '${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return dateStr;
    }
  }
}

// ============================================================
// شاشة تفاصيل الفاتورة (بنفس تصميم notification_details_screen)
// ============================================================
class _InvoiceDetailsContent extends StatelessWidget {
  final AppNotification invoice;
  final ScrollController scrollController;

  const _InvoiceDetailsContent({
    required this.invoice,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final data = invoice.data ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
     textDirection: ui.TextDirection.rtl,  // ✅ استخدام ui.TextDirection
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الفاتورة'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس الفاتورة
              _buildHeader(isDark, data),
              
              const SizedBox(height: 20),
              
              // رسالة الترحيب
              _buildWelcomeMessage(data),
              
              const SizedBox(height: 20),
              
              // بطاقة الفاتورة الرئيسية
              _buildMainInvoiceCard(context, data),
              
              const SizedBox(height: 20),
              
              // فترة الاشتراك
              if (data['old_expiry'] != null || data['new_expiry'] != null)
                _buildPeriodCard(data),
              
              const SizedBox(height: 20),
              
              // معلومات إضافية
              _buildAdditionalInfo(context, isDark, data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long,
              size: 50,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              'فاتورة تجديد',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data['invoice_number']?.toString() ?? '---',
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

  Widget _buildWelcomeMessage(Map<String, dynamic> data) {
    String periodText = data['period_text'] ?? '---';
    if (periodText.contains('يوم')) {
      final daysMatch = RegExp(r'(\d+)').firstMatch(periodText);
      if (daysMatch != null) {
        final days = int.parse(daysMatch.group(1)!);
        final months = (days / 30).ceil();
        periodText = '$months شهر';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration, size: 24, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '🎉 تم تجديد اشتراكك بنجاح\n'
              '🧾 رقم الفاتورة: ${data['invoice_number'] ?? '---'}\n'
              '💰 المبلغ: ${data['total_amount'] ?? '---'} شيكل\n'
              '📅 مدة الاشتراك: $periodText',
              style: TextStyle(
                color: Colors.green.shade700,
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

  Widget _buildMainInvoiceCard(BuildContext context, Map<String, dynamic> data) {
    String periodText = data['period_text'] ?? '---';
    if (periodText.contains('يوم')) {
      final daysMatch = RegExp(r'(\d+)').firstMatch(periodText);
      if (daysMatch != null) {
        final days = int.parse(daysMatch.group(1)!);
        final months = (days / 30).ceil();
        periodText = '$months شهر';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.white,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان الفاتورة
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    size: 40,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'فاتورة تجديد اشتراك',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // معلومات الفاتورة
          _buildInfoItem(Icons.numbers, 'رقم الفاتورة', data['invoice_number']?.toString() ?? '---'),
          _buildInfoItem(Icons.person, 'المشترك', data['subscriber_name']?.toString() ?? '---'),
          _buildInfoItem(Icons.price_check, 'المبلغ', '${data['total_amount'] ?? '---'} شيكل'),
          _buildInfoItem(Icons.calendar_month, 'مدة الاشتراك', periodText),
          _buildInfoItem(Icons.date_range, 'تاريخ الفاتورة', _formatDate2(data['invoice_date'] ?? '')),
          _buildInfoItem(Icons.admin_panel_settings, 'تم بواسطة', data['renewed_by']?.toString() ?? '---'),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'فترة الاشتراك',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatDate2(data['old_expiry']),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('من', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: Colors.blue.shade700),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatDate2(data['new_expiry']),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const Text('إلى', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo(BuildContext context, bool isDark, Map<String, dynamic> data) {
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
            'تاريخ الإصدار',
            _formatDate2(data['invoice_date'] ?? ''),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.category,
            'الكمية',
            '${data['quantity'] ?? '1'}',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.price_change,
            'سعر الوحدة',
            '${data['price'] ?? '0'} شيكل',
          ),
        ],
      ),
    );
  }

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

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
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
              color: isDark ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate2(String dateStr) {
    if (dateStr.isEmpty) return '---';
    try {
      if (dateStr.contains(' ')) dateStr = dateStr.split(' ')[0];
      final date = DateTime.parse(dateStr);
      return '${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return dateStr;
    }
  }
}