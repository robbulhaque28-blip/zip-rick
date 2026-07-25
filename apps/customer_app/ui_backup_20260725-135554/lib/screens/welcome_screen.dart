import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(flex: 3),
        Container(
          width: 78, height: 78,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.electric_rickshaw_rounded, size: 38, color: Colors.white),
        ),
        const SizedBox(height: 28),
        Text("Get moving\nwith Vybe", style: AppText.h1.copyWith(fontSize: 33, height: 1.22)),
        const SizedBox(height: 12),
        Text(
          "Book an e-rickshaw in seconds. Fair fares,\nverified drivers, live tracking.",
          style: AppText.body.copyWith(fontSize: 15, height: 1.55),
        ),
        const Spacer(flex: 2),
        Row(children: [
          _Feat(icon: Icons.bolt_rounded, label: "Quick\npickup"),
          const SizedBox(width: 10),
          _Feat(icon: Icons.verified_user_rounded, label: "Verified\ndrivers"),
          const SizedBox(width: 10),
          _Feat(icon: Icons.currency_rupee_rounded, label: "Upfront\nfares"),
        ]),
        const SizedBox(height: 30),
        SizedBox(width: double.infinity, height: 53, child: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, "/login"),
          child: Text("Login", style: AppText.button.copyWith(color: Colors.white, fontSize: 15.5)),
        )),
        const SizedBox(height: 11),
        SizedBox(width: double.infinity, height: 53, child: OutlinedButton(
          onPressed: () => Navigator.pushNamed(context, "/register"),
          child: Text("Create an account", style: AppText.button.copyWith(fontSize: 15.5)),
        )),
        const SizedBox(height: 26),
      ]),
    )),
  );
}

class _Feat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feat({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 15),
    decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
    child: Column(children: [
      Icon(icon, color: AppColors.primary, size: 21),
      const SizedBox(height: 8),
      Text(label, textAlign: TextAlign.center, style: AppText.label.copyWith(fontSize: 11.5, color: AppColors.body, height: 1.3)),
    ]),
  ));
}
