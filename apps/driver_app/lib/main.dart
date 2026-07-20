import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'services/api_service.dart';

class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF5A52D5);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFA726);
  static const bg = Color(0xFFF5F6FA);
  static const textLight = Color(0xFF9E9E9E);
}

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const ZipRickDriverApp()); }

class ZipRickDriverApp extends StatelessWidget {
  const ZipRickDriverApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Zip-Rick Driver', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.primary, scaffoldBackgroundColor: AppColors.bg),
    initialRoute: '/', routes: {
      '/': (ctx) => const SplashScreen(),
      '/login': (ctx) => const LoginScreen(),
      '/register-docs': (ctx) => const RegisterDocsScreen(),
      '/terms': (ctx) => const TermsScreen(),
      '/payment': (ctx) => const PaymentScreen(),
      '/home': (ctx) => const DriverHomeScreen(),
    },
  );
}

// ──── SPLASH SCREEN ────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() { super.initState(); _checkAuth(); }
  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    final token = await ApiService.getToken();
    if (token != null && mounted) Navigator.pushReplacementNamed(context, '/home');
    else if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.primary,
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.electric_rickshaw_rounded, size: 120, color: Colors.white),
      const SizedBox(height: 24),
      Text('Zip-Rick Driver', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      const SizedBox(height: 60), const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
    ])));
}

// ═══════════════════════════════════════════════════
// PAGE 1: LOGIN / REGISTRATION with Toggle
// ═══════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: '+91');
  final _nameCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _loading = false, _showOtp = false;
  bool _isRegister = true;
  String _errorMsg = '';

  Future<void> _sendOtp() async {
    if (_isRegister && _nameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Please enter your full name');
      return;
    }
    if (_phoneCtrl.text.trim().length < 10) {
      setState(() => _errorMsg = 'Valid phone number required');
      return;
    }
    setState(() { _loading = true; _errorMsg = ''; });
    try {
      await ApiService.sendOtp(_phoneCtrl.text.trim());
      setState(() { _showOtp = true; _loading = false; });
    } catch (e) {
      setState(() { _errorMsg = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length < 4) { setState(() => _errorMsg = 'Enter OTP'); return; }
    setState(() { _loading = true; _errorMsg = ''; });
    try {
      if (_isRegister) {
        // New registration: create account with name, go to docs
        final res = await ApiService.verifyOtp(_phoneCtrl.text.trim(), _otpCtrl.text.trim(), fullName: _nameCtrl.text.trim(), role: 'driver');
        final d = res['data'];
        if (d != null && d['tokens'] != null && d['tokens']['accessToken'] != null) {
          await ApiService.saveToken(d['tokens']['accessToken']);
          if (mounted) Navigator.pushReplacementNamed(context, '/register-docs');
        } else {
          setState(() { _errorMsg = 'Registration failed'; _loading = false; });
        }
      } else {
        // Existing user login: no name needed
        try {
          final res = await ApiService.verifyOtp(_phoneCtrl.text.trim(), _otpCtrl.text.trim(), role: 'driver');
          final d = res['data'];
          if (d != null && d['tokens'] != null && d['tokens']['accessToken'] != null) {
            await ApiService.saveToken(d['tokens']['accessToken']);
            if (mounted) Navigator.pushReplacementNamed(context, '/home');
          } else {
            setState(() { _errorMsg = 'Account not found. Please Register.'; _loading = false; });
          }
        } catch (_) {
          setState(() { _errorMsg = 'Account not found. Please Register.'; _loading = false; });
        }
      }
    } catch (e) {
      setState(() { _errorMsg = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 30),
        const Icon(Icons.electric_rickshaw_rounded, size: 64, color: AppColors.primary),
        const SizedBox(height: 24),
        // Toggle: Login / Register
        if (!_showOtp)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() { _isRegister = false; _errorMsg = ''; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isRegister ? Colors.transparent : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Login', textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold,
                      color: _isRegister ? AppColors.textLight : AppColors.primary)),
                ),
              )),
              Expanded(child: GestureDetector(
                onTap: () => setState(() { _isRegister = true; _errorMsg = ''; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isRegister ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Register', textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold,
                      color: _isRegister ? AppColors.primary : AppColors.textLight)),
                ),
              )),
            ]),
          ),
        const SizedBox(height: 24),
        Text(_showOtp ? 'Verify OTP' : (_isRegister ? 'Register as Driver' : 'Driver Login'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_showOtp ? 'Enter OTP sent to your phone' : (_isRegister ? 'Step 1 of 4' : 'Enter your phone to login'),
          style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
        const SizedBox(height: 24),
        // Name field - only for registration
        if (!_showOtp && _isRegister) ...[
          TextField(controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
          const SizedBox(height: 16),
        ],
        TextField(controller: _phoneCtrl, enabled: !_showOtp, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
        if (_showOtp) ...[
          const SizedBox(height: 16),
          TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6,
            decoration: const InputDecoration(labelText: 'OTP', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
        ],
        if (_errorMsg.isNotEmpty) ...[const SizedBox(height: 12), Text(_errorMsg, style: const TextStyle(color: Colors.red))],
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _loading ? null : (_showOtp ? _verifyOtp : _sendOtp),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(_showOtp ? 'Verify & Continue' : 'Send OTP', style: const TextStyle(fontSize: 16)))),
      ]),
    )));
  }
  @override
  void dispose() { _phoneCtrl.dispose(); _nameCtrl.dispose(); _otpCtrl.dispose(); super.dispose(); }
}

// ═══════════════════════════════════════════════════
// PAGE 2: DOCUMENTS + BANK ACCOUNT
// ═══════════════════════════════════════════════════
class RegisterDocsScreen extends StatefulWidget {
  const RegisterDocsScreen({super.key});
  @override
  State<RegisterDocsScreen> createState() => _RegisterDocsScreenState();
}
class _RegisterDocsScreenState extends State<RegisterDocsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  Map<String, XFile?> _docs = {'aadhaar_front': null, 'aadhaar_back': null, 'selfie': null, 'rc': null, 'insurance': null};
  final _bankNameCtrl = TextEditingController();
  final _acctHolderCtrl = TextEditingController();
  final _acctNumCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();

  String _label(String k) {
    switch (k) {
      case 'aadhaar_front': return 'Aadhaar Card (Front)';
      case 'aadhaar_back': return 'Aadhaar Card (Back)';
      case 'selfie': return 'Live Passport Photo';
      case 'rc': return 'Vehicle RC';
      case 'insurance': return 'Vehicle Insurance';
      default: return k;
    }
  }
  IconData _icon(String k) {
    switch (k) {
      case 'aadhaar_front': return Icons.badge;
      case 'aadhaar_back': return Icons.badge;
      case 'selfie': return Icons.camera_alt;
      case 'rc': return Icons.directions_car;
      case 'insurance': return Icons.verified;
      default: return Icons.upload_file;
    }
  }

  Future<void> _pickImage(String key) async {
    final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
    if (x != null) setState(() => _docs[key] = x);
  }

  Future<void> _submit() async {
    if (_docs['aadhaar_front'] == null || _docs['selfie'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload at least Aadhaar Front + Selfie')));
      return;
    }
    if (_bankNameCtrl.text.isEmpty || _acctHolderCtrl.text.isEmpty || _acctNumCtrl.text.isEmpty || _ifscCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all bank details')));
      return;
    }
    setState(() => _loading = true);
    try {
      for (final e in _docs.entries) {
        if (e.value != null) {
          try { await ApiService.post('/drivers/documents', {'document_type': e.key, 'document_url': e.value!.path}); } catch (_) {}
        }
      }
      try { await ApiService.updateProfile({'bank_name': _bankNameCtrl.text, 'account_holder': _acctHolderCtrl.text, 'account_number': _acctNumCtrl.text, 'ifsc_code': _ifscCtrl.text}); } catch (_) {}
      if (mounted) Navigator.pushReplacementNamed(context, '/terms');
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.toString().replaceFirst("Exception: ", "")}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Documents & Bank Details')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Step 2 of 4', style: TextStyle(color: AppColors.textLight, fontSize: 14)),
        const Text('Documents', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ..._docs.keys.map((k) => Card(child: ListTile(
          leading: Icon(_icon(k), color: AppColors.primary), title: Text(_label(k)),
          subtitle: Text(_docs[k] != null ? 'Done' : 'Tap to take photo'),
          trailing: Icon(_docs[k] != null ? Icons.check_circle : Icons.upload_file, color: _docs[k] != null ? AppColors.success : AppColors.textLight),
          onTap: () => _pickImage(k),
        ))),
        const SizedBox(height: 24),
        const Text('Bank Account Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(controller: _bankNameCtrl, decoration: const InputDecoration(labelText: 'Bank Name *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _acctHolderCtrl, decoration: const InputDecoration(labelText: 'Account Holder Name *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _acctNumCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Account Number *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _ifscCtrl, decoration: const InputDecoration(labelText: 'IFSC Code *', border: OutlineInputBorder())),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Next: Terms & Conditions', style: TextStyle(fontSize: 16)))),
      ])),
    );
  }
  @override
  void dispose() { _bankNameCtrl.dispose(); _acctHolderCtrl.dispose(); _acctNumCtrl.dispose(); _ifscCtrl.dispose(); super.dispose(); }
}

// ═══════════════════════════════════════════════════
// PAGE 3: TERMS & CONDITIONS
// ═══════════════════════════════════════════════════
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});
  @override
  State<TermsScreen> createState() => _TermsScreenState();
}
class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Terms & Conditions')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Step 3 of 4', style: TextStyle(color: AppColors.textLight, fontSize: 14)),
      const Text('Terms & Conditions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _t('1. Services'), _d('I agree to provide e-rickshaw ride services through the Zip-Rick platform.'),
          _t('2. Background Check'), _d('I authorize Zip-Rick to verify my documents and conduct a background check.'),
          _t('3. Commission'), _d('I agree to pay a commission of 10% on each ride fare to Zip-Rick.'),
          _t('4. Conduct'), _d('I will maintain professional conduct, keep my vehicle clean, and treat passengers with respect.'),
          _t('5. Cancellation'), _d('I understand that excessive cancellations may result in account suspension.'),
          _t('6. Fees'), _d('The registration fee of 499 is non-refundable.'),
          _t('7. Compliance'), _d('I will comply with all local traffic rules and regulations.'),
          _t('8. Data'), _d('I consent to Zip-Rick collecting my location data for ride tracking purposes.'),
        ])),
      const SizedBox(height: 20),
      CheckboxListTile(value: _agreed, dense: true, onChanged: (v) => setState(() => _agreed = v ?? false),
        title: const Text('I have read and agree to all the terms and conditions above', style: TextStyle(fontSize: 14)),
        controlAffinity: ListTileControlAffinity.leading),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _agreed ? () => Navigator.pushReplacementNamed(context, '/payment') : null,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('Agree & Continue to Payment', style: TextStyle(fontSize: 16)))),
    ])));
  Widget _t(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)));
  Widget _d(String d) => Text(d, style: const TextStyle(color: AppColors.textLight, fontSize: 14));
}

// ═══════════════════════════════════════════════════
// PAGE 4: PAYMENT
// ═══════════════════════════════════════════════════
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: ${e.toString().replaceFirst("Exception: ", "")}')));
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registration Fee')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('Step 4 of 4', style: TextStyle(color: AppColors.textLight, fontSize: 14)),
      const SizedBox(height: 24),
      Container(width: 100, height: 100, decoration: BoxDecoration(color: (_success ? AppColors.success : AppColors.primary).withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(_success ? Icons.check_circle : Icons.payment, size: 48, color: _success ? AppColors.success : AppColors.primary)),
      const SizedBox(height: 24),
      const Text('One-Time Registration Fee', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Pay 499 to complete your registration', style: TextStyle(color: AppColors.textLight, fontSize: 16)),
      const SizedBox(height: 32),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(children: [
          const Text('Amount Due', style: TextStyle(color: AppColors.textLight, fontSize: 14)), const SizedBox(height: 8),
          const Text('499', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const Divider(height: 32),
          _r('Registration Fee', '499'), _r('Total', '499', bold: true),
        ])),
      const SizedBox(height: 32),
      if (_success)
        const Column(children: [Icon(Icons.check_circle, size: 64, color: AppColors.success), SizedBox(height: 12),
          Text('Payment Successful!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success))])
      else
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
          onPressed: _loading ? null : _pay,
          icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.payment),
          label: Text(_loading ? 'Processing...' : 'Pay 499 Now', style: const TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ]))));
  Widget _r(String l, String v, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: TextStyle(color: AppColors.textLight, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 18 : 16)),
  ]));
}

// ═══════════════════════════════════════════════════
// DRIVER HOME SCREEN
// ═══════════════════════════════════════════════════
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}
class _DriverHomeScreenState extends State<DriverHomeScreen> with WidgetsBindingObserver {
  io.Socket? _socket; bool _socketConnected = false;
  Position? _currentPosition; bool _locationLoading = true;
  bool _isOnline = false; bool _togglingOnline = false;
  Map<String, dynamic>? _rideRequest; bool _showingRideRequest = false;
  Map<String, dynamic>? _activeRide; bool _hasActiveRide = false;
  Map<String, dynamic>? _driverProfile; String _driverName = 'Driver';
  Timer? _pollTimer; int _bottomNavIndex = 0;
  Set<String> _declinedRideIds = {};

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _fetchLocation(); _connectSocket(); _loadProfile(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _pollTimer?.cancel(); _socket?.disconnect(); _socket?.dispose(); super.dispose(); }

  Future<void> _connectSocket() async {
    final t = await ApiService.getToken(); if (t == null) return;
    _socket = io.io('https://zip-rick-4.onrender.com', <String, dynamic>{'transports': ['websocket'], 'auth': {'token': t}});
    _socket!.onConnect((_) => setState(() => _socketConnected = true));
    _socket!.on('ride:new_request', (d) {
      if (mounted && !_hasActiveRide) {
        final id = (d is Map) ? d['ride_id']?.toString() ?? '' : '';
        if (id.isNotEmpty && !_declinedRideIds.contains(id)) setState(() { _rideRequest = d as Map<String, dynamic>; _showingRideRequest = true; });
      }
    });
    _socket!.on('ride:taken', (d) { if (mounted && _showingRideRequest) setState(() { _showingRideRequest = false; _rideRequest = null; }); });
    _socket!.on('ride:cancelled', (d) { if (mounted) setState(() { _hasActiveRide = false; _activeRide = null; _showingRideRequest = false; _rideRequest = null; }); });
    _socket!.onDisconnect((_) => setState(() => _socketConnected = false));
    _socket!.connect();
  }

  Future<void> _fetchLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { setState(() => _locationLoading = false); return; }
      if (await Geolocator.checkPermission() == LocationPermission.denied) await Geolocator.requestPermission();
      Position? p = await Geolocator.getLastKnownPosition();
      if (p != null) setState(() { _currentPosition = p; _locationLoading = false; });
      p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (p != null && mounted) {
        setState(() { _currentPosition = p; _locationLoading = false; });
        if (_socket != null && _socketConnected) _socket!.emit('driver:location_update', {'latitude': p.latitude, 'longitude': p.longitude});
      }
    } catch (_) { setState(() => _locationLoading = false); }
  }

  Future<void> _loadProfile() async {
    try {
      final r = await ApiService.getProfile();
      if (r['data']?['driver'] != null) {
        setState(() { _driverProfile = r['data']['driver']; _driverName = _driverProfile!['user']?['full_name'] ?? 'Driver'; _isOnline = _driverProfile!['is_online'] == true; });
      }
    } catch (_) {}
  }

  Future<void> _toggleOnline() async {
    if (_currentPosition == null) { await _fetchLocation(); if (_currentPosition == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable GPS first'))); return; } }
    setState(() => _togglingOnline = true);
    try {
      final r = await ApiService.toggleOnline();
      setState(() { _isOnline = r['data']?['is_online'] == true; _togglingOnline = false; });
      if (_isOnline) { if (_socket?.connected == true) _socket!.emit('driver:go_online'); _startPolling(); }
      else { _stopPolling(); if (_socket?.connected == true) _socket!.emit('driver:go_offline'); }
    } catch (e) {
      setState(() => _togglingOnline = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))));
    }
  }

  void _startPolling() { _pollTimer?.cancel(); _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollForRides()); }
  void _stopPolling() { _pollTimer?.cancel(); _pollTimer = null; }
  Future<void> _pollForRides() async {
    if (!_isOnline || _hasActiveRide || _showingRideRequest) return;
    try {
      final r = await ApiService.getSearchingRides();
      if (r['data']?['rides'] != null) {
        for (final r2 in (r['data']['rides'] as List)) {
          final id = (r2 as Map)['id']?.toString() ?? '';
          if (!_declinedRideIds.contains(id)) { if (mounted) setState(() { _rideRequest = r2 as Map<String, dynamic>; _showingRideRequest = true; }); return; }
        }
      }
    } catch (_) {}
  }

  Future<void> _acceptRide() async {
    if (_rideRequest == null || _socket == null) return;
    _socket!.emit('ride:accept', {'ride_id': _rideRequest!['ride_id'] ?? _rideRequest!['id']});
    setState(() { _showingRideRequest = false; _hasActiveRide = true; });
    await Future.delayed(const Duration(seconds: 2)); _loadActiveRide();
  }
  void _rejectRide() {
    final id = _rideRequest?['ride_id']?.toString() ?? _rideRequest?['id']?.toString() ?? '';
    if (id.isNotEmpty) _declinedRideIds.add(id);
    setState(() { _showingRideRequest = false; _rideRequest = null; });
  }
  Future<void> _loadActiveRide() async {
    try {
      final r = await ApiService.getActiveRide();
      setState(() { _activeRide = r['data']?['ride']; _hasActiveRide = _activeRide != null; });
    } catch (_) { setState(() { _activeRide = null; _hasActiveRide = false; }); }
  }
  void _updateStatus(String e) {
    if (_socket != null && _activeRide != null) {
      _socket!.emit(e, {'ride_id': _activeRide!['id']});
      if (e == 'ride:complete') setState(() { _hasActiveRide = false; _activeRide = null; });
    }
  }
  Future<void> _callCustomer() async {
    String? p; try { p = _activeRide?['customer']?['user']?['phone']; } catch (_) {}
    if (p != null && p.isNotEmpty && await canLaunchUrl(Uri.parse('tel:$p'))) await launchUrl(Uri.parse('tel:$p'));
    else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone unavailable')));
  }
  Future<void> _sendSOS() async {
    if (_currentPosition == null) return;
    try { await ApiService.sendSOS(_currentPosition!.latitude, _currentPosition!.longitude); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS sent!'), backgroundColor: Colors.red)); }
    catch (_) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS failed'))); }
  }
  void _showSupport() {
    final sC = TextEditingController(); final mC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Support'), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: sC, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
        const SizedBox(height: 12), TextField(controller: mC, maxLines: 3, decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder())),
      ]), actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (sC.text.isEmpty || mC.text.isEmpty) return;
          try { await ApiService.createTicket(sC.text, mC.text); if (c.mounted) Navigator.pop(c); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket sent'))); }
          catch (_) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed'))); }
        }, child: const Text('Submit')),
      ],
    ));
  }
  Future<void> _logout() async {
    await ApiService.clearToken(); if (_socket != null) { _socket!.emit('driver:go_offline'); _socket!.disconnect(); }
    _pollTimer?.cancel(); if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_hasActiveRide ? 'Active Ride' : 'Zip-Rick Driver'), backgroundColor: AppColors.primary, foregroundColor: Colors.white,
      actions: [
        if (!_hasActiveRide) IconButton(icon: const Icon(Icons.support_agent), onPressed: _showSupport),
        IconButton(icon: const Icon(Icons.sos, color: Colors.redAccent), onPressed: _sendSOS),
        IconButton(icon: Icon(_socketConnected ? Icons.wifi : Icons.wifi_off, color: _socketConnected ? Colors.greenAccent : Colors.orange, size: 20), onPressed: () {}),
      ]),
    body: Stack(children: [
      [_homeTab(), _earningsTab(), _profileTab()][_bottomNavIndex],
      if (_showingRideRequest && _rideRequest != null) _ridePopup(),
    ]),
    bottomNavigationBar: BottomNavigationBar(currentIndex: _bottomNavIndex, onTap: (i) => setState(() => _bottomNavIndex = i),
      selectedItemColor: AppColors.primary,
      items: const [BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'), BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Earnings'), BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile')]),
  );

  Widget _homeTab() {
    if (_hasActiveRide && _activeRide != null) return _activeRideView();
    return Column(children: [
      Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: _isOnline ? AppColors.success : AppColors.textLight, child: Icon(_isOnline ? Icons.power_settings_new : Icons.power_off, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isOnline ? 'You are ONLINE' : 'You are OFFLINE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isOnline ? AppColors.success : AppColors.textLight)),
            Text(_isOnline ? 'Ride requests appear here' : 'Go online to receive rides', style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
          ])),
          Switch(value: _isOnline, onChanged: _togglingOnline ? null : (_) => _toggleOnline(), activeColor: AppColors.success),
        ])),
      Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: _currentPosition != null
              ? FlutterMap(
                  options: MapOptions(center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), zoom: 15),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.ziprick.driver'),
                    MarkerLayer(markers: [Marker(point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), width: 80, height: 80, child: Icon(Icons.electric_rickshaw_rounded, size: 48, color: _isOnline ? AppColors.success : AppColors.textLight))]),
                  ],
                )
              : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Fetching location...')])),
        ),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(onPressed: _fetchLocation, icon: const Icon(Icons.my_location), label: const Text('Refresh Location'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
    ]);
  }

  Widget _activeRideView() {
    final r = _activeRide!; final status = r['status'] ?? '';
    String st = ''; Color sc = AppColors.primary;
    if (status == 'driver_assigned') { st = 'Heading to pickup'; sc = AppColors.warning; }
    else if (status == 'driver_arrived') { st = 'Arrived'; sc = AppColors.success; }
    else if (status == 'started') { st = 'In progress'; sc = AppColors.primary; }
    else if (status == 'completed') { st = 'Completed'; sc = AppColors.success; }
    else st = status;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: sc.withOpacity(0.3))),
        child: Row(children: [Icon(Icons.info_outline, color: sc, size: 32), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status: $st', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sc)),
          Text('Fare: ${r['total_fare'] ?? '--'}', style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
        ]))])),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [const Icon(Icons.trip_origin, color: AppColors.success, size: 24), const SizedBox(width: 12), Expanded(child: Text(r['pickup_address'] ?? 'Pickup'))]),
        const Divider(height: 20),
        Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 24), const SizedBox(width: 12), Expanded(child: Text(r['drop_address'] ?? 'Drop'))]),
      ]))),
      const SizedBox(height: 16),
      if (status == 'driver_assigned') _btn('Arrived', Icons.check_circle, AppColors.warning, () => _updateStatus('ride:arrived')),
      if (status == 'driver_arrived') _btn('Start Ride', Icons.play_arrow, AppColors.success, () => _updateStatus('ride:start')),
      if (status == 'started') _btn('Complete Ride', Icons.stop_circle, AppColors.primary, () => _updateStatus('ride:complete')),
      if (status == 'completed') _btn('Done', Icons.home, AppColors.success, () => setState(() { _hasActiveRide = false; _activeRide = null; })),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _callCustomer, icon: const Icon(Icons.phone), label: const Text('Call Customer'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ]));
  }
  Widget _btn(String l, IconData i, Color c, VoidCallback o) => SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: o, icon: Icon(i), label: Text(l), style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));

  Widget _ridePopup() {
    final r = _rideRequest!;
    return Positioned(top: 0, left: 0, right: 0, child: Material(elevation: 8, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.notifications_active, color: AppColors.warning, size: 18), SizedBox(width: 6), Text('New Ride!', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold))])),
          const SizedBox(height: 12),
          if (r['distance_km'] != null) Text('${r['distance_km']} km away', style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.trip_origin, color: AppColors.success, size: 20), const SizedBox(width: 8), Expanded(child: Text(r['pickup_address'] ?? 'Pickup', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))]),
          const SizedBox(height: 6),
          Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(r['drop_address'] ?? 'Drop', style: const TextStyle(fontSize: 15)))]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Fare: ', style: TextStyle(fontSize: 18)), Text('${r['total_fare'] ?? '--'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary))]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _acceptRide, icon: const Icon(Icons.check_circle), label: const Text('Accept'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(onPressed: _rejectRide, icon: const Icon(Icons.cancel), label: const Text('Decline'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ]),
        ]))));
  }

  Widget _earningsTab() => FutureBuilder<Map<String, dynamic>>(
    future: ApiService.getEarnings(),
    builder: (c, s) {
      if (s.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), const Text('Could not load earnings'), ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry'))]));
      final d = s.data?['data'] ?? {};
      return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Earnings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
        Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total Earnings', style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 8),
            Text('${d['total_earnings'] ?? '0'}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8), Text('${d['total_rides'] ?? '0'} rides', style: const TextStyle(color: Colors.white70)),
          ])),
        const SizedBox(height: 20),
        Row(children: [Expanded(child: _ec('Today', '${d['today_earnings'] ?? '0'}', Icons.today, AppColors.success)), const SizedBox(width: 12), Expanded(child: _ec('Week', '${d['week_earnings'] ?? '0'}', Icons.date_range, AppColors.warning))]),
      ]));
    },
  );
  Widget _ec(String l, String a, IconData i, Color c) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Icon(i, color: c, size: 28), const SizedBox(height: 8), Text(a, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)), const SizedBox(height: 4), Text(l, style: const TextStyle(color: AppColors.textLight))])));

  Widget _profileTab() {
    final docs = (_driverProfile?['documents'] as List?) ?? [];
    final docStatus = <String, bool>{};
    for (final d in docs) { if (d is Map) docStatus[d['document_type']?.toString() ?? ''] = d['status'] == 'approved'; }
    final v = _driverProfile?['vehicle'] as Map?;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Center(child: Column(children: [
        CircleAvatar(radius: 48, backgroundColor: AppColors.primary, child: Text(_driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D', style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12), Text(_driverName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: (_isOnline ? AppColors.success : Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Text(_isOnline ? 'Online' : 'Offline', style: TextStyle(color: _isOnline ? AppColors.success : Colors.grey, fontWeight: FontWeight.bold))),
      ])),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _sc('Rating', '${_driverProfile?['rating_avg'] ?? '0.0'}', Icons.star, Colors.amber)),
        const SizedBox(width: 8), Expanded(child: _sc('Rides', '${_driverProfile?['total_rides'] ?? '0'}', Icons.directions_car, AppColors.primary)),
        const SizedBox(width: 8), Expanded(child: _sc('Status', '${_driverProfile?['registration_status'] ?? 'pending'}', Icons.verified_user, AppColors.success)),
      ]),
      const SizedBox(height: 20),
      const Text('Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      Card(child: Column(children: [
        _ds('Aadhaar', docStatus['aadhaar_front'] == true || docStatus['aadhaar'] == true), const Divider(height: 1),
        _ds('Selfie', docStatus['selfie'] == true), const Divider(height: 1),
        _ds('Vehicle RC', docStatus['rc'] == true), const Divider(height: 1),
        _ds('Insurance', docStatus['insurance'] == true),
      ])),
      if (v != null) ...[const SizedBox(height: 16), const Text('Vehicle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [_ir('Number', v['vehicle_number']?.toString() ?? 'N/A'), _ir('Model', v['vehicle_model']?.toString() ?? 'N/A')]))),
      ],
      if ((_driverProfile?['total_ratings'] ?? 0) > 0) ...[const SizedBox(height: 16), const Text('Ratings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [_ir('Average', '${_driverProfile?['rating_avg'] ?? '0.0'}'), _ir('Total', '${_driverProfile?['total_ratings'] ?? '0'}')]))),
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout, color: Colors.red), label: const Text('Logout', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: Colors.red)))),
      const SizedBox(height: 20),
    ]));
  }
  Widget _sc(String l, String v, IconData i, Color c) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Icon(i, color: c, size: 24), const SizedBox(height: 4), Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)), Text(l, style: const TextStyle(fontSize: 11, color: AppColors.textLight))])));
  Widget _ds(String l, bool ok) => ListTile(leading: Icon(ok ? Icons.check_circle : Icons.pending, color: ok ? AppColors.success : AppColors.warning), title: Text(l), trailing: Text(ok ? 'Verified' : 'Pending', style: TextStyle(color: ok ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w500)));
  Widget _ir(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: AppColors.textLight)), Text(v, style: const TextStyle(fontWeight: FontWeight.w500))]));
}
