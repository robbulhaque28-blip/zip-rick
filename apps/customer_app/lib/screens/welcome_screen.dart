import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF6C63FF),
    body: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Spacer(flex: 2),
      Container(width: 120, height: 120, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(24)),
        child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/icon_square.png', width: 100, height: 100, fit: BoxFit.contain))),
      const SizedBox(height: 24),
      const Text("Vybe", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 8),
      const Text("Your E-Rickshaw, Instantly", style: TextStyle(color: Colors.white70, fontSize: 16)),
      const Spacer(flex: 2),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: SizedBox(width: double.infinity, height: 56,
        child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, "/login"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: SizedBox(width: double.infinity, height: 56,
        child: OutlinedButton(onPressed: () => Navigator.pushNamed(context, "/register"),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text("Register", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
      const Spacer(flex: 1),
    ]))));
}
