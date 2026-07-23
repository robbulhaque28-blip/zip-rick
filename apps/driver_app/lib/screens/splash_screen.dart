import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override void initState() { super.initState(); _check(); }
  Future<void> _check() async {
    await Future.delayed(const Duration(seconds: 2));
    final token = await ApiService.getToken();
    if (token != null && mounted) Navigator.pushReplacementNamed(context, '/home');
    else if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF6C63FF),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
        child: const Icon(Icons.electric_rickshaw_rounded, size: 50, color: Colors.white)),
      const SizedBox(height: 24), const Text('Vybe Driver', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
      const SizedBox(height: 60), const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
    ])));
}
