import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZipRickApp());
}

final ApiService api = ApiService();

class ZipRickApp extends StatelessWidget {
  const ZipRickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zip-Rick',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF), primary: const Color(0xFF6C63FF)),
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/login': (ctx) => const LoginScreen(),
        '/home': (ctx) => const HomeScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() { super.initState(); Future.delayed(const Duration(seconds: 2), () => Navigator.pushReplacementNamed(context, '/login')); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF6C63FF),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.electric_rickshaw_rounded, size: 120, color: Colors.white),
      const SizedBox(height: 24),
      Text('Zip-Rick', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Text('Your E-Rickshaw, Instantly', style: TextStyle(color: Colors.white70, fontSize: 16)),
      const SizedBox(height: 60), const CircularProgressIndicator(color: Colors.white),
    ])),
  );
}

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
  bool _isLoading = false;
  String _errorMsg = '';

  @override
  void dispose() { _phoneCtrl.dispose(); _otpCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _sendOTP() async {
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      final res = await api.sendOTP(_phoneCtrl.text);
      if (res['success']) { setState(() => _otpSent = true); }
      else { _errorMsg = res['error']?['message'] ?? 'Failed'; }
    } catch (e) { _errorMsg = 'Cannot connect to server'; }
    setState(() => _isLoading = false);
  }

  Future<void> _verifyOTP() async {
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      final res = await api.verifyOTP(_phoneCtrl.text, _otpCtrl.text, _nameCtrl.text, 'customer');
      if (res['success']) { if (!mounted) return; Navigator.pushReplacementNamed(context, '/home'); }
      else { _errorMsg = res['error']?['message'] ?? 'Failed'; }
    } catch (e) { _errorMsg = 'Cannot connect to server'; }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 60), const Icon(Icons.electric_rickshaw_rounded, size: 64, color: Color(0xFF6C63FF)),
      const SizedBox(height: 24),
      Text(_otpSent ? 'Verify OTP' : 'Welcome to Zip-Rick', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(_otpSent ? 'Enter OTP' : 'Enter your phone number', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
      const SizedBox(height: 40),
      TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
      if (_otpSent) ...[
        const SizedBox(height: 16), TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
        const SizedBox(height: 16), TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'OTP', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
      ],
      if (_errorMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorMsg, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _isLoading ? null : (_otpSent ? _verifyOTP : _sendOTP), child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_otpSent ? 'Verify & Login' : 'Send OTP')),
    ]))),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(26.1445, 91.7362); // Guwahati default
  bool _loading = false;

  Future<void> _goToMyLocation() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_currentLocation, 15);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get location. Make sure location is enabled.')),
      );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zip-Rick')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(center: _currentLocation, zoom: 15),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.ziprick.customer'),
              MarkerLayer(markers: [
                Marker(point: _currentLocation, width: 40, height: 40, child: const Icon(Icons.my_location, color: Color(0xFF6C63FF), size: 30)),
              ]),
            ],
          ),
          // My Location Button
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _goToMyLocation,
              backgroundColor: Colors.white,
              child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: Color(0xFF6C63FF)),
            ),
          ),
          // Info text
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '?? Tap the location button to find your current location',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Rides'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ]),
    );
  }
}
