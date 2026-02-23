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
  bool sending = false;

  Future<void> submit() async {
    if (controller.text.trim().isEmpty) return;

    setState(() => sending = true);

    final res = await ApiService.createTicket(
      token: widget.token,
      type: widget.type,
      message: controller.text.trim(),
    );

    if (!mounted) return;

    setState(() => sending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res["ok"] == true
              ? "تم إرسال الطلب بنجاح"
              : "فشل إرسال الطلب",
        ),
      ),
    );

    if (res["ok"] == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.type == "renew" ? "طلب تجديد" : "تذكرة دعم";

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: "اكتب رسالتك هنا...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: sending ? null : submit,
                  child: sending
                      ? const CircularProgressIndicator(color: Colors.white)
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
