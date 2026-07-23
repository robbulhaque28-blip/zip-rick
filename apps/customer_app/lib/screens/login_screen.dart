import 'package:flutter/material.dart';
import '../services/api_service.dart';

final ApiService _api = ApiService();

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: "+91");
  final _otpCtrl = TextEditingController();
  bool _otpSent = false, _loading = false;
  String _error = "";

  @override void dispose() { _phoneCtrl.dispose(); _otpCtrl.dispose(); super.dispose(); }

  Future<void> _sendOTP() async {
    setState(() { _loading = true; _error = ""; });
    try { final r = await _api.sendOTP(_phoneCtrl.text); if (r["success"]) setState(() => _otpSent = true); else setState(() => _error = r["error"]?["message"] ?? "Failed"); }
    catch (e) { setState(() => _error = "Cannot connect"); }
    setState(() => _loading = false);
  }

  Future<void> _verifyOTP() async {
    setState(() { _loading = true; _error = ""; });
    try {
      final r = await _api.verifyOTP(_phoneCtrl.text, _otpCtrl.text, "", "customer");
      if (r["success"]) { if (!mounted) return; Navigator.pushReplacementNamed(context, "/home"); }
      else { setState(() { _error = r["error"]?["message"] ?? "Failed"; }); if (_error.contains("Name") || _error.contains("found")) _error = "Account not found. Please Register."; }
    } catch (e) { setState(() => _error = "Cannot connect"); }
    setState(() => _loading = false);
  }

  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 80),
    Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle), child: Text("V", style: TextStyle(color: Color(0xFF6C63FF), fontSize: 36, fontWeight: FontWeight.bold))),
    const SizedBox(height: 24), const Text("Welcome Back", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
    const SizedBox(height: 8), const Text("Login to your account", style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16)),
    const SizedBox(height: 40),
    TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Phone", prefixIcon: const Icon(Icons.phone_android), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    if (_otpSent) ...[const SizedBox(height: 16), TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: "OTP", prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))],
    if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(_error, style: const TextStyle(color: Colors.red)))),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_otpSent ? "Verify OTP" : "Send OTP", style: const TextStyle(fontSize: 16)))),
  ]))));
}
