import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});
  @override State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false;

  static const _terms = [
    ['Services', 'I agree to provide e-rickshaw ride services through the Vybe platform.'],
    ['Background check', 'I authorize Vybe to verify my documents.'],
    ['Commission', 'I agree to pay 10% commission on each ride fare to Vybe.'],
    ['Conduct', 'I will maintain professional conduct with passengers.'],
    ['Cancellation', 'Excessive cancellations may result in account suspension.'],
    ['Fees', 'The registration fee of Rs 499 is non-refundable.'],
    ['Compliance', 'I will comply with all local traffic rules and regulations.'],
    ['Data', 'I consent to location data collection for ride tracking.'],
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Terms & Conditions')),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
      VybeFadeIn(child: Row(children: [
        Expanded(child: _Step(n: '1', label: 'Details', done: true)),
        Expanded(child: _Step(n: '2', label: 'Docs', done: true)),
        Expanded(child: _Step(n: '3', label: 'Terms', active: true)),
        Expanded(child: _Step(n: '4', label: 'Payment')),
      ])),
      const SizedBox(height: 22),
      Text('Please read and accept', style: AppText.h2),
      const SizedBox(height: 6),
      Text('These terms cover how you work with Vybe as a driver partner.', style: AppText.body.copyWith(fontSize: 13.5)),
      const SizedBox(height: 16),
      ...List.generate(_terms.length, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: VybeFadeIn(delayMs: (i * 40).clamp(0, 300), child: VybeCard(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('${i + 1}', style: AppText.tiny.copyWith(color: AppColors.primary, fontSize: 11))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_terms[i][0], style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
              const SizedBox(height: 3),
              Text(_terms[i][1], style: AppText.body.copyWith(fontSize: 12.5, height: 1.4)),
            ])),
          ]),
        )),
      )),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => setState(() => _agreed = !_agreed),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _agreed ? AppColors.primarySoft.withOpacity(0.45) : AppColors.canvas,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: _agreed ? AppColors.primary : AppColors.line, width: _agreed ? 1.5 : 1),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: _agreed ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: _agreed ? null : Border.all(color: AppColors.muted, width: 1.6),
              ),
              child: _agreed ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('I agree to all terms and conditions', style: AppText.bodyStrong.copyWith(fontSize: 13.5))),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      VybeButton(
        label: 'Agree & continue',
        onPressed: _agreed ? () => Navigator.pushReplacementNamed(context, '/payment') : null,
      ),
    ]),
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
