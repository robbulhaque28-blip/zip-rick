import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

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

  @override void dispose() { _phoneCtrl.dispose(); _nameCtrl.dispose(); _otpCtrl.dispose(); super.dispose(); }

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
          await FirebaseService.registerTokenAfterLogin();
          if (mounted) Navigator.pushReplacementNamed(context, '/register-docs');
        } else { setState(() { _errorMsg = 'Registration failed'; _loading = false; }); }
      } else {
        try {
          final res = await ApiService.verifyOtp(_phoneCtrl.text.trim(), _otpCtrl.text.trim(), role: 'driver');
          final d = res['data'];
          if (d != null && d['tokens'] != null && d['tokens']['accessToken'] != null) {
            await ApiService.saveToken(d['tokens']['accessToken']);
            await FirebaseService.registerTokenAfterLogin();
            if (mounted) Navigator.pushReplacementNamed(context, '/home');
          } else { setState(() { _errorMsg = 'Account not found. Register?'; _loading = false; }); }
        } catch (_) { setState(() { _errorMsg = 'Account not found. Register?'; _loading = false; }); }
      }
    } catch (e) { setState(() { _errorMsg = e.toString().replaceFirst('Exception: ', ''); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: VybeFadeIn(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(19)),
          child: const Icon(Icons.electric_rickshaw_rounded, size: 29, color: AppColors.primary),
        ),
        const SizedBox(height: 22),
        Text(_showOtp ? 'Enter the code' : (_isRegister ? 'Become a driver' : 'Driver login'), style: AppText.h1),
        const SizedBox(height: 7),
        Text(
          _showOtp
            ? 'We sent a code to ${_phoneCtrl.text}'
            : (_isRegister ? 'Sign up and start earning with Vybe' : 'Log in to go online'),
          style: AppText.body.copyWith(fontSize: 14.5),
        ),
        const SizedBox(height: 24),
        if (!_showOtp) Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
          child: Row(children: [
            _Tab(label: 'Login', selected: !_isRegister, onTap: () => setState(() { _isRegister = false; _errorMsg = ''; })),
            _Tab(label: 'Register', selected: _isRegister, onTap: () => setState(() { _isRegister = true; _errorMsg = ''; })),
          ]),
        ),
        if (!_showOtp && _isRegister) ...[
          const SizedBox(height: 20),
          Text('FULL NAME', style: AppText.tiny),
          const SizedBox(height: 7),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: AppText.bodyStrong.copyWith(fontSize: 15),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded, size: 19), hintText: 'Your name'),
          ),
        ],
        const SizedBox(height: 18),
        Text('PHONE NUMBER', style: AppText.tiny),
        const SizedBox(height: 7),
        TextField(
          controller: _phoneCtrl,
          enabled: !_showOtp,
          keyboardType: TextInputType.phone,
          style: AppText.bodyStrong.copyWith(fontSize: 15),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_android_rounded, size: 19), hintText: '+91'),
        ),
        if (_showOtp) ...[
          const SizedBox(height: 18),
          Text('VERIFICATION CODE', style: AppText.tiny),
          const SizedBox(height: 7),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: AppText.h2.copyWith(letterSpacing: 9),
            decoration: const InputDecoration(counterText: '', hintText: '······'),
          ),
          Align(alignment: Alignment.centerRight, child: TextButton(
            onPressed: _loading ? null : () => setState(() { _showOtp = false; _otpCtrl.clear(); _errorMsg = ''; }),
            child: Text('Change number', style: AppText.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          )),
        ],
        if (_errorMsg.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.07), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.danger.withOpacity(0.22))),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
              const SizedBox(width: 9),
              Expanded(child: Text(_errorMsg, style: AppText.body.copyWith(color: AppColors.danger, fontSize: 13))),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        VybeButton(
          label: _showOtp ? 'Verify & continue' : 'Send code',
          loading: _loading,
          onPressed: _showOtp ? _verifyOtp : _sendOtp,
        ),
        if (!_showOtp && _isRegister) ...[
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: _Step(n: '1', label: 'Details', active: true)),
            Expanded(child: _Step(n: '2', label: 'Docs')),
            Expanded(child: _Step(n: '3', label: 'Terms')),
            Expanded(child: _Step(n: '4', label: 'Payment')),
          ]),
        ],
      ])),
    )),
  );
}

class _Tab extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _Tab({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: selected ? AppShadow.soft : null,
      ),
      child: Center(child: Text(label, style: AppText.button.copyWith(
        fontSize: 13.5, color: selected ? AppColors.primary : AppColors.muted))),
    ),
  ));
}

class _Step extends StatelessWidget {
  final String n; final String label; final bool active;
  const _Step({required this.n, required this.label, this.active = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 24, height: 24,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: active ? null : Border.all(color: AppColors.line),
      ),
      child: Center(child: Text(n, style: AppText.tiny.copyWith(
        fontSize: 11, color: active ? Colors.white : AppColors.muted))),
    ),
    const SizedBox(height: 5),
    Text(label, style: AppText.label.copyWith(fontSize: 10.5, color: active ? AppColors.primary : AppColors.muted)),
  ]);
}
