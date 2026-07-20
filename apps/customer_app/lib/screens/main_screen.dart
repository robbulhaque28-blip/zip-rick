import 'package:flutter/material.dart';
import 'home_page.dart';
import 'ride_history_page.dart';
import 'profile_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override State<MainScreen> createState() => _MainScreenState();
}
class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  @override Widget build(BuildContext context) => Scaffold(
    body: [const HomePage(), const RideHistoryPage(), const ProfilePage()][_tab],
    bottomNavigationBar: Container(
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: BottomNavigationBar(currentIndex: _tab, onTap: (i) => setState(() => _tab = i),
        selectedItemColor: const Color(0xFF6C63FF), unselectedItemColor: const Color(0xFF9CA3AF),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: "Rides"),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
        ])));
}
