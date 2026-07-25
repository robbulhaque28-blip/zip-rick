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
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

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

  Timer? _animTimer;
  int _animStep = 0;
  LatLng? _animFrom;
  LatLng? _animTo;
  static const int _totalSteps = 20;

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
    _animTimer?.cancel();
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

  void _onSocketUpdate() {
    if (!mounted) return;
    if (_socketService?.rideStatus != null) setState(() => _status = _socketService!.rideStatus!);
    final newLoc = _socketService?.driverLatLng;
    if (newLoc != null) {
      if (_driverLatLng != null) {
        final diff = (_driverLatLng!.latitude - newLoc.latitude).abs() + (_driverLatLng!.longitude - newLoc.longitude).abs();
        if (diff > 0.0001) {
          _animTimer?.cancel();
          _animFrom = _driverLatLng;
          _animTo = newLoc;
          _animStep = 0;
          _runAnimStep();
        } else {
          setState(() { _driverLatLng = newLoc; _driverFound = true; });
        }
      } else {
        setState(() { _driverLatLng = newLoc; _driverFound = true; });
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
      if (_animStep < _totalSteps) _runAnimStep();
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
        if (!mounted) return;
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
      builder: (ctx) => ChatBottomSheet(
        socketService: _socketService!,
        rideId: widget.rideData['id']?.toString() ?? '',
        userRole: 'customer',
      ),
    );
  }

  final List<Map<String, String>> _cancelReasons = [
    {'reason': 'Driver is taking too long', 'icon': '⏰'},
    {'reason': 'Changed my mind', 'icon': '🤔'},
    {'reason': 'Found another ride', 'icon': '🚗'},
    {'reason': 'Trip not needed anymore', 'icon': '❌'},
    {'reason': 'Driver behaviour is bad', 'icon': '😠'},
    {'reason': 'Wrong pickup location', 'icon': '📍'},
    {'reason': 'Booking by mistake', 'icon': '😅'},
    {'reason': 'Other', 'icon': '💬'},
  ];

  void _showCancelDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      builder: (ctx) => SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 9, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 34, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(99)))),
          const SizedBox(height: 17),
          Text("Cancel ride?", style: AppText.h2),
          const SizedBox(height: 4),
          Text("Let us know why you're cancelling", style: AppText.body.copyWith(fontSize: 13)),
          const SizedBox(height: 16),
          ...List.generate(_cancelReasons.length, (i) {
            final r = _cancelReasons[i];
            return Padding(padding: const EdgeInsets.only(bottom: 7), child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () { Navigator.pop(ctx); _doCancel(r['reason'] ?? 'Other'); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
                  child: Row(children: [
                    Text(r['icon'] ?? '', style: const TextStyle(fontSize: 17)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r['reason'] ?? '', style: AppText.bodyStrong.copyWith(fontSize: 13.5))),
                  ]),
                ),
              ),
            ));
          }),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, height: 48, child: OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Keep my ride", style: AppText.button))),
        ]),
      )),
    );
  }

  Future<void> _doCancel(String reason) async {
    try {
      final r = await _api.cancelRide(widget.rideData["id"], reason: reason);
      if (r["success"]) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ride cancelled")));
          _goHome();
        }
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to cancel")));
    }
  }

  void _shareRide() {
    Clipboard.setData(ClipboardData(text: "I'm riding with Vybe!\n📍 ${widget.rideData["pickup_address"] ?? "N/A"}\n🏁 ${widget.rideData["drop_address"] ?? "N/A"}\n💰 ₹${widget.rideData["total_fare"] ?? 0}"));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trip details copied")));
  }

  void _goHome() => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);

  Future<void> _showOtpDialog() async {
    final ctrl = TextEditingController();
    String err = '';
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: Text('Enter ride OTP', style: AppText.h3),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Ask your driver for the 4-digit code shown on their screen.', style: AppText.body.copyWith(fontSize: 13)),
        const SizedBox(height: 18),
        TextField(
          controller: ctrl, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, autofocus: true,
          style: AppText.h1.copyWith(letterSpacing: 10, fontSize: 24),
          decoration: const InputDecoration(counterText: '', hintText: '····'),
        ),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10),
          child: Text(err, style: AppText.body.copyWith(color: AppColors.danger, fontSize: 12.5))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (ctrl.text.trim().length != 4) { setD(() => err = 'Enter all 4 digits'); return; }
          try {
            final r = await _api.post('/rides/' + widget.rideData['id'].toString() + '/verify-otp', {'otp': ctrl.text.trim()});
            if (r['success'] == true) {
              Navigator.pop(ctx);
              setState(() => _status = 'started');
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride started')));
            } else {
              setD(() => err = r['error']?['message'] ?? 'Invalid OTP');
            }
          } catch (e) { setD(() => err = 'Network error, try again'); }
        }, child: const Text('Verify')),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    if (_rideCompleted) return _buildRatingPage();
    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(center: _driverLatLng ?? _pickupLatLng, zoom: 15),
          children: [
            TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.vybe.customer"),
            if (_dropLatLng != null) PolylineLayer(polylines: [
              Polyline(points: [_pickupLatLng, _dropLatLng!], strokeWidth: 3.5, color: AppColors.primary.withOpacity(0.7)),
            ]),
            MarkerLayer(markers: [
              Marker(point: _pickupLatLng, width: 22, height: 22, child: Container(
                decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 9)]))),
              if (_driverLatLng != null) Marker(point: _driverLatLng!, width: 60, height: 60,
                child: AnimatedBuilder(animation: _pulseAnim, builder: (ctx, child) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.18), shape: BoxShape.circle),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.electric_rickshaw_rounded, size: 17, color: Colors.white)),
                  )))),
              if (_dropLatLng != null) Marker(point: _dropLatLng!, width: 22, height: 22, child: Container(
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.35), blurRadius: 9)]))),
            ]),
          ],
        ),

        // Top bar
        Positioned(left: 16, right: 16, top: MediaQuery.of(context).padding.top + 10, child: Row(children: [
          _Round(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context)),
          const Spacer(),
          if (_driverFound && _socketService != null) ...[
            _Round(icon: Icons.chat_bubble_rounded, onTap: _openChat),
            const SizedBox(width: 9),
          ],
          _Round(icon: Icons.ios_share_rounded, onTap: _shareRide),
        ])),

        // Bottom status sheet
        Positioned(left: 0, right: 0, bottom: 0, child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(0.13), blurRadius: 26, offset: const Offset(0, -6))],
          ),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              _StatusDot(color: _statusColor(), icon: _statusIcon()),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_statusText(), style: AppText.h3.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text(_statusSubtitle(), style: AppText.label.copyWith(fontSize: 12)),
              ])),
              if (_driverFound && _driverInfo != null) IconButton(
                onPressed: () async {
                  final phone = _driverInfo!["user"]?["phone"] ?? "";
                  if (phone.isNotEmpty) await launchUrl(Uri.parse("tel:$phone"));
                },
                icon: const Icon(Icons.call_rounded, size: 19, color: AppColors.success),
                style: IconButton.styleFrom(backgroundColor: AppColors.success.withOpacity(0.11)),
              ),
            ]),
            if (_driverFound && _driverInfo != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(13)),
                    child: Center(child: Text(
                      (_driverInfo!["user"]?["full_name"] ?? "D").toString().trim().isEmpty
                        ? "D" : (_driverInfo!["user"]?["full_name"] ?? "D").toString().trim()[0].toUpperCase(),
                      style: AppText.h3.copyWith(color: AppColors.primary, fontSize: 16))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_driverInfo!["user"]?["full_name"] ?? "Driver", style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      "${_driverInfo!["vehicle"]?["vehicle_number"] ?? ""} ${_driverInfo!["vehicle"]?["vehicle_model"] ?? ""}".trim(),
                      style: AppText.label.copyWith(fontSize: 11.5)),
                  ])),
                ]),
              ),
            ],
            const SizedBox(height: 13),
            VybeRouteCard(from: widget.rideData["pickup_address"] ?? "", to: widget.rideData["drop_address"] ?? ""),
            const SizedBox(height: 14),
            _buildActionButton(),
          ])),
        )),
      ]),
    );
  }

  Widget _buildActionButton() {
    if (_status == 'completed') {
      return VybeButton(label: "Rate your ride", icon: Icons.star_rounded, color: AppColors.success,
        onPressed: () => setState(() => _rideCompleted = true));
    }
    if (_status == 'driver_arrived') {
      return VybeButton(label: "Enter OTP to start", icon: Icons.lock_open_rounded, color: AppColors.success,
        onPressed: _showOtpDialog);
    }
    if (_status == 'started') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          const SizedBox(width: 11),
          Text("Ride in progress", style: AppText.button.copyWith(color: AppColors.primary)),
        ]),
      );
    }
    return SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(
      onPressed: _showCancelDialog,
      icon: const Icon(Icons.close_rounded, size: 17),
      label: Text("Cancel ride", style: AppText.button),
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger.withOpacity(0.35))),
    ));
  }

  LatLng get _pickupLatLng => LatLng(
    double.tryParse('${widget.rideData["pickup_latitude"] ?? 0}') ?? 0,
    double.tryParse('${widget.rideData["pickup_longitude"] ?? 0}') ?? 0);

  LatLng? get _dropLatLng {
    final lat = double.tryParse('${widget.rideData["drop_latitude"] ?? ""}');
    final lon = double.tryParse('${widget.rideData["drop_longitude"] ?? ""}');
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  Color _statusColor() {
    if (_status == 'driver_assigned') return AppColors.warning;
    if (_status == 'driver_arrived') return AppColors.success;
    if (_status == 'started') return AppColors.primary;
    if (_status == 'completed') return AppColors.success;
    return AppColors.warning;
  }

  IconData _statusIcon() {
    if (_status == 'driver_assigned') return Icons.directions_car_rounded;
    if (_status == 'driver_arrived') return Icons.check_circle_rounded;
    if (_status == 'started') return Icons.navigation_rounded;
    if (_status == 'completed') return Icons.celebration_rounded;
    return Icons.search_rounded;
  }

  String _statusText() {
    if (_status == 'driver_assigned' && _driverInfo != null) return "Driver on the way";
    if (_status == 'driver_assigned') return "Driver assigned";
    if (_status == 'driver_arrived') return "Driver has arrived";
    if (_status == 'started') return "On your way";
    if (_status == 'completed') return "Ride completed";
    return "Finding a driver...";
  }

  String _statusSubtitle() {
    if (_status == 'searching') return "Hang tight, this usually takes a moment";
    if (_driverInfo != null) return "Ride #${widget.rideData["ride_number"] ?? ""}";
    return "Ride #${widget.rideData["ride_number"] ?? ""}";
  }

  Widget _buildRatingPage() => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(children: [
        const Spacer(flex: 2),
        Container(
          width: 84, height: 84,
          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.11), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: AppColors.success, size: 42),
        ),
        const SizedBox(height: 22),
        Text("Ride completed", style: AppText.h1),
        const SizedBox(height: 7),
        Text("Hope you had a good trip. How did it go?", style: AppText.body, textAlign: TextAlign.center),
        const SizedBox(height: 30),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(
          onTap: () => setState(() => _rating = i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: i < _rating ? 1.14 : 1.0,
              child: Icon(i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: i < _rating ? AppColors.warning : AppColors.muted.withOpacity(0.5), size: 40),
            ),
          ),
        ))),
        const Spacer(flex: 3),
        VybeButton(
          label: _ratingSubmitted ? "Thanks!" : "Submit rating",
          onPressed: _rating == 0 || _ratingSubmitted ? null : () async {
            if (_ratingSubmitted) return;
            try {
              await _api.rateRide(widget.rideData["id"], _rating);
              setState(() => _ratingSubmitted = true);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks for rating")));
            } catch (_) {}
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) _goHome();
          },
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: _goHome, child: Text("Skip", style: AppText.button.copyWith(color: AppColors.muted))),
        const SizedBox(height: 8),
      ]),
    )),
  );
}

class _Round extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _Round({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: AppShadow.card),
      child: Icon(icon, size: 18, color: AppColors.ink),
    ),
  );
}

class _StatusDot extends StatelessWidget {
  final Color color; final IconData icon;
  const _StatusDot({required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    width: 46, height: 46,
    decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(15)),
    child: Icon(icon, color: color, size: 22),
  );
}
