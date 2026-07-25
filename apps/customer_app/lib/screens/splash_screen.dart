import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() { super.initState(); _check(); }
  @override void dispose() { _c.dispose(); super.dispose(); }

  Future<void> _check() async {
    await Future.delayed(const Duration(seconds: 2));
    final token = await ApiService().getToken();
    if (token != null && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primary,
    body: Center(child: FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween(begin: 0.88, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(28)),
            child: const Icon(Icons.electric_rickshaw_rounded, size: 46, color: Colors.white),
          ),
          const SizedBox(height: 22),
          Text("Vybe", style: AppText.h1.copyWith(color: Colors.white, fontSize: 30)),
          const SizedBox(height: 6),
          Text("Your E-Rickshaw, Instantly", style: AppText.body.copyWith(color: Colors.white.withOpacity(0.72))),
          const SizedBox(height: 52),
          SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white.withOpacity(0.85)),
          ),
        ]),
      ),
    )),
  );
}
