import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'status_screen.dart';
import 'notifications_screen.dart';
import 'ticket_screen.dart';

class MainNavigation extends StatefulWidget {
  final String token;
  const MainNavigation({super.key, required this.token});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;
  int unreadCount = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      StatusScreen(token: widget.token),
      NotificationsScreen(token: widget.token),
      TicketScreen(token: widget.token, type: 'support'),
    ];

    _loadUnread();
  }

  Future<void> _loadUnread() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      unreadCount = prefs.getInt("notifications_unread") ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          if (i == 1) {
            setState(() => unreadCount = 0);
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "الرئيسية",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: "الإشعارات",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.support_agent),
            label: "الدعم",
          ),
        ],
      ),
    );
  }
}
