import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TicketScreen extends StatefulWidget {
  final String token;
  final String type; // support | renew

  const TicketScreen({
    super.key,
    required this.token,
    required this.type,
  });

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final controller = TextEditingController();
  final daysController = TextEditingController();

  bool sending = false;

  Future<void> submit() async {
    if (sending) return;

    if (widget.type == "renew") {
      if (daysController.text.trim().isEmpty) return;
    } else {
      if (controller.text.trim().isEmpty) return;
    }

    setState(() => sending = true);

    try {
      late Map res;

      if (widget.type == "renew") {
        res = await ApiService.addDays(
          token: widget.token,
          days: daysController.text.trim(),
          notes: controller.text.trim(),
        );
      } else {
        res = await ApiService.createTicket(
          token: widget.token,
          type: widget.type,
          message: controller.text.trim(),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (res["success"] == true || res["ok"] == true)
                ? "✅ تم التنفيذ بنجاح"
                : "❌ ${res["message"] ?? "فشل التنفيذ"}",
          ),
        ),
      );

      if (res["success"] == true || res["ok"] == true) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ فشل الاتصال بالسيرفر")),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.type == "renew" ? "اضافة ايام" : "تذكرة دعم";

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (widget.type == "renew") ...[
                TextField(
                  controller: daysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: "عدد الأيام",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: widget.type == "renew"
                      ? "ملاحظات (اختياري)"
                      : "اكتب رسالتك هنا...",
                  border: const OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: sending ? null : submit,
                  child: sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("إرسال"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
