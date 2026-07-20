import 'package:flutter/material.dart';
import '../services/api_service.dart';

final ApiService _api = ApiService();

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneCtrl = TextEditingController(text: "+91");
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _otpSent = false, _loading = false;
  String _error = "";

  @override void dispose() { _phoneCtrl.dispose(); _otpCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _sendOTP() async {
    setState(() { _loading = true; _error = ""; });
    try { final r = await _api.sendOTP(_phoneCtrl.text); if (r["success"]) setState(() => _otpSent = true); else setState(() => _error = r["error"]?["message"] ?? "Failed"); }
    catch (e) { setState(() => _error = "Cannot connect"); }
    setState(() => _loading = false);
  }

  Future<void> _verifyOTP() async {
    if (_nameCtrl.text.trim().isEmpty) { setState(() => _error = "Name is required"); return; }
    setState(() { _loading = true; _error = ""; });
    try { final r = await _api.verifyOTP(_phoneCtrl.text, _otpCtrl.text, _nameCtrl.text, "customer"); if (r["success"]) { if (!mounted) return; Navigator.pushReplacementNamed(context, "/home"); } else { setState(() => _error = r["error"]?["message"] ?? "Failed"); } }
    catch (e) { setState(() => _error = "Cannot connect"); }
    setState(() => _loading = false);
  }

  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 80),
    Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_add, size: 40, color: Color(0xFF6C63FF))),
    const SizedBox(height: 24), const Text("Create Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
    const SizedBox(height: 8), const Text("Register as a new customer", style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16)),
    const SizedBox(height: 40),
    TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Phone", prefixIcon: const Icon(Icons.phone_android), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    if (_otpSent) ...[
      const SizedBox(height: 16), TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: "Full Name", prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 16), TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: "OTP", prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    ],
    if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(_error, style: const TextStyle(color: Colors.red)))),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_otpSent ? "Create Account" : "Send OTP", style: const TextStyle(fontSize: 16)))),
  ]))));
}
