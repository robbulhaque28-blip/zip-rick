import 'package:flutter/material.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});
  @override State<TermsScreen> createState() => _TermsScreenState();
}
class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Terms & Conditions')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: const Text('Step 3 of 4', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold))),
      const SizedBox(height: 16),
      const Text('Terms & Conditions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _t('1. Services'), _d('I agree to provide e-rickshaw ride services through the Vybe platform.'),
          _t('2. Background Check'), _d('I authorize Vybe to verify my documents.'),
          _t('3. Commission'), _d('I agree to pay 10% commission on each ride fare to Vybe.'),
          _t('4. Conduct'), _d('I will maintain professional conduct with passengers.'),
          _t('5. Cancellation'), _d('Excessive cancellations may result in account suspension.'),
          _t('6. Fees'), _d('The registration fee of ₹499 is non-refundable.'),
          _t('7. Compliance'), _d('I will comply with all local traffic rules and regulations.'),
          _t('8. Data'), _d('I consent to location data collection for ride tracking.'),
        ])),
      const SizedBox(height: 20),
      CheckboxListTile(value: _agreed, dense: true, onChanged: (v) => setState(() => _agreed = v ?? false),
        title: const Text('I agree to all terms and conditions', style: TextStyle(fontSize: 14)),
        controlAffinity: ListTileControlAffinity.leading),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _agreed ? () => Navigator.pushReplacementNamed(context, '/payment') : null,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('Agree & Continue', style: TextStyle(fontSize: 16)))),
    ])));
  Widget _t(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937))));
  Widget _d(String d) => Text(d, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14));
}
