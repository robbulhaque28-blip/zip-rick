import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

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
    try {
      final r = await _api.sendOTP(_phoneCtrl.text);
      if (r["success"]) { setState(() => _otpSent = true); }
      else { setState(() => _error = r["error"]?["message"] ?? "Failed"); }
    } catch (e) { setState(() => _error = "Cannot connect"); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _verifyOTP() async {
    setState(() { _loading = true; _error = ""; });
    try {
      final r = await _api.verifyOTP(_phoneCtrl.text, _otpCtrl.text, "", "customer");
      if (r["success"]) {
        try { await FirebaseService.registerTokenAfterLogin(); } catch (_) {}
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, "/home");
      } else {
        setState(() { _error = r["error"]?["message"] ?? "Failed"; });
        if (_error.contains("Name") || _error.contains("found")) _error = "Account not found. Please Register.";
      }
    } catch (e) { setState(() => _error = "Cannot connect"); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0, leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context))),
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: VybeFadeIn(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(19)),
          child: const Icon(Icons.electric_rickshaw_rounded, size: 29, color: AppColors.primary),
        ),
        const SizedBox(height: 22),
        Text(_otpSent ? "Enter the code" : "Welcome back", style: AppText.h1),
        const SizedBox(height: 7),
        Text(
          _otpSent ? "We sent a 6-digit code to ${_phoneCtrl.text}" : "Log in to book your next ride",
          style: AppText.body.copyWith(fontSize: 14.5),
        ),
        const SizedBox(height: 30),
        Text("PHONE NUMBER", style: AppText.tiny),
        const SizedBox(height: 7),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          enabled: !_otpSent,
          style: AppText.bodyStrong.copyWith(fontSize: 15),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_android_rounded, size: 19), hintText: "+91"),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 18),
          Text("VERIFICATION CODE", style: AppText.tiny),
          const SizedBox(height: 7),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: AppText.h2.copyWith(letterSpacing: 9),
            decoration: const InputDecoration(counterText: "", hintText: "······"),
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: TextButton(
            onPressed: _loading ? null : () { setState(() { _otpSent = false; _otpCtrl.clear(); _error = ""; }); },
            child: Text("Change number", style: AppText.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          )),
        ],
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.07), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.danger.withOpacity(0.22))),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
              const SizedBox(width: 9),
              Expanded(child: Text(_error, style: AppText.body.copyWith(color: AppColors.danger, fontSize: 13))),
            ]),
          ),
        ],
        const SizedBox(height: 26),
        VybeButton(
          label: _otpSent ? "Verify & continue" : "Send code",
          loading: _loading,
          onPressed: _otpSent ? _verifyOTP : _sendOTP,
        ),
        const SizedBox(height: 16),
        Center(child: TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context, "/register"),
          child: Text.rich(TextSpan(
            text: "New to Vybe?  ",
            style: AppText.body.copyWith(fontSize: 13.5),
            children: [TextSpan(text: "Create an account", style: AppText.bodyStrong.copyWith(color: AppColors.primary, fontSize: 13.5))],
          )),
        )),
      ])),
    )),
  );
}
