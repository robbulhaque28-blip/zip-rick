import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: '+91');
  final _nameCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _loading = false, _showOtp = false, _isRegister = true;
  String _errorMsg = '';

  Future<void> _sendOtp() async {
    if (_isRegister && _nameCtrl.text.trim().isEmpty) { setState(() => _errorMsg = 'Enter your full name'); return; }
    if (_phoneCtrl.text.trim().length < 10) { setState(() => _errorMsg = 'Valid phone required'); return; }
    setState(() { _loading = true; _errorMsg = ''; });
    try { await ApiService.sendOtp(_phoneCtrl.text.trim()); setState(() { _showOtp = true; _loading = false; }); }
    catch (e) { setState(() { _errorMsg = e.toString().replaceFirst('Exception: ', ''); _loading = false; }); }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length < 4) { setState(() => _errorMsg = 'Enter OTP'); return; }
    setState(() { _loading = true; _errorMsg = ''; });
    try {
      if (_isRegister) {
        final res = await ApiService.verifyOtp(_phoneCtrl.text.trim(), _otpCtrl.text.trim(), fullName: _nameCtrl.text.trim(), role: 'driver');
        final d = res['data'];
        if (d != null && d['tokens'] != null && d['tokens']['accessToken'] != null) {
          await ApiService.saveToken(d['tokens']['accessToken']);
          if (mounted) Navigator.pushReplacementNamed(context, '/register-docs');
        } else { setState(() { _errorMsg = 'Registration failed'; _loading = false; }); }
      } else {
        try {
          final res = await ApiService.verifyOtp(_phoneCtrl.text.trim(), _otpCtrl.text.trim(), role: 'driver');
          final d = res['data'];
          if (d != null && d['tokens'] != null && d['tokens']['accessToken'] != null) {
            await ApiService.saveToken(d['tokens']['accessToken']);
            if (mounted) Navigator.pushReplacementNamed(context, '/home');
          } else { setState(() { _errorMsg = 'Account not found. Register?'; _loading = false; }); }
        } catch (_) { setState(() { _errorMsg = 'Account not found. Register?'; _loading = false; }); }
      }
    } catch (e) { setState(() { _errorMsg = e.toString().replaceFirst('Exception: ', ''); _loading = false; }); }
  }

  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 30),
      Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle),
        child: const Text("V", style: TextStyle(color: Color(0xFF6C63FF), fontSize: 36, fontWeight: FontWeight.bold))),
      const SizedBox(height: 24),
      if (!_showOtp) Container(
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: GestureDetector(onTap: () => setState(() { _isRegister = false; _errorMsg = ''; }),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: _isRegister ? Colors.transparent : Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text('Login', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: _isRegister ? const Color(0xFF9CA3AF) : const Color(0xFF6C63FF)))))),
          Expanded(child: GestureDetector(onTap: () => setState(() { _isRegister = true; _errorMsg = ''; }),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: _isRegister ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: Text('Register', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: _isRegister ? const Color(0xFF6C63FF) : const Color(0xFF9CA3AF)))))),
        ])),
      const SizedBox(height: 24),
      Text(_showOtp ? 'Verify OTP' : (_isRegister ? 'Register as Driver' : 'Driver Login'),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      const SizedBox(height: 8),
      Text(_showOtp ? 'Enter OTP sent to your phone' : (_isRegister ? 'Step 1 of 4' : 'Enter your phone to login'),
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15)),
      const SizedBox(height: 24),
      if (!_showOtp && _isRegister) ...[
        TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Full Name *', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 16),
      ],
      TextField(controller: _phoneCtrl, enabled: !_showOtp, keyboardType: TextInputType.phone,
        decoration: InputDecoration(labelText: 'Phone Number', prefixIcon: const Icon(Icons.phone_android), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      if (_showOtp) ...[const SizedBox(height: 16),
        TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6,
          decoration: InputDecoration(labelText: 'OTP', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      ],
      if (_errorMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _loading ? null : (_showOtp ? _verifyOtp : _sendOtp),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_showOtp ? 'Verify & Continue' : 'Send OTP', style: const TextStyle(fontSize: 16)))),
    ]))));
  @override void dispose() { _phoneCtrl.dispose(); _nameCtrl.dispose(); _otpCtrl.dispose(); super.dispose(); }
}
