import 'package:flutter/material.dart';
import '../community/community_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import '../services/services_screen.dart';
import 'home_dashboard.dart';

/// Shell that hosts the five primary bottom-navigation destinations.
/// Secondary pages (Property, Security, Authority, Chatbot, Notifications)
/// are pushed on top from the Home Dashboard's quick-access grid.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    HomeDashboard(),
    MapScreen(),
    ServicesScreen(),
    CommunityScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.handyman_outlined), activeIcon: Icon(Icons.handyman), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
