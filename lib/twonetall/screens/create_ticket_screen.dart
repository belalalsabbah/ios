import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateTicketScreen extends StatefulWidget {
  final String token;
  final String type; // support | renew

  const CreateTicketScreen({
    super.key,
    required this.token,
    required this.type,
  });

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final ctrl = TextEditingController();
  bool sending = false;
  String? msg;

  Future<void> send() async {
    if (ctrl.text.trim().isEmpty) return;

    setState(() => sending = true);

    final res = await ApiService.createTicket(
      token: widget.token,
      type: widget.type,
      message: ctrl.text.trim(),
    );

    if (res["ok"] == true) {
      msg = "تم إرسال الطلب بنجاح";
      ctrl.clear();
    } else {
      msg = "فشل إرسال الطلب";
    }

    setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.type == "renew"
              ? "طلب تجديد"
              : "الدعم الفني"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: ctrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "اكتب رسالتك هنا...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: sending ? null : send,
                child: sending
                    ? const CircularProgressIndicator()
                    : const Text("إرسال"),
              ),
              if (msg != null) ...[
                const SizedBox(height: 12),
                Text(msg!),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
