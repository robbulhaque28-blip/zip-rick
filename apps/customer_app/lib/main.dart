import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:geolocator/geolocator.dart";
import "package:url_launcher/url_launcher.dart";
import "dart:convert";
import "package:http/http.dart" as http;
import "services/api_service.dart";

void main() { WidgetsFlutterBinding.ensureInitialized(); SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent)); runApp(const ZipRickApp()); }

final ApiService api = ApiService();

class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF5A52D5);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFA726);
  static const bg = Color(0xFFF5F6FA);
  static const card = Colors.white;
  static const textDark = Color(0xFF1F2937);
  static const textLight = Color(0xFF9CA3AF);
}

class ZipRickApp extends StatelessWidget {
  const ZipRickApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: "Zip-Rick", debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.primary, scaffoldBackgroundColor: AppColors.bg,
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0, backgroundColor: Colors.white, foregroundColor: AppColors.textDark)),
    initialRoute: "/", onGenerateRoute: (s) {
      switch (s.name) {
        case "/": return MaterialPageRoute(builder: (_) => const SplashScreen());
        case "/welcome": return MaterialPageRoute(builder: (_) => const WelcomeScreen());
        case "/login": return MaterialPageRoute(builder: (_) => const LoginScreen());
        case "/register": return MaterialPageRoute(builder: (_) => const RegisterScreen());
        case "/home": return MaterialPageRoute(builder: (_) => const MainScreen());
        case "/refer": return MaterialPageRoute(builder: (_) => const ReferralPage());
        default: return MaterialPageRoute(builder: (_) => const SplashScreen());
      }
    },
  );
}

// ─── SPLASH ───
class SplashScreen extends StatefulWidget { const SplashScreen({super.key}); @override State<SplashScreen> createState() => _SplashScreenState(); }
class _SplashScreenState extends State<SplashScreen> {
  @override void initState() { super.initState(); Future.delayed(const Duration(seconds: 2), () => Navigator.pushReplacementNamed(context, "/welcome")); }
  @override Widget build(BuildContext context) => const Scaffold(backgroundColor: AppColors.primary, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.electric_rickshaw_rounded, size: 120, color: Colors.white), SizedBox(height: 24),
    Text("Zip-Rick", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
    SizedBox(height: 8), Text("Your E-Rickshaw, Instantly", style: TextStyle(color: Colors.white70, fontSize: 16)),
    SizedBox(height: 60), CircularProgressIndicator(color: Colors.white)])));
}

// ─── WELCOME ───
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.primary,
    body: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Spacer(flex: 2), Container(width: 120, height: 120, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.electric_rickshaw_rounded, size: 60, color: Colors.white)),
      const SizedBox(height: 24), const Text("Zip-Rick", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
      const Text("Your E-Rickshaw, Instantly", style: TextStyle(color: Colors.white70, fontSize: 16)),
      const Spacer(flex: 2),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
        child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, "/login"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
        child: SizedBox(width: double.infinity, height: 56, child: OutlinedButton(onPressed: () => Navigator.pushNamed(context, "/register"),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text("Register", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
      const Spacer(flex: 1),
    ]))));
}

// ─── LOGIN ───
class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: "+91"); final _otpCtrl = TextEditingController();
  bool _otpSent = false; bool _loading = false; String _error = "";
  @override void dispose() { _phoneCtrl.dispose(); _otpCtrl.dispose(); super.dispose(); }
  Future<void> _sendOTP() async {
    setState(() { _loading = true; _error = ""; });
    try { final r = await api.sendOTP(_phoneCtrl.text); if (r["success"]) setState(() => _otpSent = true); else setState(() => _error = r["error"]?["message"] ?? "Failed"); }
    catch (e) { setState(() => _error = "Cannot connect to server"); }
    setState(() => _loading = false);
  }
  Future<void> _verifyOTP() async {
    setState(() { _loading = true; _error = ""; });
    try {
      final r = await api.verifyOTP(_phoneCtrl.text, _otpCtrl.text, "", "customer");
      if (r["success"]) { if (!mounted) return; Navigator.pushReplacementNamed(context, "/home"); }
      else {
        setState(() { _error = r["error"]?["message"] ?? "Failed"; });
        if (_error.contains("Name") || _error.contains("not found")) _error = "Account not found. Please Register.";
      }
    } catch (e) { setState(() => _error = "Cannot connect"); }
    setState(() => _loading = false);
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 80), Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.electric_rickshaw_rounded, size: 40, color: AppColors.primary)),
    const SizedBox(height: 24), const Text("Welcome Back", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark)),
    const SizedBox(height: 8), const Text("Login to your account", style: TextStyle(color: AppColors.textLight, fontSize: 16)),
    const SizedBox(height: 40),
    TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Phone Number", prefixIcon: const Icon(Icons.phone_android), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    if (_otpSent) ...[const SizedBox(height: 16), TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: "OTP", prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))],
    if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(_error, style: const TextStyle(color: Colors.red)))),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP),
      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_otpSent ? "Verify OTP" : "Send OTP", style: const TextStyle(fontSize: 16))))),
  ]))));
}

// ─── REGISTER ───
class RegisterScreen extends StatefulWidget { const RegisterScreen({super.key}); @override State<RegisterScreen> createState() => _RegisterScreenState(); }
class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneCtrl = TextEditingController(text: "+91"); final _otpCtrl = TextEditingController(); final _nameCtrl = TextEditingController();
  bool _otpSent = false; bool _loading = false; String _error = "";
  @override void dispose() { _phoneCtrl.dispose(); _otpCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }
  Future<void> _sendOTP() async {
    setState(() { _loading = true; _error = ""; });
    try { final r = await api.sendOTP(_phoneCtrl.text); if (r["success"]) setState(() => _otpSent = true); else setState(() => _error = r["error"]?["message"] ?? "Failed"); }
    catch (e) { setState(() => _error = "Cannot connect"); }
    setState(() => _loading = false);
  }
  Future<void> _verifyOTP() async {
    if (_nameCtrl.text.trim().isEmpty) { setState(() => _error = "Name is required"); return; }
    setState(() { _loading = true; _error = ""; });
    try {
      final r = await api.verifyOTP(_phoneCtrl.text, _otpCtrl.text, _nameCtrl.text, "customer");
      if (r["success"]) { if (!mounted) return; Navigator.pushReplacementNamed(context, "/home"); }
      else { setState(() => _error = r["error"]?["message"] ?? "Failed"); }
    } catch (e) { setState(() => _error = "Cannot connect"); }
    setState(() => _loading = false);
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 80), Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_add, size: 40, color: AppColors.primary)),
    const SizedBox(height: 24), const Text("Create Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark)),
    const SizedBox(height: 8), const Text("Register as a new customer", style: TextStyle(color: AppColors.textLight, fontSize: 16)),
    const SizedBox(height: 40),
    TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Phone Number", prefixIcon: const Icon(Icons.phone_android), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    if (_otpSent) ...[
      const SizedBox(height: 16), TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: "Full Name", prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 16), TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: "OTP", prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    ],
    if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(_error, style: const TextStyle(color: Colors.red)))),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP),
      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_otpSent ? "Create Account" : "Send OTP", style: const TextStyle(fontSize: 16))))),
  ]))));
}

// ═══════════════════════════════════════════
// MAIN SCREEN WITH MODERN UI
// ═══════════════════════════════════════════
class MainScreen extends StatefulWidget { const MainScreen({super.key}); @override State<MainScreen> createState() => _MainScreenState(); }
class _MainScreenState extends State<MainScreen> {
  int _currentTab = 0;
  @override Widget build(BuildContext context) => Scaffold(
    body: [const HomePage(), const RideHistoryPage(), const ProfilePage()][_currentTab],
    bottomNavigationBar: Container(
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: BottomNavigationBar(currentIndex: _currentTab, onTap: (i) => setState(() => _currentTab = i),
        selectedItemColor: AppColors.primary, unselectedItemColor: AppColors.textLight,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: "Rides"),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
        ])));
}

// ═══════════════════════════════════════════
// HOME PAGE - MODERN UI
// ═══════════════════════════════════════════
class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  final _pickupCtrl = TextEditingController(); final _dropCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  LatLng _currentLocation = const LatLng(26.1445, 91.7362);
  LatLng? _pickupLocation; LatLng? _dropLocation;
  bool _loading = true; bool _isBooking = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _appliedPromo; int _discount = 0;
  bool _showBookingSheet = false; // Controls the bottom sheet

  @override void initState() { super.initState(); _getCurrentLocation(); }
  @override void dispose() { _pickupCtrl.dispose(); _dropCtrl.dispose(); _promoCtrl.dispose(); super.dispose(); }

  void _sosAlert() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.warning_rounded, color: Colors.red, size: 28), SizedBox(width: 8), Text("SOS Emergency", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
      content: const Text("This will alert our support team immediately."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async { Navigator.pop(ctx);
          try { final r = await api.sos(); if (r["success"]) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS sent! Help is on the way."))); }
          catch (_) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send SOS."))); }
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Send SOS", style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (await Geolocator.requestPermission() == LocationPermission.whileInUse || await Geolocator.checkPermission() == LocationPermission.always) {
        final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 10));
        setState(() { _currentLocation = LatLng(p.latitude, p.longitude); _pickupLocation = _currentLocation; _pickupCtrl.text = "Current Location"; _loading = false; });
        _mapController.move(_currentLocation, 15);
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _searchPlaces(String q, bool isPickup) async {
    if (q.length < 3) { setState(() => _searchResults = []); return; }
    try {
      final lat = _currentLocation.latitude; final lon = _currentLocation.longitude;
      final r = await http.get(Uri.parse("https://nominatim.openstreetmap.org/search?q=" + Uri.encodeComponent(q) + "&format=json&limit=5&countrycodes=in"), headers: {"User-Agent": "ZipRick/1.0"});
      if (r.statusCode == 200) {
        final List d = jsonDecode(r.body);
        setState(() { _searchResults = d.map((e) => {"display_name": e["display_name"] ?? "", "lat": double.parse(e["lat"] ?? "0"), "lon": double.parse(e["lon"] ?? "0"), "isPickup": isPickup}).toList(); });
      }
    } catch (_) {}
  }

  void _selectPlace(Map<String, dynamic> p) {
    final ll = LatLng(p["lat"], p["lon"]);
    setState(() {
      if (p["isPickup"] == true) { _pickupLocation = ll; _pickupCtrl.text = p["display_name"].toString(); }
      else { _dropLocation = ll; _dropCtrl.text = p["display_name"].toString(); }
      _searchResults = [];
    });
    _mapController.move(ll, 15);
  }

  void _showBookingPanel() {
    setState(() => _showBookingSheet = true);
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        // Get inline fare when both locations are set
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text("Book a Ride", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Pickup field
              Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Column(children: [
                  TextField(controller: _pickupCtrl, decoration: const InputDecoration(labelText: "Pickup", prefixIcon: Icon(Icons.circle, color: Colors.green, size: 12), border: InputBorder.none, contentPadding: EdgeInsets.all(16)), onChanged: (v) => _searchPlaces(v, true)),
                  ..._searchResults.where((p) => p["isPickup"] == true).take(3).map((p) => ListTile(dense: true, leading: const Icon(Icons.location_on, size: 16), title: Text(p["display_name"].toString(), style: const TextStyle(fontSize: 13)), onTap: () { _selectPlace(p); setSheetState(() {}); })),
                  const Divider(height: 1),
                  TextField(controller: _dropCtrl, decoration: const InputDecoration(labelText: "Drop", prefixIcon: Icon(Icons.location_on, color: Colors.red, size: 12), border: InputBorder.none, contentPadding: EdgeInsets.all(16)), onChanged: (v) => _searchPlaces(v, false)),
                  ..._searchResults.where((p) => p["isPickup"] == false).take(3).map((p) => ListTile(dense: true, leading: const Icon(Icons.location_on, size: 16), title: Text(p["display_name"].toString(), style: const TextStyle(fontSize: 13)), onTap: () { _selectPlace(p); setSheetState(() {}); })),
                ])),
              const SizedBox(height: 20),
              // Proceed button
              SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
                onPressed: _pickupLocation == null || _dropLocation == null ? null : () { Navigator.pop(ctx); _getFare(); },
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isBooking ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Search for Ride", style: TextStyle(fontSize: 16)),
              )),
            ]),
          ),
        );
      }),
    ).whenComplete(() => setState(() => _showBookingSheet = false));
  }

  Future<void> _getFare() async {
    if (_pickupLocation == null || _dropLocation == null) return;
    setState(() => _isBooking = true);
    try {
      final r = await api.getFareEstimate(_pickupLocation!.latitude, _pickupLocation!.longitude, _dropLocation!.latitude, _dropLocation!.longitude);
      if (r["success"]) {
        setState(() { _isBooking = false; });
        _showPayment((r["data"]?["total_fare"] ?? 30).toInt(), r["data"]);
      } else { setState(() => _isBooking = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r["error"]?["message"] ?? "Could not get fare"))); }
    } catch (e) { setState(() => _isBooking = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection error"))); }
  }

  void _showPayment(int amount, Map<String, dynamic>? fareData) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Your Trip", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 8),
          // Pickup & Drop summary
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Row(children: [const Icon(Icons.circle, color: Colors.green, size: 10), const SizedBox(width: 12), Expanded(child: Text(_pickupCtrl.text, style: const TextStyle(fontSize: 14)))]),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Column(children: List.generate(3, (_) => Container(width: 2, height: 3, margin: const EdgeInsets.symmetric(vertical: 1), color: Colors.grey.shade400)))),
              Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 14), const SizedBox(width: 10), Expanded(child: Text(_dropCtrl.text, style: const TextStyle(fontSize: 14)))]),
            ])),
          const SizedBox(height: 16),
          // Fare breakdown
          if (fareData != null) ...[
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                _fareRow("Base fare", "₹${fareData['base_fare']?.toStringAsFixed(0) ?? '30'}"),
                const Divider(height: 12),
                _fareRow("Distance", "₹${fareData['distance_fare']?.toStringAsFixed(0) ?? '0'}"),
                const Divider(height: 12),
                _fareRow("Time", "₹${fareData['time_fare']?.toStringAsFixed(0) ?? '0'}"),
                if ((fareData['night_charges'] ?? 0) > 0) ...[const Divider(height: 12), _fareRow("Night charges", "₹${fareData['night_charges']?.toStringAsFixed(0)}")],
                if ((fareData['peak_charges'] ?? 0) > 0) ...[const Divider(height: 12), _fareRow("Peak charges", "₹${fareData['peak_charges']?.toStringAsFixed(0)}")],
                if (_discount > 0) ...[const Divider(height: 12), _fareRow("Discount", "-₹$_discount", color: Colors.green)],
                const Divider(height: 12),
                _fareRow("Total", "₹${amount - _discount}", bold: true),
              ])),
            const SizedBox(height: 16),
          ],
          // Promo code
          Row(children: [
            Expanded(child: TextField(controller: _promoCtrl, decoration: InputDecoration(labelText: "Promo code", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () {
              if (_promoCtrl.text.isEmpty) return;
              final code = _promoCtrl.text.trim().toUpperCase();
              if (code == "ZIP50") { setModalState(() { _discount = (amount * 0.5).toInt(); _appliedPromo = code; }); }
              else if (code == "ZIP20") { setModalState(() { _discount = 20; _appliedPromo = code; }); }
              else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid code"))); }
            }, style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)), child: const Text("Apply")),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: SizedBox(height: 52, child: ElevatedButton(onPressed: () { Navigator.pop(ctx); _bookRide("cash"); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Cash")))),
            const SizedBox(width: 12),
            Expanded(child: SizedBox(height: 52, child: ElevatedButton(onPressed: () { Navigator.pop(ctx); _bookRide("upi"); }, style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("UPI")))),
          ]),
          const SizedBox(height: 8),
        ]))));
  }

  Widget _fareRow(String label, String value, {bool bold = false, Color? color}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: color ?? AppColors.textLight, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color, fontSize: 14)),
    ]);
  }

  Future<void> _bookRide(String pm) async {
    if (_pickupLocation == null || _dropLocation == null) return;
    setState(() => _isBooking = true);
    try {
      final r = await api.bookRide(_pickupLocation!.latitude, _pickupLocation!.longitude, _pickupCtrl.text, _dropLocation!.latitude, _dropLocation!.longitude, _dropCtrl.text, pm, _appliedPromo ?? "");
      if (r["success"]) { if (!mounted) return; Navigator.push(context, MaterialPageRoute(builder: (_) => RideTrackingPage(rideData: r["data"]["ride"]))); }
      else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r["error"]?["message"] ?? "Booking failed"))); }
    } catch (_) {}
    setState(() => _isBooking = false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Zip-Rick", style: TextStyle(fontWeight: FontWeight.bold)), actions: [
      Container(margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
        child: IconButton(icon: const Icon(Icons.headset_mic, color: AppColors.primary), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage())))),
      Container(margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
        child: IconButton(icon: const Icon(Icons.warning_rounded, color: Colors.red), onPressed: _sosAlert)),
    ]),
    body: Stack(children: [
      // Map
      _loading
        ? const Center(child: CircularProgressIndicator())
        : FlutterMap(mapController: _mapController, options: MapOptions(center: _currentLocation, zoom: 15, onLongPress: (tapPos, latlng) {
            setState(() { if (_dropLocation == null) { _dropLocation = latlng; _dropCtrl.text = "Pinned"; } else { _pickupLocation = latlng; _pickupCtrl.text = "Pinned"; _dropLocation = null; _dropCtrl.clear(); } });
          }), children: [
            TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.ziprick.customer"),
            MarkerLayer(markers: [
              if (_pickupLocation != null) Marker(point: _pickupLocation!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 35)),
              if (_dropLocation != null) Marker(point: _dropLocation!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 35)),
            ]),
          ]),
      // "Where to?" floating card
      Positioned(left: 16, right: 16, top: MediaQuery.of(context).padding.top + 8,
        child: GestureDetector(
          onTap: _showBookingPanel,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))]),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.search, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_pickupCtrl.text.isNotEmpty ? _pickupCtrl.text : "Current Location", style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
                const SizedBox(height: 2),
                Text(_dropCtrl.text.isNotEmpty ? _dropCtrl.text : "Where to?", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _dropCtrl.text.isNotEmpty ? AppColors.textDark : AppColors.textLight)),
              ])),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
            ]),
          ),
        ),
      ),
      // My Location button
      Positioned(right: 16, bottom: 30, child: FloatingActionButton(mini: true, onPressed: _getCurrentLocation, backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: AppColors.primary))),
    ]),
  );
}

// ═══════════════════════════════════════════
// RIDE TRACKING - MODERN
// ═══════════════════════════════════════════
class RideTrackingPage extends StatefulWidget { final Map<String, dynamic> rideData; const RideTrackingPage({super.key, required this.rideData}); @override State<RideTrackingPage> createState() => _RideTrackingPageState(); }
class _RideTrackingPageState extends State<RideTrackingPage> {
  bool _rideCompleted = false; int _rating = 0; bool _driverFound = false;
  Map<String, dynamic>? _driverInfo; bool _ratingSubmitted = false;
  @override void initState() { super.initState(); _checkDriver(); }
  void _checkDriver() {
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      try {
        final r = await api.getActiveRide();
        if (r["success"] && r["data"] != null && r["data"]["ride"] != null && r["data"]["ride"]["status"] == "driver_assigned") {
          setState(() { _driverFound = true; _driverInfo = r["data"]["ride"]["driver"]; }); return;
        }
        if (mounted) _checkDriver();
      } catch (_) { if (mounted) _checkDriver(); }
    });
  }
  void _shareRide() { final text = "I'm riding with Zip-Rick!\n📍 ${widget.rideData["pickup_address"] ?? "N/A"}\n🏁 ${widget.rideData["drop_address"] ?? "N/A"}\n💰 ₹${widget.rideData["total_fare"] ?? 0}"; Clipboard.setData(ClipboardData(text: text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trip details copied!"))); }

  @override Widget build(BuildContext context) {
    if (_rideCompleted) {
      return Scaffold(
        appBar: AppBar(title: const Text("Rate Your Ride")),
        body: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 100, height: 100, decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.celebration, color: AppColors.success, size: 48)),
          const SizedBox(height: 24), const Text("Ride Completed!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), const Text("How was your ride?", style: TextStyle(color: AppColors.textLight)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(icon: Icon(i < _rating ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 44), onPressed: () => setState(() => _rating = i + 1)))),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _rating == 0 ? null : () async {
            if (_ratingSubmitted) return;
            try { await api.rateRide(widget.rideData["id"], _rating); setState(() => _ratingSubmitted = true); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rating submitted!"))); } catch (_) {}
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainScreen()), (route) => false);
          }, style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _ratingSubmitted ? const Text("Submitted") : const Text("Submit Rating"))),
        ])));
    }
    return Scaffold(
      appBar: AppBar(title: Text(_driverFound ? "Driver Found!" : "Finding Driver..."), actions: [IconButton(icon: const Icon(Icons.share_rounded), onPressed: _shareRide)]),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        const SizedBox(height: 20),
        AnimatedContainer(duration: const Duration(milliseconds: 500),
          width: 100, height: 100,
          decoration: BoxDecoration(color: (_driverFound ? AppColors.success : AppColors.warning).withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(_driverFound ? Icons.check_circle_rounded : Icons.hourglass_top_rounded, color: _driverFound ? AppColors.success : AppColors.warning, size: 48)),
        const SizedBox(height: 20),
        Text(_driverFound ? "Driver Assigned!" : "Searching for nearby drivers...", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _driverFound ? AppColors.success : AppColors.warning)),
        const SizedBox(height: 4),
        Text("Ride #${widget.rideData["ride_number"] ?? "N/A"}", style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 24),
        if (_driverFound) LinearProgressIndicator(color: AppColors.success, backgroundColor: AppColors.success.withOpacity(0.1)) else const CircularProgressIndicator(),
        const SizedBox(height: 24),
        // Trip details card
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
          child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            Row(children: [Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)), const SizedBox(width: 12), Expanded(child: Text("${widget.rideData["pickup_address"] ?? "N/A"}"))]),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4), child: Column(children: List.generate(3, (_) => Container(width: 2, height: 4, margin: const EdgeInsets.symmetric(vertical: 1), color: Colors.grey.shade400)))),
            Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 14), const SizedBox(width: 10), Expanded(child: Text("${widget.rideData["drop_address"] ?? "N/A"}"))]),
            const Divider(height: 20),
            Row(children: [const Icon(Icons.currency_rupee, size: 18), const SizedBox(width: 8), Text("₹${widget.rideData["total_fare"] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
            if (_driverFound && _driverInfo != null) ...[
              const Divider(height: 20),
              Row(children: [const Icon(Icons.person, color: AppColors.primary, size: 20), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_driverInfo!["user"]?["full_name"] ?? "Driver", style: const TextStyle(fontWeight: FontWeight.bold)), Text(_driverInfo!["vehicle"]?["vehicle_number"] ?? "", style: TextStyle(fontSize: 12, color: Colors.grey[600]))]))]),
              const Divider(height: 1),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone, color: Colors.green), title: Text(_driverInfo!["user"]?["phone"] ?? "+91XXXXXXXXXX"), trailing: IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () async { final phone = _driverInfo!["user"]?["phone"] ?? ""; if (phone.isNotEmpty) await launchUrl(Uri.parse("tel:$phone")); })),
            ],
          ])),
        ),
        const SizedBox(height: 20),
        _driverFound
          ? SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => setState(() => _rideCompleted = true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Complete Ride")))
          : SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { try { final r = await api.cancelRide(widget.rideData["id"]); if (r["success"]) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride cancelled"))); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainScreen()), (route) => false); } } catch (_) {} }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Cancel Ride"))),
      ])),
    );
  }
}

// ═══════════════════════════════════════════
// RIDE HISTORY - FIXED
// ═══════════════════════════════════════════
class RideHistoryPage extends StatefulWidget { const RideHistoryPage({super.key}); @override State<RideHistoryPage> createState() => _RideHistoryPageState(); }
class _RideHistoryPageState extends State<RideHistoryPage> {
  List _rides = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await api.getRideHistory(); if (r["success"]) {
      final data = r["data"];
      setState(() { _rides = data["rides"] ?? data["rows"] ?? []; _loading = false; });
    } } catch (_) { setState(() => _loading = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("My Rides")),
    body: _loading ? const Center(child: CircularProgressIndicator())
    : _rides.isEmpty
      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.directions_car, size: 40, color: AppColors.primary)), const SizedBox(height: 16), const Text("No rides yet", style: TextStyle(fontSize: 16))]))
      : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _rides.length, itemBuilder: (ctx, i) {
          final r = _rides[i]; final status = r["status"] ?? ""; final fare = r["total_fare"]?.toString() ?? "0"; final date = r["created_at"] ?? "";
          String dateStr = ""; try { final dt = DateTime.parse(date); dateStr = "${dt.day}/${dt.month}/${dt.year}"; } catch (_) { dateStr = date; }
          return Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: (status == "completed" ? AppColors.success : AppColors.warning).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(status == "completed" ? Icons.check_circle_rounded : Icons.pending_rounded, color: status == "completed" ? AppColors.success : AppColors.warning)),
              title: Text("Ride #${r["ride_number"] ?? ""}", style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              trailing: Text("₹$fare", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
            ));
        })),
  );
}

// ═══════════════════════════════════════════
// PROFILE
// ═══════════════════════════════════════════
class ProfilePage extends StatefulWidget { const ProfilePage({super.key}); @override State<ProfilePage> createState() => _ProfilePageState(); }
class _ProfilePageState extends State<ProfilePage> { Map? _profile; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await api.getProfile(); if (r["success"]) setState(() { _profile = r["data"]; _loading = false; }); } catch (_) { setState(() => _loading = false); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Profile")),
    body: _loading ? const Center(child: CircularProgressIndicator())
    : ListView(padding: const EdgeInsets.all(24), children: [
      Center(child: Column(children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_rounded, size: 40, color: AppColors.primary)),
        const SizedBox(height: 12), Text(_profile?["user"]?["full_name"] ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        Text(_profile?["user"]?["phone"] ?? "", style: const TextStyle(color: AppColors.textLight)),
      ])),
      const SizedBox(height: 32),
      Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Column(children: [
          ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.star_rounded, color: Colors.amber)), title: const Text("Rating"), trailing: Text("${_profile?["customer"]?["rating"] ?? "0.0"} / 5", style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.directions_car_rounded, color: AppColors.primary)), title: const Text("Total Rides"), trailing: Text("${_profile?["customer"]?["total_rides"] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.card_giftcard_rounded, color: Colors.purple)), title: const Text("Refer & Earn"), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralPage()))),
        ])),
    ]));
}

// ═══════════════════════════════════════════
// REFERRAL
// ═══════════════════════════════════════════
class ReferralPage extends StatefulWidget { const ReferralPage({super.key}); @override State<ReferralPage> createState() => _ReferralPageState(); }
class _ReferralPageState extends State<ReferralPage> { String? _code; int _points = 0; int _totalReferrals = 0; bool _loading = true; final _referCtrl = TextEditingController(); bool _applying = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await api.getReferralStats(); if (r["success"]) { setState(() { _code = r["data"]["referral_code"]; _points = r["data"]["loyalty_points"] ?? 0; _totalReferrals = r["data"]["total_referrals"] ?? 0; _loading = false; }); } } catch (_) { setState(() => _loading = false); } }
  void _invite() async { if (_code == null) return; final text = "Join Zip-Rick! Use my code: $_code and get ₹50 bonus!"; Clipboard.setData(ClipboardData(text: text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral code copied!"))); }
  Future<void> _applyCode() async { if (_referCtrl.text.isEmpty) return; setState(() => _applying = true); try { final r = await api.applyReferral(_referCtrl.text.trim()); if (r["success"]) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral applied!"))); _referCtrl.clear(); _load(); } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r["error"]?["message"] ?? "Failed"))); } } catch (_) {} setState(() => _applying = false); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Refer & Earn")),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(24), children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Icon(Icons.card_giftcard_rounded, size: 60, color: Colors.white), const SizedBox(height: 12),
          const Text("Your Referral Code", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 8),
          Text(_code ?? "", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(children: [Text("$_points", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), const Text("Points", style: TextStyle(color: Colors.white70))]),
            Column(children: [Text("$_totalReferrals", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), const Text("Referred", style: TextStyle(color: Colors.white70))]),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _invite, icon: const Icon(Icons.share_rounded), label: const Text("Invite Friends"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ])),
      const SizedBox(height: 32),
      const Text("Have a referral code?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)), const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _referCtrl, decoration: InputDecoration(labelText: "Enter code", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
        const SizedBox(width: 12),
        ElevatedButton(onPressed: _applying ? null : _applyCode, style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24)), child: _applying ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Apply")),
      ]),
    ]));
}

// ═══════════════════════════════════════════
// SUPPORT
// ═══════════════════════════════════════════
class SupportPage extends StatefulWidget { const SupportPage({super.key}); @override State<SupportPage> createState() => _SupportPageState(); }
class _SupportPageState extends State<SupportPage> { final _subjectCtrl = TextEditingController(); final _descCtrl = TextEditingController(); bool _loading = false; List _tickets = []; bool _loadTickets = true;
  @override void initState() { super.initState(); _fetchTickets(); }
  Future<void> _fetchTickets() async { try { final r = await api.getSupportTickets(); if (r["success"]) setState(() { _tickets = r["data"] ?? []; _loadTickets = false; }); } catch (_) { setState(() => _loadTickets = false); } }
  Future<void> _createTicket() async { if (_subjectCtrl.text.isEmpty || _descCtrl.text.isEmpty) return; setState(() => _loading = true); try { final r = await api.createSupportTicket(_subjectCtrl.text, _descCtrl.text); if (r["success"]) { _subjectCtrl.clear(); _descCtrl.clear(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket created!"))); _fetchTickets(); } } catch (_) {} setState(() => _loading = false); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Support")),
    body: _loadTickets ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Create a Ticket", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)), const SizedBox(height: 12),
          TextField(controller: _subjectCtrl, decoration: InputDecoration(labelText: "Subject", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 8),
          TextField(controller: _descCtrl, decoration: InputDecoration(labelText: "Describe your issue", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), maxLines: 3),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _createTicket, style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Submit"))),
        ])),
      const SizedBox(height: 24),
      const Text("My Tickets", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      const SizedBox(height: 12),
      if (_tickets.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text("No tickets yet", style: TextStyle(color: AppColors.textLight))))
      else ..._tickets.map((t) => Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: (t["priority"] == "urgent" ? Colors.red : AppColors.primary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(t["priority"] == "urgent" ? Icons.warning_rounded : Icons.support_agent_rounded, color: t["priority"] == "urgent" ? Colors.red : AppColors.primary)),
          title: Text(t["subject"] ?? "Support", style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(t["status"] ?? "open", style: const TextStyle(fontSize: 12)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (t["priority"] == "urgent" ? Colors.red : Colors.blue).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(t["priority"] ?? "medium", style: TextStyle(fontSize: 11, color: t["priority"] == "urgent" ? Colors.red : Colors.blue))))),
      ),
    ]));
}