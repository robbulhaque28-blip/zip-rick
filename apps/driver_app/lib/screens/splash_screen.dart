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
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset('assets/icon_square.png', width: 120, height: 120, fit: BoxFit.contain),
      ),
      const SizedBox(height: 24), const Text('Vybe Driver', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
      const SizedBox(height: 60), const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
    ])));
}
