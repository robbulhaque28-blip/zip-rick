import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = false, _success = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      await ApiService.payRegistrationFee(amount: 499);
      setState(() => _success = true);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment failed: ${e.toString().replaceFirst("Exception: ", "")}')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registration Fee')),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
      VybeFadeIn(child: Row(children: [
        Expanded(child: _Step(n: '1', label: 'Details', done: true)),
        Expanded(child: _Step(n: '2', label: 'Docs', done: true)),
        Expanded(child: _Step(n: '3', label: 'Terms', done: true)),
        Expanded(child: _Step(n: '4', label: 'Payment', active: true)),
      ])),
      const SizedBox(height: 28),
      Center(child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 78, height: 78,
        decoration: BoxDecoration(
          color: (_success ? AppColors.success : AppColors.primary).withOpacity(0.11),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(_success ? Icons.check_rounded : Icons.account_balance_wallet_rounded,
          size: 38, color: _success ? AppColors.success : AppColors.primary),
      )),
      const SizedBox(height: 20),
      Center(child: Text(_success ? 'Payment successful' : 'One-time registration fee', style: AppText.h2, textAlign: TextAlign.center)),
      const SizedBox(height: 6),
      Center(child: Text(
        _success ? 'Setting up your account...' : 'Pay once to activate your driver account',
        style: AppText.body.copyWith(fontSize: 13.5), textAlign: TextAlign.center)),
      const SizedBox(height: 26),
      VybeFadeIn(delayMs: 80, child: VybeCard(
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          Text('AMOUNT DUE', style: AppText.tiny),
          const SizedBox(height: 8),
          Text('Rs 499', style: AppText.h1.copyWith(fontSize: 34, color: AppColors.primary)),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _row('Registration fee', 'Rs 499'),
          const SizedBox(height: 7),
          _row('Platform charges', 'Rs 0'),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _row('Total', 'Rs 499', bold: true),
        ]),
      )),
      const SizedBox(height: 16),
      VybeFadeIn(delayMs: 130, child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warning.withOpacity(0.25))),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 17, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(child: Text('This fee is non-refundable once your account is activated.',
            style: AppText.body.copyWith(fontSize: 12.5, color: AppColors.body))),
        ]),
      )),
      const SizedBox(height: 24),
      if (!_success) VybeButton(label: 'Pay Rs 499 now', icon: Icons.lock_rounded, loading: _loading, onPressed: _pay)
      else Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.11), borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 19),
          const SizedBox(width: 9),
          Text('Payment successful', style: AppText.button.copyWith(color: AppColors.success)),
        ]),
      ),
    ]),
  );

  Widget _row(String l, String v, {bool bold = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(l, style: bold ? AppText.bodyStrong.copyWith(fontSize: 14) : AppText.body.copyWith(fontSize: 13)),
      Text(v, style: bold ? AppText.price.copyWith(fontSize: 17) : AppText.bodyStrong.copyWith(fontSize: 13)),
    ],
  );
}

class _Step extends StatelessWidget {
  final String n; final String label; final bool active; final bool done;
  const _Step({required this.n, required this.label, this.active = false, this.done = false});
  @override
  Widget build(BuildContext context) {
    final Color bg = done ? AppColors.success : (active ? AppColors.primary : AppColors.canvas);
    final Color fg = (done || active) ? Colors.white : AppColors.muted;
    return Column(children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9),
          border: (done || active) ? null : Border.all(color: AppColors.line)),
        child: Center(child: done
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : Text(n, style: AppText.tiny.copyWith(fontSize: 11, color: fg))),
      ),
      const SizedBox(height: 5),
      Text(label, style: AppText.label.copyWith(fontSize: 10.5,
        color: active ? AppColors.primary : (done ? AppColors.success : AppColors.muted))),
    ]);
  }
}
