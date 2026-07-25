import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}')));
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registration Fee')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: const Text('Step 4 of 4', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold))),
      const SizedBox(height: 24),
      Container(width: 100, height: 100, decoration: BoxDecoration(color: (_success ? const Color(0xFF4CAF50) : const Color(0xFF6C63FF)).withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(_success ? Icons.check_circle : Icons.payment, size: 48, color: _success ? const Color(0xFF4CAF50) : const Color(0xFF6C63FF))),
      const SizedBox(height: 24),
      const Text('One-Time Registration Fee', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      const SizedBox(height: 8),
      const Text('Pay ₹499 to complete your registration', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16)),
      const SizedBox(height: 32),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(children: [
          const Text('Amount Due', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
          const SizedBox(height: 8),
          const Text('₹499', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          const Divider(height: 32),
          _r('Registration Fee', '₹499'),
          _r('Total', '₹499', bold: true),
        ])),
      const SizedBox(height: 32),
      if (_success)
        const Column(children: [Icon(Icons.check_circle, size: 64, color: Color(0xFF4CAF50)), SizedBox(height: 12), Text('Payment Successful!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)))])
      else
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
          onPressed: _loading ? null : _pay,
          icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.payment),
          label: Text(_loading ? 'Processing...' : 'Pay ₹499 Now', style: const TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ),
    ]))));
  Widget _r(String l, String v, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: TextStyle(color: const Color(0xFF9CA3AF), fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 18 : 16)),
  ]));
}
