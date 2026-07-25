import 'package:flutter/material.dart';
import 'home_page.dart';
import 'ride_history_page.dart';
import 'profile_page.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _tab, children: const [HomePage(), RideHistoryPage(), ProfilePage()]),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, -3))],
      ),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          _NavItem(icon: Icons.explore_rounded, label: "Home", active: _tab == 0, onTap: () => setState(() => _tab = 0)),
          _NavItem(icon: Icons.receipt_long_rounded, label: "Rides", active: _tab == 1, onTap: () => setState(() => _tab = 1)),
          _NavItem(icon: Icons.person_rounded, label: "Profile", active: _tab == 2, onTap: () => setState(() => _tab = 2)),
        ]),
      )),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 23, color: active ? AppColors.primary : AppColors.muted),
        const SizedBox(height: 4),
        Text(label, style: AppText.label.copyWith(
          fontSize: 11.5,
          color: active ? AppColors.primary : AppColors.muted,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        )),
      ]),
    ),
  ));
}
