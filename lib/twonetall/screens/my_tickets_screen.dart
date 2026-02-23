import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MyTicketsScreen extends StatefulWidget {
  final String token;
  const MyTicketsScreen({super.key, required this.token});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  bool loading = true;
  List tickets = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final res = await ApiService.getMyTickets(widget.token);
    if (res["ok"] == true) {
      setState(() {
        tickets = res["items"];
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case "open":
        return Colors.orange;
      case "closed":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text("تذاكري")),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : tickets.isEmpty
                ? const Center(child: Text("لا توجد تذاكر"))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: tickets.length,
                    itemBuilder: (_, i) {
                      final t = tickets[i];
                      return Card(
                        child: ListTile(
                          title: Text(t["subject"]),
                          subtitle: Text(t["last_message"]),
                          trailing: Text(
                            t["status"],
                            style: TextStyle(
                              color: statusColor(t["status"]),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
