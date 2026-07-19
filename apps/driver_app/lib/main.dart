import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:geolocator/geolocator.dart";
import "package:http/http.dart" as http;
import "dart:convert";

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const ZipRickDriverApp()); }

final String baseUrl = "https://zip-rick-4.onrender.com/api/v1";
String? _authToken;

class ZipRickDriverApp extends StatelessWidget { const ZipRickDriverApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(title: "Zip-Rick Driver", debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF))),
    initialRoute: "/",
    onGenerateRoute: (s) { switch (s.name) {
      case "/": return MaterialPageRoute(builder: (_) => const SplashScreen());
      case "/welcome": return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case "/login": return MaterialPageRoute(builder: (_) => const LoginScreen());
      case "/register": return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case "/home": return MaterialPageRoute(builder: (_) => const DriverHomeScreen());
      case "/support": return MaterialPageRoute(builder: (_) => const SupportPage());
      default: return MaterialPageRoute(builder: (_) => const SplashScreen());
    }},
  );
}

class WelcomeScreen extends StatelessWidget { const WelcomeScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF6C63FF),
    body: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Spacer(flex: 2), const Icon(Icons.electric_rickshaw_rounded, size: 100, color: Colors.white),
      const SizedBox(height: 24), const Text("Zip-Rick Driver", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 8), const Text("Earn driving E-Rickshaw", style: TextStyle(color: Colors.white70, fontSize: 16)),
      const Spacer(flex: 2),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, "/login"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: SizedBox(width: double.infinity, height: 56, child: OutlinedButton(onPressed: () => Navigator.pushNamed(context, "/register"), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("New Driver? Register", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
      const Spacer(flex: 1),
    ]))),
  );
}

class SplashScreen extends StatefulWidget { const SplashScreen({super.key}); @override State<SplashScreen> createState() => _SplashScreenState(); }
class _SplashScreenState extends State<SplashScreen> {
  @override void initState() { super.initState(); Future.delayed(const Duration(seconds: 2), () => Navigator.pushReplacementNamed(context, "/welcome")); }
  @override Widget build(BuildContext context) => const Scaffold(backgroundColor: Color(0xFF6C63FF), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.electric_rickshaw_rounded, size: 120, color: Colors.white), SizedBox(height: 24), Text("Zip-Rick Driver", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text("Earn driving E-Rickshaw", style: TextStyle(color: Colors.white70, fontSize: 16)), SizedBox(height: 60), CircularProgressIndicator(color: Colors.white)])));
}

// LOGIN SCREEN - Phone + OTP only, no name
class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: "+91"); final _otpCtrl = TextEditingController();
  bool _otpSent = false; bool _loading = false; String _error = "";
  @override void dispose() { _phoneCtrl.dispose(); _otpCtrl.dispose(); super.dispose(); }
  Future<void> _sendOTP() async { setState(() { _loading = true; _error = ""; }); try { final r = await http.post(Uri.parse(baseUrl + "/auth/send-otp"), headers: {"Content-Type": "application/json"}, body: jsonEncode({"phone": _phoneCtrl.text})); final d = jsonDecode(r.body); if (d["success"]) setState(() => _otpSent = true); else _error = d["error"]?["message"] ?? "Failed"; } catch (e) { _error = "Cannot connect"; } setState(() => _loading = false); }
  Future<void> _verifyOTP() async {
    setState(() { _loading = true; _error = ""; });
    try {
      final r = await http.post(Uri.parse(baseUrl + "/auth/verify-otp"), headers: {"Content-Type": "application/json"}, body: jsonEncode({"phone": _phoneCtrl.text, "otp": _otpCtrl.text, "full_name": "", "role": "driver"}));
      final d = jsonDecode(r.body);
      if (d["success"]) { _authToken = d["data"]["tokens"]["accessToken"]; if (!mounted) return; Navigator.pushReplacementNamed(context, "/home"); }
      else {
        _error = d["error"]?["message"] ?? "Failed";
        if (_error.contains("Name is required") || _error.contains("not found")) {
          _error = "Account not found. Please go back and register.";
        }
      }
    } catch (e) { _error = "Cannot connect"; }
    setState(() => _loading = false);
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 60), const Icon(Icons.electric_rickshaw_rounded, size: 64, color: Color(0xFF6C63FF)),
      const SizedBox(height: 24),
      Text("Driver Login", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text("Sign in to your account", style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
      const SizedBox(height: 40),
      TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone", prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
      if (_otpSent) ...[
        const SizedBox(height: 16), TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: "OTP", prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
      ],
      if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP), child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_otpSent ? "Verify OTP" : "Send OTP")),
    ]))),
  );
}

// REGISTER SCREEN - Phone + Name + OTP
class RegisterScreen extends StatefulWidget { const RegisterScreen({super.key}); @override State<RegisterScreen> createState() => _RegisterScreenState(); }
class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneCtrl = TextEditingController(text: "+91"); final _otpCtrl = TextEditingController(); final _nameCtrl = TextEditingController();
  bool _otpSent = false; bool _loading = false; String _error = "";
  @override void dispose() { _phoneCtrl.dispose(); _otpCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }
  Future<void> _sendOTP() async { setState(() { _loading = true; _error = ""; }); try { final r = await http.post(Uri.parse(baseUrl + "/auth/send-otp"), headers: {"Content-Type": "application/json"}, body: jsonEncode({"phone": _phoneCtrl.text})); final d = jsonDecode(r.body); if (d["success"]) setState(() => _otpSent = true); else _error = d["error"]?["message"] ?? "Failed"; } catch (e) { _error = "Cannot connect"; } setState(() => _loading = false); }
  Future<void> _verifyOTP() async {
    if (_nameCtrl.text.trim().isEmpty) { _error = "Full Name is required"; return; }
    setState(() { _loading = true; _error = ""; });
    try {
      final r = await http.post(Uri.parse(baseUrl + "/auth/verify-otp"), headers: {"Content-Type": "application/json"}, body: jsonEncode({"phone": _phoneCtrl.text, "otp": _otpCtrl.text, "full_name": _nameCtrl.text, "role": "driver"}));
      final d = jsonDecode(r.body);
      if (d["success"]) { _authToken = d["data"]["tokens"]["accessToken"]; if (!mounted) return; Navigator.pushReplacementNamed(context, "/register"); }
      else { _error = d["error"]?["message"] ?? "Failed"; }
    } catch (e) { _error = "Cannot connect"; }
    setState(() => _loading = false);
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 60), const Icon(Icons.electric_rickshaw_rounded, size: 64, color: Color(0xFF6C63FF)),
      const SizedBox(height: 24),
      Text("Register as Driver", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text("Create your driver account", style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
      const SizedBox(height: 40),
      TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone", prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
      if (_otpSent) ...[
        const SizedBox(height: 16), TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
        const SizedBox(height: 16), TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: "OTP", prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
      ],
      if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP), child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_otpSent ? "Create Account" : "Send OTP")),
    ]))),
  );
}

// Keep all the rest exactly as before - DriverHomeScreen, SupportPage, etc.
class DriverHomeScreen extends StatefulWidget { const DriverHomeScreen({super.key}); @override State<DriverHomeScreen> createState() => _DriverHomeScreenState(); }
class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final MapController _mapController = MapController(); LatLng _driverLocation = const LatLng(26.1445, 91.7362);
  bool _isOnline = false; bool _isLoading = true; int _currentTab = 0; double _commissionDue = 0; double _totalEarnings = 0; bool _commissionLoading = false;
  List<Map<String, dynamic>> _rideRequests = []; Map<String, dynamic>? _activeRide; int _pollCount = 0;

  void _sosAlert() async {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("🚨 SOS Emergency", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: const Text("This will alert our support team immediately. Do you need help?"),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () async { Navigator.pop(ctx); try { final res = await http.post(Uri.parse(baseUrl + "/sos"), headers: {"Authorization": "Bearer " + (_authToken ?? "")}); final data = jsonDecode(res.body); if (data["success"]) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS sent!"))); } } catch (_) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed"))); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Send SOS", style: TextStyle(color: Colors.white)))],
    ));
  }

  @override void initState() { super.initState(); _getLocation(); _startPolling(); }
  Future<void> _getLocation() async {
    try { if (await Geolocator.requestPermission() == LocationPermission.whileInUse || await Geolocator.checkPermission() == LocationPermission.always) { final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 10)); setState(() { _driverLocation = LatLng(p.latitude, p.longitude); _isLoading = false; }); _mapController.move(_driverLocation, 14); } else { setState(() => _isLoading = false); } } catch (_) { setState(() => _isLoading = false); }
  }
  void _startPolling() { Future.delayed(const Duration(seconds: 5), () { if (!mounted) return; if (_isOnline) { _checkForRideRequests(); } if (mounted) _startPolling(); }); }
  void _checkForRideRequests() async {
    try { final res = await http.get(Uri.parse(baseUrl + "/rides/searching/available"), headers: {"Authorization": "Bearer " + (_authToken ?? "")}); final data = jsonDecode(res.body); if (data["success"] && data["data"] is List && data["data"].length > 0) { for (var ride in data["data"]) { bool exists = _rideRequests.any((r) => r["id"] == ride["id"]); if (!exists) { setState(() { _rideRequests.add({"id": ride["id"], "pickup_address": ride["pickup_address"] ?? "Unknown", "drop_address": ride["drop_address"] ?? "Unknown", "ride_number": ride["ride_number"] ?? "N/A", "total_fare": ride["total_fare"]?.toString() ?? "0"}); }); } } } } catch (_) {}
  }
  void _acceptRide(Map<String, dynamic> ride) async {
    try { final res = await http.post(Uri.parse(baseUrl + "/rides/" + ride["id"] + "/accept"), headers: {"Authorization": "Bearer " + (_authToken ?? ""), "Content-Type": "application/json"}); final data = jsonDecode(res.body); if (data["success"]) { setState(() { _rideRequests.removeWhere((r) => r["id"] == ride["id"]); _activeRide = ride; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride accepted!"))); } } catch (_) {}
  }
  void _rejectRide(Map<String, dynamic> ride) { setState(() => _rideRequests.removeWhere((r) => r["id"] == ride["id"])); }
  void _completeRide() { setState(() { _activeRide = null; _commissionDue += (_commissionDue + 10); }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride completed!"))); }
  void _checkCommissionBeforeOnline() async {
    try { setState(() => _commissionLoading = true); final res = await http.get(Uri.parse(baseUrl + "/drivers/commission/due"), headers: {"Authorization": "Bearer " + (_authToken ?? "")}); final data = jsonDecode(res.body); setState(() => _commissionLoading = false);
      if (data["success"] && data["data"] != null) { final due = (data["data"]["commission_due"] ?? 0).toDouble(); final earnings = (data["data"]["total_earnings"] ?? 0).toDouble(); setState(() { _commissionDue = due; _totalEarnings = earnings; });
        if (due > 0) { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Commission Due", style: TextStyle(color: Colors.red)), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text("Pay commission to go online."), Text("Due: Rs " + due.toStringAsFixed(0), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () { Navigator.pop(ctx); _showCommissionPayment(); }, child: const Text("Pay Now"))])); return; } }
      setState(() => _isOnline = true);
    } catch (_) { setState(() { _commissionLoading = false; _isOnline = true; }); }
  }
  void _showCommissionPayment() { showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text("Pay Commission", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 20), const Text("Pending Commission", style: TextStyle(color: Colors.grey)), const SizedBox(height: 8), Text("Rs " + _commissionDue.toStringAsFixed(0), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))), const SizedBox(height: 24), SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _commissionLoading ? null : () async { try { setState(() => _commissionLoading = true); final res = await http.post(Uri.parse(baseUrl + "/drivers/commission/pay"), headers: {"Authorization": "Bearer " + (_authToken ?? ""), "Content-Type": "application/json"}, body: jsonEncode({"amount": _commissionDue})); final data = jsonDecode(res.body); setState(() => _commissionLoading = false); if (data["success"]) { setState(() => _commissionDue = 0); Navigator.pop(ctx); setState(() => _isOnline = true); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Paid!"))); } } catch (_) { setState(() => _commissionLoading = false); } }, child: _commissionLoading ? const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text("Pay Now")))]))); }
  @override Widget build(BuildContext context) { final pages = [_home(), _earnings(), _profile()]; return Scaffold(body: pages[_currentTab], bottomNavigationBar: BottomNavigationBar(currentIndex: _currentTab, onTap: (i) => setState(() => _currentTab = i), items: const [BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"), BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: "Earnings"), BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile")])); }
  Widget _home() => Scaffold(appBar: AppBar(title: const Text("Zip-Rick Driver"), actions: [IconButton(icon: const Icon(Icons.headset_mic), onPressed: () => Navigator.pushNamed(context, "/support")), const SizedBox(width: 8), IconButton(icon: const Icon(Icons.emergency, color: Colors.red), onPressed: _sosAlert)]),
    body: _isLoading ? const Center(child: CircularProgressIndicator()) : Stack(children: [
      FlutterMap(mapController: _mapController, options: MapOptions(center: _driverLocation, zoom: 14), children: [TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.ziprick.driver"), MarkerLayer(markers: [Marker(point: _driverLocation, width: 40, height: 40, child: const Icon(Icons.electric_rickshaw_rounded, color: Color(0xFF6C63FF), size: 35))])]),
      Positioned(bottom: 140, left: 0, right: 0, child: Center(child: GestureDetector(onTap: _showCommissionPayment, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(20)), child: Text("Commission Due: Rs " + _commissionDue.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))))),
      Positioned(top: 16, left: 0, right: 0, child: Center(child: GestureDetector(onTap: () { if (!_isOnline) { _checkCommissionBeforeOnline(); } else { setState(() => _isOnline = false); } }, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: _isOnline ? const Color(0xFF00D9A6) : Colors.white.withOpacity(0.9), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_isOnline ? Icons.power_settings_new : Icons.power_off, color: _isOnline ? Colors.white : const Color(0xFF6C63FF), size: 28), Text(_isOnline ? "ONLINE" : "OFFLINE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isOnline ? Colors.white : const Color(0xFF6C63FF)))])))))),
      Positioned(bottom: 80, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)), child: Text(_isOnline ? "Waiting for rides..." : "Tap to go online", style: TextStyle(color: _isOnline ? Colors.green : Colors.grey, fontSize: 14))))),
      Positioned(right: 16, bottom: 16, child: FloatingActionButton(mini: true, onPressed: _getLocation, backgroundColor: Colors.white, child: const Icon(Icons.my_location, color: Color(0xFF6C63FF)))),
    ]));
  Widget _earnings() => Scaffold(appBar: AppBar(title: const Text("Earnings")), body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [const Text("Total Earnings", style: TextStyle(color: Colors.grey)), const Text("Rs 0", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))), const Divider(), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Today"), const Text("Rs 0")]), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("This Week"), const Text("Rs 0")]), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Rides"), const Text("0")])]))), const SizedBox(height: 16), Card(child: ListTile(leading: const Icon(Icons.history), title: const Text("Ride History"), trailing: const Icon(Icons.chevron_right))), const SizedBox(height: 8), Card(child: ListTile(leading: Icon(_commissionDue > 0 ? Icons.payment : Icons.check_circle, color: _commissionDue > 0 ? Colors.red : Colors.green), title: const Text("Pay Commission"), subtitle: Text("Due: Rs " + _commissionDue.toStringAsFixed(0)), trailing: TextButton(onPressed: _commissionDue > 0 ? () { _showCommissionPayment(); } : null, child: Text(_commissionDue > 0 ? "Pay Now" : "Cleared"))))])));
  Widget _profile() => FutureBuilder(future: http.get(Uri.parse(baseUrl + "/drivers/profile"), headers: {"Authorization": "Bearer " + (_authToken ?? "")}), builder: (ctx, snap) { String name = "Driver"; String phone = ""; if (snap.hasData) { try { final d = jsonDecode(snap.data!.body); if (d["success"] && d["data"] != null && d["data"]["driver"] != null) { name = d["data"]["driver"]["user"]?["full_name"] ?? "Driver"; phone = d["data"]["driver"]["user"]?["phone"] ?? ""; } } catch (_) {} } return Scaffold(appBar: AppBar(title: const Text("Profile")), body: ListView(padding: const EdgeInsets.all(24), children: [const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)), const SizedBox(height: 16), Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center), Text(phone, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center), const SizedBox(height: 32), Card(child: ListTile(leading: const Icon(Icons.star, color: Colors.amber), title: const Text("Rating"), trailing: const Text("0.0"))), Card(child: ListTile(leading: const Icon(Icons.document_scanner), title: const Text("My Documents"), trailing: const Icon(Icons.chevron_right)))])); });
}

class SupportPage extends StatefulWidget { const SupportPage({super.key}); @override State<SupportPage> createState() => _SupportPageState(); }
class _SupportPageState extends State<SupportPage> {
  final _subjectCtrl = TextEditingController(); final _descCtrl = TextEditingController(); bool _loading = false; List _tickets = []; bool _loadTickets = true;
  @override void initState() { super.initState(); _fetchTickets(); }
  Future<void> _fetchTickets() async { try { final res = await http.get(Uri.parse(baseUrl + "/support/tickets"), headers: {"Authorization": "Bearer " + (_authToken ?? "")}); final data = jsonDecode(res.body); if (data["success"]) setState(() { _tickets = data["data"] ?? []; _loadTickets = false; }); } catch (_) { setState(() => _loadTickets = false); } }
  Future<void> _createTicket() async { if (_subjectCtrl.text.isEmpty || _descCtrl.text.isEmpty) return; setState(() => _loading = true); try { final res = await http.post(Uri.parse(baseUrl + "/support/tickets"), headers: {"Authorization": "Bearer " + (_authToken ?? ""), "Content-Type": "application/json"}, body: jsonEncode({"subject": _subjectCtrl.text, "description": _descCtrl.text})); final data = jsonDecode(res.body); if (data["success"]) { _subjectCtrl.clear(); _descCtrl.clear(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Created!"))); _fetchTickets(); } } catch (_) {} setState(() => _loading = false); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Support")), body: _loadTickets ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
    const Text("Create Ticket", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 12), TextField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: "Subject", border: OutlineInputBorder())), const SizedBox(height: 8),
    TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: "Issue", border: OutlineInputBorder()), maxLines: 3), const SizedBox(height: 12),
    ElevatedButton(onPressed: _loading ? null : _createTicket, child: _loading ? const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text("Submit")),
    const Divider(height: 32), Text("My Tickets (${_tickets.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ..._tickets.isEmpty ? [const Padding(padding: EdgeInsets.all(24), child: Text("No tickets"))] : _tickets.map((t) => Card(child: ListTile(leading: Icon(t["priority"] == "urgent" ? Icons.warning : Icons.support_agent, color: t["priority"] == "urgent" ? Colors.red : Colors.blue), title: Text(t["subject"] ?? "Support"), subtitle: Text(t["status"] ?? "open"), trailing: Text(t["priority"] ?? "medium", style: const TextStyle(fontSize: 12))))),
  ]));
}