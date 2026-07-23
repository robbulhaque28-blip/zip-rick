import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../widgets/chat_bottom_sheet.dart';

final ApiService _api = ApiService();

class RideTrackingPage extends StatefulWidget {
  final Map<String, dynamic> rideData;
  const RideTrackingPage({super.key, required this.rideData});
  @override State<RideTrackingPage> createState() => _RideTrackingPageState();
}
class _RideTrackingPageState extends State<RideTrackingPage> with TickerProviderStateMixin {
  bool _rideCompleted = false;
  int _rating = 0;
  bool _driverFound = false;
  Map<String, dynamic>? _driverInfo;
  bool _ratingSubmitted = false;
  String _status = 'searching';
  LatLng? _driverLatLng;
  final MapController _mapCtrl = MapController();
  Timer? _statusTimer;
  SocketService? _socketService;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  
  // Smooth driver animation


  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _connectSocket();
    _startPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pulseCtrl.dispose();
    _socketService?.dispose();
    super.dispose();
  }

  Future<void> _connectSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    if (token == null) return;
    _socketService = SocketService();
    await _socketService!.init(token);
    _socketService!.addListener(_onSocketUpdate);
  }

Timer? _animTimer;
  int _animStep = 0;
  LatLng? _animFrom;
  LatLng? _animTo;
  static const int _totalSteps = 20;

  void _onSocketUpdate() {
    if (!mounted) return;
    if (_socketService?.rideStatus != null) setState(() => _status = _socketService!.rideStatus!);
    final newLoc = _socketService?.driverLatLng;
    if (newLoc != null) {
      if (_driverLatLng != null) {
        final diff = (_driverLatLng!.latitude - newLoc.latitude).abs() + (_driverLatLng!.longitude - newLoc.longitude).abs();
        if (diff > 0.0001) {
          // Start smooth interpolation
          _animTimer?.cancel();
          _animFrom = _driverLatLng;
          _animTo = newLoc;
          _animStep = 0;
          _runAnimStep();
        } else {
          setState(() {
            _driverLatLng = newLoc;
            _driverFound = true;
          });
        }
      } else {
        setState(() {
          _driverLatLng = newLoc;
          _driverFound = true;
        });
      }
      _driverFound = true;
      _mapCtrl.move(newLoc, 15);
    }
  }

  void _runAnimStep() {
    _animTimer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted || _animFrom == null || _animTo == null) return;
      _animStep++;
      final t = _animStep / _totalSteps;
      setState(() {
        _driverLatLng = LatLng(
          _animFrom!.latitude + (_animTo!.latitude - _animFrom!.latitude) * t,
          _animFrom!.longitude + (_animTo!.longitude - _animFrom!.longitude) * t,
        );
      });
      if (_animStep < _totalSteps) {
        _runAnimStep();
      }
    });
  }

  void _startPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    try {
      final r = await _api.getActiveRide();
      if (r["success"] && r["data"]?["ride"] != null) {
        final ride = r["data"]["ride"];
        setState(() {
          _status = ride["status"] ?? "searching";
          _driverFound = _status == 'driver_assigned' || _status == 'driver_arrived' || _status == 'started';
          if (ride["driver"] != null) _driverInfo = ride["driver"];
        });
        if (_status == 'completed') _statusTimer?.cancel();
      }
    } catch (_) {}
  }

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ChatBottomSheet(
        socketService: _socketService!,
        rideId: widget.rideData['id']?.toString() ?? '',
        userRole: 'customer',
      ),
    );
  }

  void _shareRide() {
    Clipboard.setData(ClipboardData(text: "I'm riding with Vybe!\n📍 ${widget.rideData["pickup_address"] ?? "N/A"}\n🏁 ${widget.rideData["drop_address"] ?? "N/A"}\n💰 ₹${widget.rideData["total_fare"] ?? 0}"));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trip details copied!")));
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override Widget build(BuildContext context) {
    if (_rideCompleted) return _buildRatingPage();
    return Scaffold(
      appBar: AppBar(title: Text(_statusText()), actions: [
        if (_driverFound) IconButton(icon: const Icon(Icons.chat_rounded), onPressed: _openChat),
        IconButton(icon: const Icon(Icons.share_rounded), onPressed: _shareRide),
      ]),
      body: Column(children: [
        Expanded(
          child: FlutterMap(mapController: _mapCtrl, options: MapOptions(center: _driverLatLng ?? _pickupLatLng, zoom: 15),
            children: [
              TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.vybe.customer"),
              MarkerLayer(markers: [
                Marker(point: _pickupLatLng, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 35)),
if (_driverLatLng != null) Marker(point: _driverLatLng!, width: 60, height: 60,
                  child: AnimatedBuilder(animation: _pulseAnim, builder: (ctx, child) => Transform.scale(scale: _pulseAnim.value,
                    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.electric_rickshaw_rounded, size: 28, color: Color(0xFF6C63FF)))))),
                if (_dropLatLng != null) Marker(point: _dropLatLng!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 35)),
              ]),
            ]),
        ),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
          child: Column(children: [
            Row(children: [
              AnimatedContainer(duration: const Duration(milliseconds: 500),
                width: 50, height: 50, decoration: BoxDecoration(color: _statusColor().withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(_statusIcon(), color: _statusColor(), size: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_statusText(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _statusColor())),
                Text(_statusSubtitle(), style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
              ])),
              if (_driverFound && _driverInfo != null)
                IconButton(icon: const Icon(Icons.phone, color: Colors.green), onPressed: () async {
                  final phone = _driverInfo!["user"]?["phone"] ?? "";
                  if (phone.isNotEmpty) await launchUrl(Uri.parse("tel:$phone"));
                }),
            ]),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(children: [const Icon(Icons.circle, color: Colors.green, size: 10), const SizedBox(width: 8), Expanded(child: Text(widget.rideData["pickup_address"] ?? "", style: const TextStyle(fontSize: 13)))]),
                const SizedBox(height: 2), Row(children: [const SizedBox(width: 5), Column(children: List.generate(2, (_) => Container(width: 2, height: 3, margin: const EdgeInsets.symmetric(vertical: 1), color: Colors.grey.shade400)))]),
                const SizedBox(height: 2), Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 14), const SizedBox(width: 7), Expanded(child: Text(widget.rideData["drop_address"] ?? "", style: const TextStyle(fontSize: 13)))]),
              ])),
            const SizedBox(height: 12),
            _buildActionButton(),
          ]),
        ),
      ]),
    );
  }

  Widget _buildActionButton() {
    if (_status == 'completed') {
      return SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => setState(() => _rideCompleted = true),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Rate Your Ride")));
    }
    if (_status == 'started') {
      return SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () {},
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Ride in Progress...")));
    }
    return SizedBox(width: double.infinity, height: 48, child: OutlinedButton(onPressed: () async {
        try { final r = await _api.cancelRide(widget.rideData["id"]); if (r["success"]) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cancelled"))); _goHome(); } } catch (_) {}
      }, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Cancel Ride")));
  }

  LatLng get _pickupLatLng => LatLng(
    double.tryParse('${widget.rideData["pickup_latitude"] ?? 0}') ?? 0,
    double.tryParse('${widget.rideData["pickup_longitude"] ?? 0}') ?? 0);
  LatLng? get _dropLatLng {
    final lat = double.tryParse('${widget.rideData["drop_latitude"] ?? ""}');
    final lon = double.tryParse('${widget.rideData["drop_longitude"] ?? ""}');
    if (lat == null || lon == null) return null; return LatLng(lat, lon);
  }

  Color _statusColor() {
    if (_status == 'driver_assigned') return const Color(0xFFFFA726);
    if (_status == 'driver_arrived') return const Color(0xFF4CAF50);
    if (_status == 'started') return const Color(0xFF6C63FF);
    if (_status == 'completed') return const Color(0xFF4CAF50);
    return const Color(0xFFFFA726);
  }

  IconData _statusIcon() {
    if (_status == 'driver_assigned') return Icons.person_pin;
    if (_status == 'driver_arrived') return Icons.check_circle;
    if (_status == 'started') return Icons.directions_car;
    if (_status == 'completed') return Icons.celebration;
    return Icons.hourglass_top;
  }

  String _statusText() {
    if (_status == 'driver_assigned' && _driverInfo != null) return "Driver on the way!";
    if (_status == 'driver_assigned') return "Driver assigned";
    if (_status == 'driver_arrived') return "Driver has arrived!";
    if (_status == 'started') return "Ride in progress";
    if (_status == 'completed') return "Ride completed";
    return "Finding a driver...";
  }

  String _statusSubtitle() {
    if (_driverInfo != null) return _driverInfo!["user"]?["full_name"] ?? "";
    return "Ride #${widget.rideData["ride_number"] ?? ""}";
  }

  Widget _buildRatingPage() {
    return Scaffold(
      appBar: AppBar(title: const Text("Rate Your Ride")),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.celebration, color: Color(0xFF4CAF50), size: 80),
        const SizedBox(height: 16), const Text("Ride Completed!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), const Text("How was your ride?", style: TextStyle(color: Color(0xFF9CA3AF))),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
          icon: Icon(i < _rating ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 44),
          onPressed: () => setState(() => _rating = i + 1)))),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
          onPressed: _rating == 0 || _ratingSubmitted ? null : () async {
            if (_ratingSubmitted) return;
            try { await _api.rateRide(widget.rideData["id"], _rating); setState(() => _ratingSubmitted = true); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks for rating!"))); } catch (_) {}
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) _goHome();
          }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: _ratingSubmitted ? const Text("Thanks!") : const Text("Submit Rating"))),
      ]))),
    );
  }
}
