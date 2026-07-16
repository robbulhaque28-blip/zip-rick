import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:geolocator/geolocator.dart";
import "dart:html" as html;
import "dart:convert";
import "package:http/http.dart" as http;
import "services/api_service.dart";

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const ZipRickApp()); }

final ApiService api = ApiService();

class ZipRickApp extends StatelessWidget {
  const ZipRickApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: "Zip-Rick", debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)), scaffoldBackgroundColor: const Color(0xFFF8F9FE),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
    initialRoute: "/",
    onGenerateRoute: (s) {
      switch (s.name) {
        case "/": return MaterialPageRoute(builder: (_) => const SplashScreen());
        case "/welcome": return MaterialPageRoute(builder: (_) => const WelcomeScreen());
        case "/login": return MaterialPageRoute(builder: (_) => const LoginScreen());
        case "/home": return MaterialPageRoute(builder: (_) => const MainScreen());
        case "/refer": return MaterialPageRoute(builder: (_) => const ReferralPage());
        default: return MaterialPageRoute(builder: (_) => const SplashScreen());
      }
    },
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF6C63FF),
    body: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Spacer(flex: 2), const Icon(Icons.electric_rickshaw_rounded, size: 100, color: Colors.white),
      const SizedBox(height: 24), const Text("Zip-Rick", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
      const Text("Your E-Rickshaw, Instantly", style: TextStyle(color: Colors.white70, fontSize: 16)),
      const Spacer(flex: 2),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, "/login"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: SizedBox(width: double.infinity, height: 56, child: OutlinedButton(onPressed: () => Navigator.pushNamed(context, "/login"), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Register / New User", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
      const Spacer(flex: 1),
    ]))),
  );
}

class SplashScreen extends StatefulWidget { const SplashScreen({super.key}); @override State<SplashScreen> createState() => _SplashScreenState(); }
class _SplashScreenState extends State<SplashScreen> {
  @override void initState() { super.initState(); Future.delayed(const Duration(seconds: 2), () => Navigator.pushReplacementNamed(context, "/welcome")); }
  @override Widget build(BuildContext context) => const Scaffold(backgroundColor: Color(0xFF6C63FF), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.electric_rickshaw_rounded, size: 120, color: Colors.white), SizedBox(height: 24), Text("Zip-Rick", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text("Your E-Rickshaw, Instantly", style: TextStyle(color: Colors.white70, fontSize: 16)), SizedBox(height: 60), CircularProgressIndicator(color: Colors.white)])));
}

class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: "+91"); final _otpCtrl = TextEditingController(); final _nameCtrl = TextEditingController();
  bool _otpSent = false; bool _loading = false; String _error = "";
  @override void dispose() { _phoneCtrl.dispose(); _otpCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }
  Future<void> _sendOTP() async {
    setState(() { _loading = true; _error = ""; });
    try { final r = await api.sendOTP(_phoneCtrl.text); if (r["success"]) setState(() => _otpSent = true); else _error = r["error"]?["message"] ?? "Failed"; }
    catch (e) { _error = "Cannot connect"; }
    setState(() => _loading = false);
  }
  Future<void> _verifyOTP() async {
    setState(() { _loading = true; _error = ""; });
    try { final r = await api.verifyOTP(_phoneCtrl.text, _otpCtrl.text, _nameCtrl.text, "customer"); if (r["success"]) { if (!mounted) return; Navigator.pushReplacementNamed(context, "/home"); } else _error = r["error"]?["message"] ?? "Failed"; }
    catch (e) { _error = "Cannot connect"; }
    setState(() => _loading = false);
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 60), const Icon(Icons.electric_rickshaw_rounded, size: 64, color: Color(0xFF6C63FF)),
      const SizedBox(height: 24),
      Text(_otpSent ? "Verify OTP" : "Welcome", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text(_otpSent ? "Enter OTP" : "Enter your phone", style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
      const SizedBox(height: 40),
      TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone", prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
      if (_otpSent) ...[
        const SizedBox(height: 16), TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Full Name (new users only)", prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
        const SizedBox(height: 16), TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: "OTP", prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
      ],
      if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP), child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_otpSent ? "Verify & Login" : "Send OTP")),
    ]))),
  );
}

class MainScreen extends StatefulWidget { const MainScreen({super.key}); @override State<MainScreen> createState() => _MainScreenState(); }
class _MainScreenState extends State<MainScreen> {
  int _currentTab = 0;
  @override Widget build(BuildContext context) => Scaffold(
    body: [const HomePage(), const RideHistoryPage(), const ProfilePage()][_currentTab],
    bottomNavigationBar: BottomNavigationBar(currentIndex: _currentTab, onTap: (i) => setState(() => _currentTab = i),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: "Rides"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ]),
  );
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  final _pickupCtrl = TextEditingController(); final _dropCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  LatLng _currentLocation = const LatLng(26.1445, 91.7362); LatLng? _pickupLocation; LatLng? _dropLocation;
  bool _loading = true; bool _isBooking = false; Map<String, dynamic>? _fareData;
  List<Map<String, dynamic>> _searchResults = []; bool _isSearching = false;
  String? _appliedPromo;
  int _discount = 0;

  @override void initState() { super.initState(); _getCurrentLocation(); }
  @override void dispose() { _pickupCtrl.dispose(); _dropCtrl.dispose(); _promoCtrl.dispose(); super.dispose(); }

  void _sosAlert() async {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("🚨 SOS Emergency", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: const Text("This will alert our support team immediately. Do you need help?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          try {
            final r = await api.sos();
            if (r["success"]) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS sent! Help is on the way.")));
            }
          } catch (_) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send SOS. Call emergency number.")));
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Send SOS", style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  Future<void> _getCurrentLocation() async {
    try {
      final js = html.window.navigator.geolocation;
      if (js != null) {
        await js.getCurrentPosition().then((pos) {
          final lat = pos.coords?.latitude ?? 0.0; final lng = pos.coords?.longitude ?? 0.0;
          if (lat != 0 || lng != 0) { setState(() { _currentLocation = LatLng(lat.toDouble(), lng.toDouble()); _pickupLocation = _currentLocation; _pickupCtrl.text = "Current Location"; _loading = false; }); _mapController.move(_currentLocation, 15); return; }
          _nativeLoc();
        }).catchError((_) => _nativeLoc());
      } else { _nativeLoc(); }
    } catch (_) { _nativeLoc(); }
  }
  Future<void> _nativeLoc() async {
    try {
      if (await Geolocator.requestPermission() == LocationPermission.whileInUse || await Geolocator.checkPermission() == LocationPermission.always) {
        final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 10));
        setState(() { _currentLocation = LatLng(p.latitude, p.longitude); _pickupLocation = _currentLocation; _pickupCtrl.text = "Current Location"; _loading = false; });
        _mapController.move(_currentLocation, 15);
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
  }
  Future<void> _searchPlaces(String q, bool isPickup) async {
    if (q.length < 3) return;
    setState(() => _isSearching = true);
    try {
      final r = await http.get(Uri.parse("https://nominatim.openstreetmap.org/search?q=" + Uri.encodeComponent(q) + "&format=json&limit=5&countrycodes=in"), headers: {"User-Agent": "ZipRick/1.0"});
      if (r.statusCode == 200) {
        final List d = jsonDecode(r.body);
        setState(() { _searchResults = d.map((e) => {"display_name": e["display_name"] ?? "", "lat": double.parse(e["lat"] ?? "0"), "lon": double.parse(e["lon"] ?? "0"), "isPickup": isPickup}).toList(); });
      }
    } catch (_) {}
    setState(() => _isSearching = false);
  }
  void _selectPlace(Map<String, dynamic> p) {
    final ll = LatLng(p["lat"], p["lon"]);
    setState(() {
      if (p["isPickup"] == true) { _pickupLocation = ll; _pickupCtrl.text = p["display_name"].toString(); }
      else { _dropLocation = ll; _dropCtrl.text = p["display_name"].toString(); }
      _searchResults = [];
    });
    _mapController.move(ll, 15);
    if (_pickupLocation != null && _dropLocation != null) _getFare();
  }
  Future<void> _getFare() async {
    if (_pickupLocation == null || _dropLocation == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Set pickup and drop first"))); return; }
    setState(() => _loading = true);
    try {
      final r = await api.getFareEstimate(_pickupLocation!.latitude, _pickupLocation!.longitude, _dropLocation!.latitude, _dropLocation!.longitude);
      if (r["success"]) { setState(() { _fareData = r["data"]; _loading = false; }); _showRideType(); }
    } catch (_) { setState(() => _loading = false); }
  }
  void _showRideType() {
    final base = (_fareData?["total_fare"] ?? 30).toInt();
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("Select Ride Type", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _typeBtn("Premium", "Rs $base", const Color(0xFF6C63FF), () { Navigator.pop(ctx); _showShareMode(base); })),
        const SizedBox(width: 16),
        Expanded(child: _typeBtn("Standard", "Rs ${(base * 0.85).toInt()}", Colors.teal, () { Navigator.pop(ctx); _showShareMode((base * 0.85).toInt()); })),
      ]),
    ])));
  }
  void _showShareMode(int fare) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("Ride Mode", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _typeBtn("Single", "Rs $fare", const Color(0xFF6C63FF), () { Navigator.pop(ctx); _showPayment(fare); })),
        const SizedBox(width: 16),
        Expanded(child: _typeBtn("Sharing", "Rs ${(fare * 0.6).toInt()}", Colors.teal, () { Navigator.pop(ctx); _showPayment((fare * 0.6).toInt()); })),
      ]),
    ])));
  }
  void _showPayment(int amount) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("Payment", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      Text("Total: Rs ${amount - _discount}", style: const TextStyle(fontSize: 32, color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
      if (_discount > 0) Text("Discount: -Rs $_discount", style: const TextStyle(color: Colors.green)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _promoCtrl, decoration: const InputDecoration(labelText: "Promo code", border: OutlineInputBorder(), isDense: true))),
        const SizedBox(width: 8),
        TextButton(onPressed: () async {
          if (_promoCtrl.text.isEmpty) return;
          final code = _promoCtrl.text.trim().toUpperCase();
          if (code == "ZIP50") { setModalState(() { _discount = (amount * 0.5).toInt(); _appliedPromo = code; }); }
          else if (code == "ZIP20") { setModalState(() { _discount = 20; _appliedPromo = code; }); }
          else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid code"))); }
        }, child: const Text("Apply")),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: SizedBox(height: 50, child: ElevatedButton(onPressed: () { Navigator.pop(ctx); _bookRide("cash"); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: const Text("Cash")))),
        const SizedBox(width: 12),
        Expanded(child: SizedBox(height: 50, child: ElevatedButton(onPressed: () { Navigator.pop(ctx); _bookRide("upi"); }, child: const Text("UPI")))),
      ]),
    ]))));
  }
  Widget _typeBtn(String t, String p, Color c, VoidCallback on) => GestureDetector(onTap: on, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: c, width: 2)), child: Column(children: [Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)), const SizedBox(height: 4), Text(p, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c))])));
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
    appBar: AppBar(title: const Text("Zip-Rick"), actions: [
      IconButton(icon: const Icon(Icons.headset_mic), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage()))),
      const SizedBox(width: 8),
      IconButton(icon: const Icon(Icons.emergency, color: Colors.red), onPressed: _sosAlert),
    ]),
    body: Stack(children: [
      _loading ? const Center(child: CircularProgressIndicator()) : FlutterMap(mapController: _mapController, options: MapOptions(center: _currentLocation, zoom: 15, onLongPress: (tapPos, latlng) { setState(() { if (_dropLocation == null) { _dropLocation = latlng; _dropCtrl.text = "Pinned"; if (_pickupLocation != null) _getFare(); } else { _pickupLocation = latlng; _pickupCtrl.text = "Pinned"; _dropLocation = null; _dropCtrl.clear(); } }); }), children: [
        TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.ziprick.customer"),
        MarkerLayer(markers: [
          if (_pickupLocation != null) Marker(point: _pickupLocation!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 35)),
          if (_dropLocation != null) Marker(point: _dropLocation!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 35)),
        ]),
      ]),
      Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: Card(margin: const EdgeInsets.all(12), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        TextField(controller: _pickupCtrl, decoration: const InputDecoration(labelText: "Pickup", prefixIcon: Icon(Icons.circle, color: Colors.green, size: 12), border: OutlineInputBorder(), isDense: true), onChanged: (v) => _searchPlaces(v, true)),
        ..._searchResults.where((p) => p["isPickup"] == true).take(2).map((p) => ListTile(dense: true, title: Text(p["display_name"].toString(), style: const TextStyle(fontSize: 12)), onTap: () => _selectPlace(p))),
        const SizedBox(height: 8),
        TextField(controller: _dropCtrl, decoration: const InputDecoration(labelText: "Drop", prefixIcon: Icon(Icons.location_on, color: Colors.red, size: 12), border: OutlineInputBorder(), isDense: true), onChanged: (v) => _searchPlaces(v, false)),
        ..._searchResults.where((p) => p["isPickup"] == false).take(2).map((p) => ListTile(dense: true, title: Text(p["display_name"].toString(), style: const TextStyle(fontSize: 12)), onTap: () => _selectPlace(p))),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: _getFare, child: _isBooking ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Proceed to Book")),
      ]))))),
      Positioned(right: 16, bottom: 16, child: FloatingActionButton(mini: true, onPressed: _getCurrentLocation, backgroundColor: Colors.white, child: const Icon(Icons.my_location, color: Color(0xFF6C63FF)))),
    ]),
  );
}

class RideTrackingPage extends StatefulWidget { final Map<String, dynamic> rideData; const RideTrackingPage({super.key, required this.rideData}); @override State<RideTrackingPage> createState() => _RideTrackingPageState(); }
class _RideTrackingPageState extends State<RideTrackingPage> {
  bool _rideCompleted = false; int _rating = 0; bool _driverFound = false;
  Map<String, dynamic>? _driverInfo;
  bool _ratingSubmitted = false;

  @override void initState() { super.initState(); _checkDriver(); }
  void _checkDriver() {
    Future.delayed(const Duration(seconds: 5), () async { if (!mounted) return; try { final r = await api.getActiveRide(); if (r["success"] && r["data"] != null && r["data"]["ride"] != null && r["data"]["ride"]["status"] == "driver_assigned") {
      setState(() { _driverFound = true; _driverInfo = r["data"]["ride"]["driver"]; });
      return;
    } if (mounted) _checkDriver(); } catch (_) { if (mounted) _checkDriver(); } });
  }

  void _submitRating() async {
    if (_ratingSubmitted) return;
    try {
      await api.rateRide(widget.rideData["id"], _rating);
      setState(() => _ratingSubmitted = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rating submitted!")));
    } catch (_) {}
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainScreen()), (route) => false);
  }

  void _shareRide() {
    final text = "🚀 I'm riding with Zip-Rick!\n📍 Pickup: ${widget.rideData["pickup_address"] ?? "N/A"}\n🏁 Drop: ${widget.rideData["drop_address"] ?? "N/A"}\n💰 Fare: Rs ${widget.rideData["total_fare"] ?? 0}\nTrack me live on Zip-Rick!";
    html.window.navigator.clipboard?.writeText(text);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride details copied! Share via WhatsApp.")));
  }

  @override Widget build(BuildContext context) {
    if (_rideCompleted) {
      return Scaffold(appBar: AppBar(title: const Text("Rate Your Ride")), body: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.celebration, color: Colors.green, size: 80), const SizedBox(height: 16),
        const Text("Ride Completed!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24), const Text("How was your ride?"), const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(icon: Icon(i < _rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 40), onPressed: () => setState(() => _rating = i + 1)))),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _rating == 0 ? null : _submitRating, child: _ratingSubmitted ? const Text("Submitted") : const Text("Submit Rating")),
      ])));
    }
    return Scaffold(appBar: AppBar(title: const Text("Ride Status"), actions: [
      IconButton(icon: const Icon(Icons.share), onPressed: _shareRide, tooltip: "Share ride"),
    ]), body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      Icon(_driverFound ? Icons.check_circle : Icons.hourglass_top, color: _driverFound ? Colors.green : Colors.orange, size: 80),
      const SizedBox(height: 16),
      Text(_driverFound ? "Driver Found!" : "Booking your ride...", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _driverFound ? Colors.green : Colors.orange)),
      const SizedBox(height: 8),
      Text("Ride #${widget.rideData["ride_number"] ?? "N/A"}", style: TextStyle(color: Colors.grey[600])),
      const SizedBox(height: 24),
      if (_driverFound) const LinearProgressIndicator() else const CircularProgressIndicator(),
      const SizedBox(height: 24),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Row(children: [const Icon(Icons.location_on, color: Colors.green), const SizedBox(width: 12), Expanded(child: Text("${widget.rideData["pickup_address"] ?? "N/A"}"))]),
        const Divider(),
        Row(children: [const Icon(Icons.location_on, color: Colors.red), const SizedBox(width: 12), Expanded(child: Text("${widget.rideData["drop_address"] ?? "N/A"}"))]),
        const Divider(),
        Row(children: [const Icon(Icons.currency_rupee), const SizedBox(width: 12), Text("Rs ${widget.rideData["total_fare"] ?? 0}")]),
        if (_driverFound && _driverInfo != null) ...[
          const Divider(),
          Row(children: [
            const Icon(Icons.person, color: Color(0xFF6C63FF)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_driverInfo!["user"]?["full_name"] ?? "Driver", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_driverInfo!["vehicle"]?["registration_number"] ?? "Vehicle: N/A", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
          ]),
          const Divider(),
          Row(children: [
            const Icon(Icons.phone, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(child: Text(_driverInfo!["user"]?["phone"] ?? "+91XXXXXXXXXX")),
            IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () {
              final phone = _driverInfo!["user"]?["phone"] ?? "";
              if (phone.isNotEmpty) html.window.open("tel:$phone", "_self");
            }),
          ]),
        ],
      ]))),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: () { setState(() => _rideCompleted = true); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Complete Ride")),
    ])));
  }
}

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});
  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}
class _RideHistoryPageState extends State<RideHistoryPage> {
  List _rides = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await api.getRideHistory();
      if (r["success"]) setState(() { _rides = r["data"] ?? []; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Rides")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rides.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No rides yet"),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rides.length,
                  itemBuilder: (ctx, i) {
                    final r = _rides[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          r["status"] == "completed" ? Icons.check_circle : Icons.pending,
                          color: r["status"] == "completed" ? Colors.green : Colors.orange,
                        ),
                        title: Text("Ride #"),
                        subtitle: Text(" -> "),
                        trailing: Text("Rs ", style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => html.window.navigator.clipboard?.writeText("Ride with Zip-Rick! Details: ${r["ride_number"] ?? ""}"),
                      ),
                    );
                  },
                ),
    );
  }
}

class ProfilePage extends StatefulWidget { const ProfilePage({super.key}); @override State<ProfilePage> createState() => _ProfilePageState(); }
class _ProfilePageState extends State<ProfilePage> { Map? _profile; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await api.getProfile(); if (r["success"]) setState(() { _profile = r["data"]; _loading = false; }); } catch (_) { setState(() => _loading = false); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Profile")), body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(24), children: [
    const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)), const SizedBox(height: 16),
    Center(child: Text(_profile?["user"]?["full_name"] ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
    Center(child: Text(_profile?["user"]?["phone"] ?? "", style: TextStyle(color: Colors.grey[600]))),
    const SizedBox(height: 32),
    Card(child: Column(children: [ListTile(leading: const Icon(Icons.star, color: Colors.amber), title: const Text("Rating"), trailing: Text("${_profile?["customer"]?["rating"] ?? "0.0"}")), const Divider(height: 1), ListTile(leading: const Icon(Icons.directions_car, color: Color(0xFF6C63FF)), title: const Text("Total Rides"), trailing: Text("${_profile?["customer"]?["total_rides"] ?? 0}"))])),
    const SizedBox(height: 8),
    Card(child: ListTile(
      leading: const Icon(Icons.card_giftcard, color: Color(0xFF6C63FF)),
      title: const Text("Refer & Earn"),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralPage())),
    )),
  ]));
}

class ReferralPage extends StatefulWidget { const ReferralPage({super.key}); @override State<ReferralPage> createState() => _ReferralPageState(); }
class _ReferralPageState extends State<ReferralPage> {
  String? _code;
  int _points = 0;
  int _totalReferrals = 0;
  bool _loading = true;
  final _referCtrl = TextEditingController();
  bool _applying = false;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await api.getReferralStats();
      if (r["success"]) {
        setState(() { _code = r["data"]["referral_code"]; _points = r["data"]["loyalty_points"] ?? 0; _totalReferrals = r["data"]["total_referrals"] ?? 0; _loading = false; });
      }
    } catch (_) { setState(() => _loading = false); }
  }
  void _invite() async {
    if (_code == null) return;
    final text = "🚀 Join Zip-Rick! Use my referral code: $_code and get ₹50 bonus! Download at https://zip-rick-4.onrender.com";
    await html.window.navigator.clipboard?.writeText(text);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral code copied! Share it with friends.")));
  }
  Future<void> _applyCode() async {
    if (_referCtrl.text.isEmpty) return;
    setState(() => _applying = true);
    try {
      final r = await api.applyReferral(_referCtrl.text.trim());
      if (r["success"]) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral applied! You earned 50 points!")));
        _referCtrl.clear();
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r["error"]?["message"] ?? "Failed")));
      }
    } catch (_) {}
    setState(() => _applying = false);
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Refer & Earn")),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(24), children: [
      Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        const Icon(Icons.card_giftcard, size: 60, color: Color(0xFF6C63FF)),
        const SizedBox(height: 12),
        Text("Your Referral Code", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text(_code ?? "", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFF6C63FF))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Column(children: [Text("$_points", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const Text("Points", style: TextStyle(color: Colors.grey))]),
          Column(children: [Text("$_totalReferrals", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const Text("Referred", style: TextStyle(color: Colors.grey))]),
        ]),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: _invite, icon: const Icon(Icons.share), label: const Text("Invite Friends")),
      ]))),
      const Divider(height: 40),
      const Text("Have a referral code?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _referCtrl, decoration: const InputDecoration(labelText: "Enter code", border: OutlineInputBorder()))),
        const SizedBox(width: 12),
        ElevatedButton(onPressed: _applying ? null : _applyCode, child: _applying ? const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text("Apply")),
      ]),
    ]),
  );
}

class SupportPage extends StatefulWidget { const SupportPage({super.key}); @override State<SupportPage> createState() => _SupportPageState(); }
class _SupportPageState extends State<SupportPage> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;
  List _tickets = [];
  bool _loadTickets = true;

  @override void initState() { super.initState(); _fetchTickets(); }
  Future<void> _fetchTickets() async {
    try {
      final r = await api.getSupportTickets();
      if (r["success"]) setState(() { _tickets = r["data"] ?? []; _loadTickets = false; });
    } catch (_) { setState(() => _loadTickets = false); }
  }
  Future<void> _createTicket() async {
    if (_subjectCtrl.text.isEmpty || _descCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final r = await api.createSupportTicket(_subjectCtrl.text, _descCtrl.text);
      if (r["success"]) {
        _subjectCtrl.clear(); _descCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket created!")));
        _fetchTickets();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Support")),
    body: _loadTickets ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      const Text("Create Ticket", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      TextField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: "Subject", border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: "Describe your issue", border: OutlineInputBorder()), maxLines: 3),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _loading ? null : _createTicket, child: _loading ? const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text("Submit")),
      const Divider(height: 32),
      Text("My Tickets (${_tickets.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ..._tickets.isEmpty ? [const Padding(padding: EdgeInsets.all(24), child: Text("No tickets yet"))] : _tickets.map((t) => Card(
        child: ListTile(
          leading: Icon(t["priority"] == "urgent" ? Icons.warning : Icons.support_agent, color: t["priority"] == "urgent" ? Colors.red : Colors.blue),
          title: Text(t["subject"] ?? "Support"),
          subtitle: Text(t["status"] ?? "open"),
          trailing: Text(t["priority"] ?? "medium", style: const TextStyle(fontSize: 12)),
        ),
      )),
    ]),
  );
}