import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'services/api_service.dart';

// ──── Colors ────
class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF5A52D5);
  static const accent = Color(0xFFFF6B6B);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFA726);
  static const bg = Color(0xFFF5F6FA);
  static const card = Colors.white;
  static const textDark = Color(0xFF2D2D3A);
  static const textLight = Color(0xFF9E9E9E);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZippyDriverApp());
}

class ZippyDriverApp extends StatelessWidget {
  const ZippyDriverApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zippy Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        scaffoldBackgroundColor: AppColors.bg,
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/login': (ctx) => const LoginScreen(),
        '/register': (ctx) => const RegisterScreen(),
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
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    final token = await ApiService.getToken();
    if (token != null && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.electric_rickshaw_rounded, size: 120, color: Colors.white),
            const SizedBox(height: 24),
            Text('Zippy Driver',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your E-Rickshaw, Instantly',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 60),
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          ],
        ),
      ),
    );
  }
}

// ──── LOGIN SCREEN ────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: '+91');
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  bool _isNewUser = false;
  String _error = '';

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await ApiService.sendOtp(_phoneCtrl.text.trim());
      if (res['data'] != null && res['data']['is_new_user'] == true) {
        setState(() { _isNewUser = true; _otpSent = true; _loading = false; });
      } else {
        setState(() { _otpSent = true; _isNewUser = false; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _verifyOtp() async {
    setState(() { _loading = true; _error = ''; });
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    try {
      if (_isNewUser) {
        // New user - go to register
        if (mounted) Navigator.pushReplacementNamed(context, '/register', arguments: {'phone': phone, 'otp': otp});
        return;
      }
      final res = await ApiService.verifyOtp(phone, otp);
      if (res['data'] != null && res['data']['token'] != null) {
        await ApiService.saveToken(res['data']['token']);
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() { _error = 'Invalid response from server'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.electric_rickshaw_rounded, size: 64, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                _otpSent ? (_isNewUser ? 'Register' : 'Verify OTP') : 'Driver Login',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent ? 'Enter the OTP sent to your phone' : 'Enter your phone to continue',
                style: const TextStyle(color: AppColors.textLight, fontSize: 16),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_android),
                  border: OutlineInputBorder(),
                ),
                enabled: !_otpSent,
              ),
              if (_otpSent) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'OTP',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: const TextStyle(color: Colors.red, fontSize: 14)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_otpSent ? 'Verify & Login' : 'Send OTP', style: const TextStyle(fontSize: 16)),
                ),
              ),
              if (!_otpSent) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                    child: const Text('New driver? Register here'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }
}

// ──── REGISTER SCREEN ────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _vehicleNoCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  String _phone = '';
  String _otp = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      _phone = args['phone'] ?? '';
      _otp = args['otp'] ?? '';
    }
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your full name');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      // If OTP was already verified, use register endpoint
      final res = await ApiService.registerDriver(_phone, _nameCtrl.text.trim(), _otp);
      if (res['data'] != null && res['data']['token'] != null) {
        await ApiService.saveToken(res['data']['token']);
        // Save vehicle info
        if (_vehicleNoCtrl.text.isNotEmpty || _vehicleModelCtrl.text.isNotEmpty) {
          try {
            await ApiService.saveVehicle({
              'vehicle_number': _vehicleNoCtrl.text.trim(),
              'vehicle_model': _vehicleModelCtrl.text.trim(),
            });
          } catch (_) {}
        }
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() { _error = 'Registration failed. Try again.'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as Driver')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Complete Your Profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Fill in your details to start earning',
                style: TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 32),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _vehicleNoCtrl,
              decoration: const InputDecoration(
                labelText: 'E-Rickshaw Number (optional)',
                prefixIcon: Icon(Icons.directions_car),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _vehicleModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Vehicle Model (optional)',
                prefixIcon: Icon(Icons.model_training),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_error, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Register & Start', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vehicleNoCtrl.dispose();
    _vehicleModelCtrl.dispose();
    super.dispose();
  }
}

// ──── DRIVER HOME SCREEN (Main) ────
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with WidgetsBindingObserver {
  // Socket
  io.Socket? _socket;
  bool _socketConnected = false;

  // Location
  Position? _currentPosition;
  bool _locationLoading = true;

  // Online/Offline
  bool _isOnline = false;
  bool _togglingOnline = false;

  // Ride requests
  Map<String, dynamic>? _rideRequest;
  bool _showingRideRequest = false;

  // Active ride
  Map<String, dynamic>? _activeRide;
  bool _hasActiveRide = false;

  // Driver profile
  Map<String, dynamic>? _driverProfile;
  String _driverName = 'Driver';

  // Polling timer
  Timer? _pollTimer;

  // Navigation
  int _bottomNavIndex = 0;

  // Location fetch guard
  bool _locationFetched = false;

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

  // ─── Socket Connection ───
  Future<void> _connectSocket() async {
    final token = await ApiService.getToken();
    if (token == null) return;

    _socket = io.io(
      'https://zip-rick-4.onrender.com',
      <String, dynamic>{
        'transports': ['websocket'],
        'auth': {'token': token},
      },
    );

    _socket!.onConnect((_) {
      setState(() => _socketConnected = true);
      debugPrint('Socket connected');
    });

    _socket!.on('ride:new_request', (data) {
      debugPrint('Ride request received: $data');
      if (mounted && !_hasActiveRide) {
        setState(() {
          _rideRequest = data as Map<String, dynamic>;
          _showingRideRequest = true;
        });
      }
    });

    _socket!.on('ride:taken', (data) {
      debugPrint('Ride taken by another driver');
      if (mounted && _showingRideRequest) {
        setState(() {
          _showingRideRequest = false;
          _rideRequest = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride was taken by another driver'), duration: Duration(seconds: 2)),
        );
      }
    });

    _socket!.on('ride:accepted', (data) {
      debugPrint('Ride accepted by me: $data');
      setState(() => _hasActiveRide = true);
      _loadActiveRide();
    });

    _socket!.on('driver:status', (data) {
      debugPrint('Status update: $data');
    });

    _socket!.on('ride:cancelled', (data) {
      debugPrint('Ride cancelled: $data');
      setState(() {
        _hasActiveRide = false;
        _activeRide = null;
      });
    });

    _socket!.onDisconnect((_) {
      setState(() => _socketConnected = false);
      debugPrint('Socket disconnected');
    });

    _socket!.connect();
  }

  // ─── Location ───
  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationLoading = false);
          return;
        }
      }

      // Try last known first for speed
      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        setState(() {
          _currentPosition = pos;
          _locationLoading = false;
          _locationFetched = true;
        });
      }

      // Then get precise location
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (pos != null && mounted) {
        setState(() {
          _currentPosition = pos;
          _locationLoading = false;
          _locationFetched = true;
        });
        // Send location update via socket
        _sendLocationUpdate(pos);
      }
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() => _locationLoading = false);
    }
  }

  void _sendLocationUpdate(Position pos) {
    if (_socket != null && _socketConnected) {
      _socket!.emit('driver:location_update', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
    }
  }

  // ─── Load Profile ───
  Future<void> _loadProfile() async {
    try {
      final res = await ApiService.getProfile();
      if (res['data'] != null && res['data']['driver'] != null) {
        final driver = res['data']['driver'];
        final user = driver['user'];
        setState(() {
          _driverProfile = driver;
          _driverName = user?['full_name'] ?? 'Driver';
          _isOnline = driver['is_online'] == true;
        });
      }
    } catch (e) {
      debugPrint('Load profile error: $e');
    }
  }

  // ─── Online/Offline Toggle ───
  Future<void> _toggleOnline() async {
    if (_position == null) {
      await _fetchLocation();
      if (_position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to get GPS location. Please enable GPS.')),
          );
        }
        return;
      }
    }

    setState(() => _togglingOnline = true);
    try {
      final res = await ApiService.toggleOnline();
      if (res['data'] != null) {
        setState(() {
          _isOnline = res['data']['is_online'] == true;
          _togglingOnline = false;
        });

        // If going online, send location and start polling
        if (_isOnline && _currentPosition != null) {
          _sendLocationUpdate(_currentPosition!);
          _startPolling();
          // Emit via socket too
          if (_socket != null && _socketConnected) {
            _socket!.emit('driver:go_online');
          }
        } else {
          _stopPolling();
          if (_socket != null && _socketConnected) {
            _socket!.emit('driver:go_offline');
          }
        }
      }
    } catch (e) {
      setState(() => _togglingOnline = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  // ─── Polling for ride requests ───
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollForRides());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollForRides() async {
    if (!_isOnline || _hasActiveRide || _showingRideRequest) return;
    try {
      final res = await ApiService.getSearchingRides();
      if (res['data'] != null && res['data']['rides'] != null && (res['data']['rides'] as List).isNotEmpty) {
        final rides = res['data']['rides'] as List;
        if (mounted && !_hasActiveRide && !_showingRideRequest) {
          setState(() {
            _rideRequest = rides[0] as Map<String, dynamic>;
            _showingRideRequest = true;
          });
        }
      }
    } catch (e) {
      // Silently fail polling
    }
  }

  // ─── Accept/Reject Ride ───
  Future<void> _acceptRide() async {
    if (_rideRequest == null || _socket == null) return;
    final rideId = _rideRequest!['ride_id'];
    _socket!.emit('ride:accept', {'ride_id': rideId});
    setState(() {
      _showingRideRequest = false;
      _hasActiveRide = true;
    });
    // Wait a bit then load the active ride
    await Future.delayed(const Duration(seconds: 2));
    _loadActiveRide();
  }

  void _rejectRide() {
    setState(() {
      _showingRideRequest = false;
      _rideRequest = null;
    });
  }

  // ─── Load Active Ride ───
  Future<void> _loadActiveRide() async {
    try {
      final res = await ApiService.getActiveRide();
      if (res['data'] != null && res['data']['ride'] != null) {
        setState(() {
          _activeRide = res['data']['ride'];
          _hasActiveRide = true;
        });
      } else {
        setState(() {
          _activeRide = null;
          _hasActiveRide = false;
        });
      }
    } catch (e) {
      setState(() {
        _activeRide = null;
        _hasActiveRide = false;
      });
    }
  }

  // ─── Ride Status Updates ───
  void _updateRideStatus(String event) {
    if (_socket != null && _activeRide != null) {
      _socket!.emit(event, {'ride_id': _activeRide!['id']});
    }
  }

  // ─── Call Customer ───
  Future<void> _callCustomer() async {
    if (_activeRide == null || _activeRide!['customer'] == null) return;
    final phone = _activeRide!['customer']['user']?['phone'];
    if (phone != null) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  // ─── SOS ───
  Future<void> _sendSOS() async {
    if (_currentPosition == null) return;
    try {
      await ApiService.sendSOS(_currentPosition!.latitude, _currentPosition!.longitude);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS sent! Emergency contacts notified.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SOS failed: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  // ─── Support Ticket ───
  void _showSupportDialog() {
    final subjectCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Support Ticket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: msgCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (subjectCtrl.text.isEmpty || msgCtrl.text.isEmpty) return;
              try {
                await ApiService.createTicket(subjectCtrl.text, msgCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket created successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // ─── Logout ───
  Future<void> _logout() async {
    await ApiService.clearToken();
    if (_socket != null) {
      _socket!.emit('driver:go_offline');
      _socket!.disconnect();
    }
    _pollTimer?.cancel();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomeTab(context),
      _buildEarningsTab(context),
      _buildProfileTab(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_hasActiveRide ? 'Active Ride' : 'Zippy Driver'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_hasActiveRide)
            IconButton(
              icon: const Icon(Icons.support_agent),
              onPressed: _showSupportDialog,
              tooltip: 'Support',
            ),
          IconButton(
            icon: const Icon(Icons.sos, color: Colors.redAccent),
            onPressed: _sendSOS,
            tooltip: 'SOS Emergency',
          ),
          IconButton(
            icon: Icon(
              _socketConnected ? Icons.wifi : Icons.wifi_off,
              color: _socketConnected ? Colors.greenAccent : Colors.orange,
              size: 20,
            ),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_socketConnected ? 'Connected' : 'Disconnected. Trying to reconnect...')),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          pages[_bottomNavIndex],
          // Ride Request Popup
          if (_showingRideRequest && _rideRequest != null) _buildRideRequestPopup(),
          // Loading overlay for active ride
          if (_hasActiveRide && _activeRide == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (i) => setState(() => _bottomNavIndex = i),
        selectedItemColor: AppColors.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Position? get _position => _currentPosition;

  // ─── HOME TAB ───
  Widget _buildHomeTab(BuildContext context) {
    if (_hasActiveRide && _activeRide != null) {
      return _buildActiveRideView();
    }

    return Column(
      children: [
        // Online Status Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _isOnline ? AppColors.success : AppColors.textLight,
                child: Icon(
                  _isOnline ? Icons.power_settings_new : Icons.power_off,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnline ? 'You are ONLINE' : 'You are OFFLINE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isOnline ? AppColors.success : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOnline
                          ? 'Ride requests will appear here'
                          : 'Go online to receive ride requests',
                      style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isOnline,
                onChanged: _togglingOnline ? null : (_) => _toggleOnline(),
                activeColor: AppColors.success,
              ),
            ],
          ),
        ),

        // Map
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: _currentPosition != null
                ? FlutterMap(
                    options: MapOptions(
                      center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      zoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ziprick.driver',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            width: 80,
                            height: 80,
                            child: Icon(
                              Icons.electric_rickshaw_rounded,
                              size: 48,
                              color: _isOnline ? AppColors.success : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Fetching your location...'),
                      ],
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // Refresh Location Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _fetchLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Refresh Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // ─── ACTIVE RIDE VIEW ───
  Widget _buildActiveRideView() {
    final ride = _activeRide!;
    final pickup = ride['pickup_address'] ?? 'Pickup location';
    final drop = ride['drop_address'] ?? 'Drop location';
    final fare = ride['total_fare']?.toString() ?? '--';
    final status = ride['status'] ?? 'unknown';
    final driver = ride['driver'];

    String statusText = '';
    Color statusColor = AppColors.primary;
    switch (status) {
      case 'driver_assigned':
        statusText = 'Heading to pickup';
        statusColor = AppColors.warning;
        break;
      case 'driver_arrived':
        statusText = 'Arrived at pickup';
        statusColor = AppColors.success;
        break;
      case 'started':
        statusText = 'Ride in progress';
        statusColor = AppColors.primary;
        break;
      case 'completed':
        statusText = 'Ride completed';
        statusColor = AppColors.success;
        break;
      default:
        statusText = status;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: statusColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: $statusText',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor)),
                      Text('Fare: ₹$fare',
                          style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Pickup & Drop
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trip_origin, color: AppColors.success, size: 24),
                      const SizedBox(width: 12),
                      Expanded(child: Text(pickup, style: const TextStyle(fontSize: 16))),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    child: Column(
                      children: List.generate(3, (_) => Container(
                        width: 2, height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: Colors.grey.shade400,
                      )),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(child: Text(drop, style: const TextStyle(fontSize: 16))),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          if (status == 'driver_assigned') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateRideStatus('ride:arrived'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('I\'ve Arrived'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'driver_arrived') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateRideStatus('ride:start'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'started') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateRideStatus('ride:complete'),
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('Complete Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Call Customer
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _callCustomer,
              icon: const Icon(Icons.phone),
              label: const Text('Call Customer'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── RIDE REQUEST POPUP ───
  Widget _buildRideRequestPopup() {
    final req = _rideRequest!;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 8,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Countdown / urgency indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active, color: AppColors.accent, size: 18),
                    SizedBox(width: 6),
                    Text('New Ride Request!', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Distance
              if (req['distance_km'] != null)
                Text(
                  '${req['distance_km']} km away',
                  style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                ),
              const SizedBox(height: 12),
              // Pickup
              Row(
                children: [
                  const Icon(Icons.trip_origin, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      req['pickup_address'] ?? 'Pickup',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Drop
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      req['drop_address'] ?? 'Drop',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Fare
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Fare: ', style: TextStyle(fontSize: 18)),
                  Text(
                    '₹${req['total_fare'] ?? '--'}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Accept / Reject buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _acceptRide,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _rejectRide,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── EARNINGS TAB ───
  Widget _buildEarningsTab(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService.getEarnings(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error: ${snapshot.error.toString().replaceFirst("Exception: ", "")}'),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = snapshot.data?['data'] ?? {};
        final totalEarnings = data['total_earnings']?.toString() ?? '0';
        final todayEarnings = data['today_earnings']?.toString() ?? '0';
        final weekEarnings = data['week_earnings']?.toString() ?? '0';
        final totalRides = data['total_rides']?.toString() ?? '0';
        final rating = data['rating_avg']?.toString() ?? '0';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Total Earnings Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Earnings', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('₹$totalEarnings',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('$totalRides rides completed',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildEarningCard('Today', '₹$todayEarnings', Icons.today, AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildEarningCard('This Week', '₹$weekEarnings', Icons.date_range, AppColors.warning),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Rating
              Card(
                child: ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber, size: 32),
                  title: const Text('Rating'),
                  trailing: Text('$rating / 5',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEarningCard(String label, String amount, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(amount, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }

  // ─── PROFILE TAB ───
  Widget _buildProfileTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D',
                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(_driverName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isOnline ? AppColors.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: _isOnline ? AppColors.success : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Ride History
          const Text('Recent Rides', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          FutureBuilder<Map<String, dynamic>>(
            future: ApiService.getRideHistory(),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error loading rides');
              }
              final rides = snapshot.data?['data']?['rides'] ??
                  snapshot.data?['data']?['rows'] ?? [];
              if (rides is! List || rides.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No rides yet')),
                  ),
                );
              }
              return Column(
                children: rides.take(5).map<Widget>((ride) {
                  final r = ride as Map<String, dynamic>;
                  final status = r['status'] ?? '';
                  final fare = r['total_fare']?.toString() ?? '--';
                  final date = r['created_at'] ?? '';
                  String dateStr = '';
                  try {
                    final dt = DateTime.parse(date);
                    dateStr = DateFormat('MMM dd, HH:mm').format(dt);
                  } catch (_) {
                    dateStr = date;
                  }
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        status == 'completed' ? Icons.check_circle : Icons.cancel,
                        color: status == 'completed' ? AppColors.success : Colors.red,
                      ),
                      title: Text('₹$fare', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$status • $dateStr'),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
