import 'dart:async';
import 'dart:io';
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
  static const accent = Color(0xFFFF6B6B);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFA726);
  static const bg = Color(0xFFF5F6FA);
  static const card = Colors.white;
  static const textLight = Color(0xFF9E9E9E);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZipRickDriverApp());
}

class ZipRickDriverApp extends StatelessWidget {
  const ZipRickDriverApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zip-Rick Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.primary, scaffoldBackgroundColor: AppColors.bg),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/login': (ctx) => const LoginScreen(),
        '/register': (ctx) => const RegisterScreen(),
        '/register-docs': (ctx) => const RegisterDocsScreen(),
        '/home': (ctx) => const DriverHomeScreen(),
      },
    );
  }
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
      const SizedBox(height: 8),
      const Text('Your E-Rickshaw, Instantly', style: TextStyle(color: Colors.white70, fontSize: 16)),
      const SizedBox(height: 60), const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
    ])));
}

// ──── LOGIN SCREEN (Page 1: Phone + Name) ────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: '+91');
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';
  bool _showOtp = false;
  final _otpCtrl = TextEditingController();

  Future<void> _sendOtp() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your full name');
      return;
    }
    if (_phoneCtrl.text.trim().length < 10) {
      setState(() => _error = 'Please enter a valid phone number');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      await ApiService.sendOtp(_phoneCtrl.text.trim());
      setState(() { _showOtp = true; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) { setState(() => _error = 'Enter OTP'); return; }
    setState(() { _loading = true; _error = ''; });
    try {
      // Try login first
      try {
        final res = await ApiService.verifyOtp(phone, otp, role: 'driver');
        final data = res['data'];
        if (data != null && data['tokens'] != null && data['tokens']['accessToken'] != null) {
          await ApiService.saveToken(data['tokens']['accessToken']);
          if (mounted) Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      } catch (_) {}
      
      // If login fails, try registering with name
      final res = await ApiService.verifyOtp(phone, otp, fullName: _nameCtrl.text.trim(), role: 'driver');
      final data = res['data'];
      if (data != null && data['tokens'] != null && data['tokens']['accessToken'] != null) {
        await ApiService.saveToken(data['tokens']['accessToken']);
        // Go to documents page
        if (mounted) Navigator.pushReplacementNamed(context, '/register-docs');
      } else {
        setState(() { _error = 'Registration failed'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(
    child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 40),
      const Icon(Icons.electric_rickshaw_rounded, size: 64, color: AppColors.primary),
      const SizedBox(height: 24),
      Text(_showOtp ? 'Verify OTP' : 'Driver Registration',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(_showOtp ? 'Enter the OTP sent to your phone' : 'Enter your details to get started',
          style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
      const SizedBox(height: 32),
      TextField(controller: _nameCtrl, enabled: !_showOtp,
        decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
      const SizedBox(height: 16),
      TextField(controller: _phoneCtrl, enabled: !_showOtp, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
      if (_showOtp) ...[
        const SizedBox(height: 16),
        TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6,
          decoration: const InputDecoration(labelText: 'OTP', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
      ],
      if (_error.isNotEmpty) ...[const SizedBox(height: 12), Text(_error, style: const TextStyle(color: Colors.red, fontSize: 14))],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _loading ? null : (_showOtp ? _verifyOtp : _sendOtp),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(_showOtp ? 'Verify & Continue' : 'Send OTP', style: const TextStyle(fontSize: 16)),
      )),
    ])));
  }
  @override
  void dispose() { _phoneCtrl.dispose(); _nameCtrl.dispose(); _otpCtrl.dispose(); super.dispose(); }
}

// ──── REGISTER SCREEN (kept for backwards compatibility) ────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  @override
  Widget build(BuildContext context) => const LoginScreen();
}

// ──── REGISTER DOCUMENTS SCREEN (Page 2) ────
class RegisterDocsScreen extends StatefulWidget {
  const RegisterDocsScreen({super.key});
  @override
  State<RegisterDocsScreen> createState() => _RegisterDocsScreenState();
}
class _RegisterDocsScreenState extends State<RegisterDocsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;

  // Track selected images
  Map<String, XFile?> _documents = {
    'aadhaar_front': null,
    'aadhaar_back': null,
    'selfie': null,
    'rc': null,
    'insurance': null,
  };

  Future<void> _pickImage(String docType) async {
    final xFile = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
    if (xFile != null) {
      setState(() => _documents[docType] = xFile);
    }
  }

  String _docLabel(String key) {
    switch (key) {
      case 'aadhaar_front': return 'Aadhaar Card (Front)';
      case 'aadhaar_back': return 'Aadhaar Card (Back)';
      case 'selfie': return 'Live Passport Photo';
      case 'rc': return 'Vehicle RC';
      case 'insurance': return 'Vehicle Insurance';
      default: return key;
    }
  }

  IconData _docIcon(String key) {
    switch (key) {
      case 'aadhaar_front':
      case 'aadhaar_back': return Icons.badge;
      case 'selfie': return Icons.camera_alt;
      case 'rc': return Icons.directions_car;
      case 'insurance': return Icons.verified;
      default: return Icons.upload_file;
    }
  }

  Future<void> _submitDocuments() async {
    // Check at least essential docs are done
    if (_documents['aadhaar_front'] == null || _documents['selfie'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least Aadhaar (Front) and Selfie')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      // Upload each document to backend
      for (final entry in _documents.entries) {
        if (entry.value != null) {
          try {
            await ApiService.post('/drivers/documents', {
              'document_type': entry.key,
              'document_url': entry.value!.path, // placeholder path
            });
          } catch (_) {}
        }
      }
      // Save vehicle info
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Upload Documents')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Submit Your Documents', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Your documents will be verified by our team', style: TextStyle(color: AppColors.textLight)),
        const SizedBox(height: 24),
        ..._documents.keys.map((key) => Card(
          child: ListTile(
            leading: Icon(_docIcon(key), color: AppColors.primary),
            title: Text(_docLabel(key)),
            subtitle: Text(_documents[key] != null ? '✓ Photo taken' : 'Tap to take photo'),
            trailing: _documents[key] != null
                ? const Icon(Icons.check_circle, color: AppColors.success)
                : const Icon(Icons.upload_file),
            onTap: () => _pickImage(key),
          ),
        )),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _loading ? null : _submitDocuments,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Submit & Continue', style: TextStyle(fontSize: 16)),
        )),
      ]),
    ),
  );
}

// ──── DRIVER HOME SCREEN ────
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}
class _DriverHomeScreenState extends State<DriverHomeScreen> with WidgetsBindingObserver {
  io.Socket? _socket;
  bool _socketConnected = false;
  Position? _currentPosition;
  bool _locationLoading = true;
  bool _isOnline = false;
  bool _togglingOnline = false;
  Map<String, dynamic>? _rideRequest;
  bool _showingRideRequest = false;
  Map<String, dynamic>? _activeRide;
  bool _hasActiveRide = false;
  Map<String, dynamic>? _driverProfile;
  String _driverName = 'Driver';
  Timer? _pollTimer;
  int _bottomNavIndex = 0;
  bool _locationFetched = false;
  Set<String> _declinedRideIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchLocation();
    _connectSocket();
    _loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _connectSocket() async {
    final token = await ApiService.getToken();
    if (token == null) return;
    _socket = io.io('https://zip-rick-4.onrender.com', <String, dynamic>{
      'transports': ['websocket'], 'auth': {'token': token},
    });
    _socket!.onConnect((_) => setState(() => _socketConnected = true));
    _socket!.on('ride:new_request', (data) {
      if (mounted && !_hasActiveRide) {
        final rideId = (data is Map) ? data['ride_id']?.toString() ?? '' : '';
        if (rideId.isNotEmpty && !_declinedRideIds.contains(rideId)) {
          setState(() { _rideRequest = data as Map<String, dynamic>; _showingRideRequest = true; });
        }
      }
    });
    _socket!.on('ride:taken', (data) {
      if (mounted && _showingRideRequest) {
        setState(() { _showingRideRequest = false; _rideRequest = null; });
      }
    });
    _socket!.on('ride:cancelled', (data) {
      if (mounted) setState(() { _hasActiveRide = false; _activeRide = null; _showingRideRequest = false; _rideRequest = null; });
    });
    _socket!.onDisconnect((_) => setState(() => _socketConnected = false));
    _socket!.connect();
  }

  Future<void> _fetchLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { setState(() => _locationLoading = false); return; }
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos != null) setState(() { _currentPosition = pos; _locationLoading = false; _locationFetched = true; });
      pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (pos != null && mounted) {
        setState(() { _currentPosition = pos; _locationLoading = false; _locationFetched = true; });
        if (_socket != null && _socketConnected) {
          _socket!.emit('driver:location_update', {'latitude': pos.latitude, 'longitude': pos.longitude});
        }
      }
    } catch (_) { setState(() => _locationLoading = false); }
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiService.getProfile();
      if (res['data'] != null && res['data']['driver'] != null) {
        setState(() {
          _driverProfile = res['data']['driver'];
          _driverName = _driverProfile!['user']?['full_name'] ?? _driverProfile!['full_name'] ?? 'Driver';
          _isOnline = _driverProfile!['is_online'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleOnline() async {
    if (_currentPosition == null) { await _fetchLocation(); if (_currentPosition == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable GPS first'))); return; } }
    setState(() => _togglingOnline = true);
    try {
      final res = await ApiService.toggleOnline();
      if (res['data'] != null) {
        setState(() { _isOnline = res['data']['is_online'] == true; _togglingOnline = false; });
        if (_isOnline) {
          if (_socket != null && _socketConnected) _socket!.emit('driver:go_online');
          _startPolling();
        } else {
          _stopPolling();
          if (_socket != null && _socketConnected) _socket!.emit('driver:go_offline');
        }
      }
    } catch (e) {
      setState(() => _togglingOnline = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.toString().replaceFirst("Exception: ", "")}')));
    }
  }

  void _startPolling() { _pollTimer?.cancel(); _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollForRides()); }
  void _stopPolling() { _pollTimer?.cancel(); _pollTimer = null; }

  Future<void> _pollForRides() async {
    if (!_isOnline || _hasActiveRide || _showingRideRequest) return;
    try {
      final res = await ApiService.getSearchingRides();
      if (res['data'] != null && res['data']['rides'] != null) {
        final rides = res['data']['rides'] as List;
        if (rides.isNotEmpty) {
          for (final r in rides) {
            final rideId = (r as Map)['id']?.toString() ?? '';
            if (!_declinedRideIds.contains(rideId)) {
              if (mounted) setState(() { _rideRequest = r as Map<String, dynamic>; _showingRideRequest = true; });
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _acceptRide() async {
    if (_rideRequest == null || _socket == null) return;
    final rideId = _rideRequest!['ride_id'] ?? _rideRequest!['id'];
    _socket!.emit('ride:accept', {'ride_id': rideId});
    setState(() { _showingRideRequest = false; _hasActiveRide = true; });
    await Future.delayed(const Duration(seconds: 2));
    _loadActiveRide();
  }

  void _rejectRide() {
    final rideId = _rideRequest?['ride_id']?.toString() ?? _rideRequest?['id']?.toString() ?? '';
    if (rideId.isNotEmpty) _declinedRideIds.add(rideId);
    setState(() { _showingRideRequest = false; _rideRequest = null; });
  }

  Future<void> _loadActiveRide() async {
    try {
      final res = await ApiService.getActiveRide();
      if (res['data'] != null && res['data']['ride'] != null) {
        setState(() { _activeRide = res['data']['ride']; _hasActiveRide = true; });
      } else { setState(() { _activeRide = null; _hasActiveRide = false; }); }
    } catch (_) { setState(() { _activeRide = null; _hasActiveRide = false; }); }
  }

  void _updateRideStatus(String event) {
    if (_socket != null && _activeRide != null) {
      _socket!.emit(event, {'ride_id': _activeRide!['id']});
      if (event == 'ride:complete') setState(() { _hasActiveRide = false; _activeRide = null; });
    }
  }

  Future<void> _callCustomer() async {
    String? phone;
    try { phone = _activeRide?['customer']?['user']?['phone']; } catch (_) {}
    if (phone != null && phone.isNotEmpty) {
      if (await canLaunchUrl(Uri.parse('tel:$phone'))) await launchUrl(Uri.parse('tel:$phone'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer phone not available')));
    }
  }

  Future<void> _sendSOS() async {
    if (_currentPosition == null) return;
    try {
      await ApiService.sendSOS(_currentPosition!.latitude, _currentPosition!.longitude);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS sent!'), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SOS failed')));
    }
  }

  void _showSupportDialog() {
    final sCtrl = TextEditingController(); final mCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Support'), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: sCtrl, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: mCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder())),
      ]), actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (sCtrl.text.isEmpty || mCtrl.text.isEmpty) return;
          try { await ApiService.createTicket(sCtrl.text, mCtrl.text); if (ctx.mounted) Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket sent'))); }
          catch (_) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed'))); }
        }, child: const Text('Submit')),
      ],
    ));
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (_socket != null) { _socket!.emit('driver:go_offline'); _socket!.disconnect(); }
    _pollTimer?.cancel();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_hasActiveRide ? 'Active Ride' : 'Zip-Rick Driver'),
        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
        actions: [
          if (!_hasActiveRide) IconButton(icon: const Icon(Icons.support_agent), onPressed: _showSupportDialog),
          IconButton(icon: const Icon(Icons.sos, color: Colors.redAccent), onPressed: _sendSOS),
          IconButton(icon: Icon(_socketConnected ? Icons.wifi : Icons.wifi_off, color: _socketConnected ? Colors.greenAccent : Colors.orange, size: 20), onPressed: () {}),
        ]),
      body: Stack(children: [
        [_buildHomeTab(context), _buildEarningsTab(context), _buildProfileTab()][_bottomNavIndex],
        if (_showingRideRequest && _rideRequest != null) _buildRideRequestPopup(),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex, onTap: (i) => setState(() => _bottomNavIndex = i),
        selectedItemColor: AppColors.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ]),
    );
  }

  // ─── HOME TAB ───
  Widget _buildHomeTab(BuildContext context) {
    if (_hasActiveRide && _activeRide != null) return _buildActiveRideView();
    return Column(children: [
      Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: _isOnline ? AppColors.success : AppColors.textLight,
            child: Icon(_isOnline ? Icons.power_settings_new : Icons.power_off, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isOnline ? 'You are ONLINE' : 'You are OFFLINE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isOnline ? AppColors.success : AppColors.textLight)),
            Text(_isOnline ? 'Ride requests appear here' : 'Go online to receive rides', style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
          ])),
          Switch(value: _isOnline, onChanged: _togglingOnline ? null : (_) => _toggleOnline(), activeColor: AppColors.success),
        ])),
      Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), clipBehavior: Clip.antiAlias,
        child: _currentPosition != null
            ? FlutterMap(options: MapOptions(center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), zoom: 15.0), children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.ziprick.driver'),
                MarkerLayer(markers: [Marker(point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), width: 80, height: 80, child: Icon(Icons.electric_rickshaw_rounded, size: 48, color: _isOnline ? AppColors.success : AppColors.textLight))]),
              ])
            : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Fetching location...')]))),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(onPressed: _fetchLocation, icon: const Icon(Icons.my_location), label: const Text('Refresh Location'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildActiveRideView() {
    final r = _activeRide!; final pickup = r['pickup_address'] ?? 'Pickup'; final drop = r['drop_address'] ?? 'Drop';
    final fare = r['total_fare']?.toString() ?? '--'; final status = r['status'] ?? '';
    String st = ''; Color sc = AppColors.primary;
    if (status == 'driver_assigned') { st = 'Heading to pickup'; sc = AppColors.warning; }
    else if (status == 'driver_arrived') { st = 'Arrived at pickup'; sc = AppColors.success; }
    else if (status == 'started') { st = 'Ride in progress'; sc = AppColors.primary; }
    else if (status == 'completed') { st = 'Completed'; sc = AppColors.success; }
    else st = status;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: sc.withOpacity(0.3))),
        child: Row(children: [Icon(Icons.info_outline, color: sc, size: 32), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Status: $st', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sc)),
            Text('Fare: ₹$fare', style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
          ]))])),
      const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [const Icon(Icons.trip_origin, color: AppColors.success, size: 24), const SizedBox(width: 12), Expanded(child: Text(pickup))]),
        const Divider(height: 24),
        Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 24), const SizedBox(width: 12), Expanded(child: Text(drop))]),
      ]))),
      const SizedBox(height: 20),
      if (status == 'driver_assigned') _actionBtn('I\'ve Arrived', Icons.check_circle, AppColors.warning, () => _updateRideStatus('ride:arrived')),
      if (status == 'driver_arrived') _actionBtn('Start Ride', Icons.play_arrow, AppColors.success, () => _updateRideStatus('ride:start')),
      if (status == 'started') _actionBtn('Complete Ride', Icons.stop_circle, AppColors.primary, () => _updateRideStatus('ride:complete')),
      if (status == 'completed') _actionBtn('Back to Home', Icons.home, AppColors.primary, () => setState(() { _hasActiveRide = false; _activeRide = null; })),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _callCustomer, icon: const Icon(Icons.phone), label: const Text('Call Customer'),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ]));
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));
  }

  Widget _buildRideRequestPopup() {
    final req = _rideRequest!;
    return Positioned(top: 0, left: 0, right: 0, child: Material(elevation: 8,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.notifications_active, color: AppColors.accent, size: 18), SizedBox(width: 6), Text('New Ride Request!', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold))])),
          const SizedBox(height: 16),
          if (req['distance_km'] != null) Text('${req['distance_km']} km away', style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.trip_origin, color: AppColors.success, size: 20), const SizedBox(width: 8), Expanded(child: Text(req['pickup_address'] ?? 'Pickup', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))]),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(req['drop_address'] ?? 'Drop', style: const TextStyle(fontSize: 15)))]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Fare: ', style: TextStyle(fontSize: 18)), Text('₹${req['total_fare'] ?? '--'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary))]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _acceptRide, icon: const Icon(Icons.check_circle), label: const Text('Accept'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(onPressed: _rejectRide, icon: const Icon(Icons.cancel), label: const Text('Decline'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ]),
        ]))));
  }

  // ─── EARNINGS TAB ───
  Widget _buildEarningsTab(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService.getEarnings(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12),
          const Text('Could not load earnings'), const SizedBox(height: 12),
          ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry')),
        ]));
        final d = snap.data?['data'] ?? {};
        return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Earnings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Earnings', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text('₹${d['total_earnings'] ?? '0'}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${d['total_rides'] ?? '0'} rides completed', style: const TextStyle(color: Colors.white70)),
            ])),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _eCard('Today', '₹${d['today_earnings'] ?? '0'}', Icons.today, AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _eCard('This Week', '₹${d['week_earnings'] ?? '0'}', Icons.date_range, AppColors.warning)),
          ]),
        ]));
      },
    );
  }
  Widget _eCard(String l, String a, IconData i, Color c) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Icon(i, color: c, size: 32), const SizedBox(height: 8), Text(a, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)), const SizedBox(height: 4), Text(l, style: const TextStyle(color: AppColors.textLight))])));

  // ─── PROFILE TAB ───
  Widget _buildProfileTab() {
    final docs = _driverProfile?['documents'] as List? ?? [];
    final docTypes = <String, bool>{};
    for (final d in docs) { if (d is Map) docTypes[d['document_type']?.toString() ?? ''] = d['status'] == 'approved'; }
    final vehicle = _driverProfile?['vehicle'] as Map?;
    
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Profile Header
      Center(child: Column(children: [
        CircleAvatar(radius: 48, backgroundColor: AppColors.primary, child: Text(_driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D', style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        Text(_driverName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: (_isOnline ? AppColors.success : Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Text(_isOnline ? 'Online' : 'Offline', style: TextStyle(color: _isOnline ? AppColors.success : Colors.grey, fontWeight: FontWeight.bold))),
      ])),
      const SizedBox(height: 24),

      // Stats Row
      Row(children: [
        _statCard('Rating', '${_driverProfile?['rating_avg'] ?? '0.0'} / 5', Icons.star, Colors.amber),
        const SizedBox(width: 12),
        _statCard('Rides', '${_driverProfile?['total_rides'] ?? '0'}', Icons.ride, AppColors.primary),
        const SizedBox(width: 12),
        _statCard('Status', '${_driverProfile?['registration_status'] ?? 'pending'}', Icons.verified_user, AppColors.success),
      ]),
      const SizedBox(height: 24),

      // Documents Status
      const Text('Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Card(child: Column(children: [
        _docStatus('Aadhaar Card', docTypes['aadhaar_front'] == true || docTypes['aadhaar'] == true),
        const Divider(height: 1),
        _docStatus('Selfie/Photo', docTypes['selfie'] == true),
        const Divider(height: 1),
        _docStatus('Vehicle RC', docTypes['rc'] == true),
        const Divider(height: 1),
        _docStatus('Vehicle Insurance', docTypes['insurance'] == true),
      ])),
      const SizedBox(height: 16),

      // Vehicle Info
      if (vehicle != null) ...[
        const Text('Vehicle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          _infoRow('Number', vehicle['vehicle_number']?.toString() ?? 'Not set'),
          _infoRow('Model', vehicle['vehicle_model']?.toString() ?? 'Not set'),
        ]))),
        const SizedBox(height: 16),
      ],

      // Rating Section
      if ((_driverProfile?['total_ratings'] ?? 0) > 0) ...[
        const Text('Rating Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          _infoRow('Average Rating', '${_driverProfile?['rating_avg'] ?? '0.0'}'),
          _infoRow('Total Ratings', '${_driverProfile?['total_ratings'] ?? '0'}'),
        ]))),
        const SizedBox(height: 16),
      ],

      // Logout
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout, color: Colors.red), label: const Text('Logout', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: Colors.red)))),
      const SizedBox(height: 20),
    ]));
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Icon(icon, color: color, size: 28),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
    ]))));
  }

  Widget _docStatus(String label, bool approved) {
    return ListTile(
      leading: Icon(approved ? Icons.check_circle : Icons.pending, color: approved ? AppColors.success : AppColors.warning),
      title: Text(label),
      trailing: Text(approved ? 'Verified' : 'Pending', style: TextStyle(color: approved ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w500)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textLight)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
    ]));
  }
}
