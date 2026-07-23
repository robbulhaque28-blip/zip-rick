import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/chat_bottom_sheet.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}
class _DriverHomeScreenState extends State<DriverHomeScreen> with WidgetsBindingObserver {
  io.Socket? _socket; bool _socketConnected = false;
  LatLng? _currentLoc; bool _locationLoading = true, _locationDone = false;
  bool _isOnline = false, _togglingOnline = false;
  Map<String, dynamic>? _rideRequest; bool _showingRideRequest = false;
  Map<String, dynamic>? _activeRide; bool _hasActiveRide = false;
  Map<String, dynamic>? _driverProfile; String _driverName = 'Driver';
  Timer? _pollTimer; int _bottomNavIndex = 0;
  Set<String> _declinedRideIds = {};
  List<Map<String, dynamic>> _chatMessages = [];
  final _chatStreamCtrl = StreamController<Map<String, dynamic>>.broadcast();

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
    _socket!.on('chat:received', (d) {
      if (d is Map) {
        setState(() => _chatMessages.add(d as Map<String, dynamic>));
        _chatStreamCtrl.add(d as Map<String, dynamic>);
      }
    });
    _socket!.on('chat:sent', (d) {
      if (d is Map) {
        setState(() => _chatMessages.add(d as Map<String, dynamic>));
        _chatStreamCtrl.add(d as Map<String, dynamic>);
      }
    });
    _socket!.onDisconnect((_) => setState(() => _socketConnected = false));
    _socket!.connect();
  }

  Future<void> _fetchLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { setState(() => _locationLoading = false); return; }
      if (await Geolocator.checkPermission() == LocationPermission.denied) await Geolocator.requestPermission();
      // Last known first (instant)
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && !_locationDone) {
        setState(() { _currentLoc = LatLng(lastPos.latitude, lastPos.longitude); _locationLoading = false; _locationDone = true; });
      }
      // Precise GPS
      final precisePos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (precisePos != null && mounted) {
        setState(() { _currentLoc = LatLng(precisePos.latitude, precisePos.longitude); _locationLoading = false; _locationDone = true; });
        if (_socket != null && _socketConnected) _sendLocation();
      }
    } catch (_) { if (!_locationDone) setState(() => _locationLoading = false); }
  }

  void _sendLocation() {
    if (_socket != null && _socketConnected && _currentLoc != null) {
      _socket!.emit('driver:location_update', {'latitude': _currentLoc!.latitude, 'longitude': _currentLoc!.longitude});
    }
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
    if (_currentLoc == null) { await _fetchLocation(); if (_currentLoc == null) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable GPS first'))); return; } }
    setState(() => _togglingOnline = true);
    try {
      final r = await ApiService.toggleOnline();
      setState(() { _isOnline = r['data']?['is_online'] == true; _togglingOnline = false; });
      if (_isOnline) { _sendLocation(); if (_socket?.connected == true) _socket!.emit('driver:go_online'); _startPolling(); }
      else { _stopPolling(); if (_socket?.connected == true) _socket!.emit('driver:go_offline'); }
    } catch (e) {
      setState(() => _togglingOnline = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))));
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
  void _rejectRide() { final id = _rideRequest?['ride_id']?.toString() ?? _rideRequest?['id']?.toString() ?? ''; if (id.isNotEmpty) _declinedRideIds.add(id); setState(() { _showingRideRequest = false; _rideRequest = null; }); }

  Future<void> _loadActiveRide() async {
    try { final r = await ApiService.getActiveRide(); setState(() { _activeRide = r['data']?['ride']; _hasActiveRide = _activeRide != null; }); }
    catch (_) { setState(() { _activeRide = null; _hasActiveRide = false; }); }
  }

  void _updateStatus(String e) { if (_socket != null && _activeRide != null) { _socket!.emit(e, {'ride_id': _activeRide!['id']}); if (e == 'ride:complete') setState(() { _hasActiveRide = false; _activeRide = null; }); } }

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DriverChatSheet(
        socket: _socket,
        rideId: _activeRide?['id']?.toString() ?? '',
        messages: _chatMessages,
        streamCtrl: _chatStreamCtrl,
      ),
    );
  }

  Future<void> _callCustomer() async {
    String? p; try { p = _activeRide?['customer']?['user']?['phone']; } catch (_) {}
    if (p != null && p.isNotEmpty) { if (await canLaunchUrl(Uri.parse('tel:$p'))) await launchUrl(Uri.parse('tel:$p')); }
    else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone unavailable')));
  }

  Future<void> _sendSOS() async {
    if (_currentLoc == null) return;
    try { await ApiService.sendSOS(_currentLoc!.latitude, _currentLoc!.longitude); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS sent!'), backgroundColor: Colors.red)); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS failed'))); }
  }

  void _showSupport() {
    final sC = TextEditingController(); final mC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Support'), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: sC, decoration: InputDecoration(labelText: 'Subject', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12), TextField(controller: mC, maxLines: 3, decoration: InputDecoration(labelText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      ]), actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (sC.text.isEmpty || mC.text.isEmpty) return;
          try { await ApiService.createTicket(sC.text, mC.text); if (c.mounted) Navigator.pop(c); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket sent'))); }
          catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed'))); }
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)), child: const Text('Submit')),
      ],
    ));
  }

  Future<void> _logout() async {
    await ApiService.clearToken(); if (_socket != null) { _socket!.emit('driver:go_offline'); _socket!.disconnect(); }
    _pollTimer?.cancel(); if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_hasActiveRide ? 'Active Ride' : 'Vybe Driver'), backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white,
      actions: [
        if (!_hasActiveRide) IconButton(icon: const Icon(Icons.support_agent), onPressed: _showSupport),
        IconButton(icon: const Icon(Icons.sos, color: Colors.redAccent), onPressed: _sendSOS),
        IconButton(icon: Icon(_socketConnected ? Icons.wifi : Icons.wifi_off, color: _socketConnected ? Colors.greenAccent : Colors.orange, size: 20), onPressed: () {}),
      ]),
    body: Stack(children: [
      [_homeTab(), _earningsTab(), _profileTab()][_bottomNavIndex],
      if (_showingRideRequest && _rideRequest != null) _ridePopup(),
    ]),
    bottomNavigationBar: Container(decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: BottomNavigationBar(currentIndex: _bottomNavIndex, onTap: (i) => setState(() => _bottomNavIndex = i),
        selectedItemColor: const Color(0xFF6C63FF), unselectedItemColor: const Color(0xFF9CA3AF),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on_rounded), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ])),
  );

  // ─── HOME TAB ───
  Widget _homeTab() {
    if (_hasActiveRide && _activeRide != null) return _activeRideView();
    return Column(children: [
      Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: _isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9CA3AF),
            child: Icon(_isOnline ? Icons.power_settings_new : Icons.power_off, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isOnline ? 'You are ONLINE' : 'You are OFFLINE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9CA3AF))),
            Text(_isOnline ? 'Ride requests appear here' : 'Go online to receive rides', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
          ])),
          Switch(value: _isOnline, onChanged: _togglingOnline ? null : (_) => _toggleOnline(), activeColor: const Color(0xFF4CAF50)),
        ])),
      Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: _currentLoc != null
              ? FlutterMap(options: MapOptions(center: _currentLoc!, zoom: 15), children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.vybe.driver'),
                  MarkerLayer(markers: [Marker(point: _currentLoc!, width: 80, height: 80, child: Icon(Icons.electric_rickshaw_rounded, size: 48, color: _isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9CA3AF)))]),
                ])
              : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Fetching location...')])),
        ),
      ),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(onPressed: _fetchLocation, icon: const Icon(Icons.my_location), label: const Text('Refresh Location'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
      const SizedBox(height: 12),
    ]);
  }

  Widget _activeRideView() {
    final r = _activeRide!; final status = r['status'] ?? '';
    String st = ''; Color sc = const Color(0xFF6C63FF);
    if (status == 'driver_assigned') { st = 'Heading to pickup'; sc = const Color(0xFFFFA726); }
    else if (status == 'driver_arrived') { st = 'Arrived'; sc = const Color(0xFF4CAF50); }
    else if (status == 'started') { st = 'In progress'; sc = const Color(0xFF6C63FF); }
    else if (status == 'completed') { st = 'Completed'; sc = const Color(0xFF4CAF50); }
    else st = status;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: sc.withOpacity(0.3))),
        child: Row(children: [Icon(Icons.info_outline, color: sc, size: 32), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status: $st', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sc)),
          Text('Fare: ₹${r['total_fare'] ?? '--'}', style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
        ]))])),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [const Icon(Icons.trip_origin, color: Color(0xFF4CAF50), size: 24), const SizedBox(width: 12), Expanded(child: Text(r['pickup_address'] ?? 'Pickup'))]),
        const Divider(height: 20),
        Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 24), const SizedBox(width: 12), Expanded(child: Text(r['drop_address'] ?? 'Drop'))]),
      ]))),
      const SizedBox(height: 16),
      if (status == 'driver_assigned') _btn('Arrived', Icons.check_circle, const Color(0xFFFFA726), () => _updateStatus('ride:arrived')),
      if (status == 'driver_arrived') _btn('Start Ride', Icons.play_arrow, const Color(0xFF4CAF50), () => _updateStatus('ride:start')),
      if (status == 'started') _btn('Complete Ride', Icons.stop_circle, const Color(0xFF6C63FF), () => _updateStatus('ride:complete')),
      if (status == 'completed') _btn('Done', Icons.home, const Color(0xFF4CAF50), () => setState(() { _hasActiveRide = false; _activeRide = null; })),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _openChat, icon: const Icon(Icons.chat_rounded), label: const Text('Chat'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: _callCustomer, icon: const Icon(Icons.phone), label: const Text('Call'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      ]),
    ]);
  }

  Widget _btn(String l, IconData i, Color c, VoidCallback o) => SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: o, icon: Icon(i), label: Text(l),
    style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));

  Widget _ridePopup() {
    final r = _rideRequest!;
    return Positioned(top: 0, left: 0, right: 0, child: Material(elevation: 8, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFFA726).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.notifications_active, color: Color(0xFFFFA726), size: 18), SizedBox(width: 6), Text('New Ride!', style: TextStyle(color: Color(0xFFFFA726), fontWeight: FontWeight.bold))])),
          const SizedBox(height: 12),
          if (r['distance_km'] != null) Text('${r['distance_km']} km away', style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.trip_origin, color: Color(0xFF4CAF50), size: 20), const SizedBox(width: 8), Expanded(child: Text(r['pickup_address'] ?? 'Pickup', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))]),
          const SizedBox(height: 6),
          Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(r['drop_address'] ?? 'Drop', style: const TextStyle(fontSize: 15)))]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Fare: ', style: TextStyle(fontSize: 18)), Text('₹${r['total_fare'] ?? '--'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)))]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _acceptRide, icon: const Icon(Icons.check_circle), label: const Text('Accept'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(onPressed: _rejectRide, icon: const Icon(Icons.cancel), label: const Text('Decline'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ]),
        ]))));
  }

  // ─── EARNINGS TAB ───
  Widget _earningsTab() => FutureBuilder<Map<String, dynamic>>(
    future: ApiService.getEarnings(),
    builder: (c, s) {
      if (s.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), const Text('Could not load earnings'), ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry'))]));
      final d = s.data?['data'] ?? {};
      return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Earnings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))), const SizedBox(height: 20),
        Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)]), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total Earnings', style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 8),
            Text('₹${d['total_earnings'] ?? '0'}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8), Text('${d['total_rides'] ?? '0'} rides', style: const TextStyle(color: Colors.white70)),
          ])),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _ec('Today', '₹${d['today_earnings'] ?? '0'}', Icons.today, const Color(0xFF4CAF50))),
          const SizedBox(width: 12),
          Expanded(child: _ec('Week', '₹${d['week_earnings'] ?? '0'}', Icons.date_range, const Color(0xFFFFA726))),
        ]),
      ]));
    },
  );
  Widget _ec(String l, String a, IconData i, Color c) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Icon(i, color: c, size: 28), const SizedBox(height: 8), Text(a, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)), const SizedBox(height: 4), Text(l, style: const TextStyle(color: Color(0xFF9CA3AF)))])));

  // ─── PROFILE TAB ───
  Widget _profileTab() {
    final docs = (_driverProfile?['documents'] as List?) ?? [];
    final docStatus = <String, bool>{};
    for (final d in docs) { if (d is Map) docStatus[d['document_type']?.toString() ?? ''] = d['status'] == 'approved'; }
    final v = _driverProfile?['vehicle'] as Map?;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Center(child: Column(children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle),
          child: Text(_driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)))),
        const SizedBox(height: 12), Text(_driverName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: (_isOnline ? const Color(0xFF4CAF50) : Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Text(_isOnline ? 'Online' : 'Offline', style: TextStyle(color: _isOnline ? const Color(0xFF4CAF50) : Colors.grey, fontWeight: FontWeight.bold))),
      ])),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _sc('Rating', '${_driverProfile?['rating_avg'] ?? '0.0'}', Icons.star_rounded, Colors.amber)),
        const SizedBox(width: 8), Expanded(child: _sc('Rides', '${_driverProfile?['total_rides'] ?? '0'}', Icons.directions_car_rounded, const Color(0xFF6C63FF))),
        const SizedBox(width: 8), Expanded(child: _sc('Status', '${_driverProfile?['registration_status'] ?? 'pending'}', Icons.verified_user_rounded, const Color(0xFF4CAF50))),
      ]),
      const SizedBox(height: 20),
      // Documents
      const Text('Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))), const SizedBox(height: 8),
      Card(child: Column(children: [
        _ds('Aadhaar', docStatus['aadhaar_front'] == true || docStatus['aadhaar'] == true), const Divider(height: 1, indent: 16, endIndent: 16),
        _ds('Selfie', docStatus['selfie'] == true), const Divider(height: 1, indent: 16, endIndent: 16),
        _ds('Vehicle RC', docStatus['rc'] == true), const Divider(height: 1, indent: 16, endIndent: 16),
        _ds('Insurance', docStatus['insurance'] == true),
      ])),
      // Vehicle
      if (v != null) ...[const SizedBox(height: 16), const Text('Vehicle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))), const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          _ir('Number', v['vehicle_number']?.toString() ?? 'N/A'), const Divider(height: 1, indent: 16, endIndent: 16),
          _ir('Model', v['vehicle_model']?.toString() ?? 'N/A'),
        ]))),
      ],
      // Registration status
      const SizedBox(height: 16), const Text('Registration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))), const SizedBox(height: 8),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        _ir('Fee Paid', _driverProfile?['registration_fee_paid'] == true ? 'Yes' : 'No'),
        const Divider(height: 1, indent: 16, endIndent: 16),
        _ir('Status', (_driverProfile?['registration_status'] ?? 'pending').toString().toUpperCase()),
      ]))),
      // Ratings if any
      if ((_driverProfile?['total_ratings'] ?? 0) > 0) ...[const SizedBox(height: 16), const Text('Ratings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))), const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          _ir('Average', '${_driverProfile?['rating_avg'] ?? '0.0'}'), const Divider(height: 1, indent: 16, endIndent: 16),
          _ir('Total', '${_driverProfile?['total_ratings'] ?? '0'}'),
        ]))),
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout, color: Colors.red), label: const Text('Logout', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: Colors.red)))),
      const SizedBox(height: 20),
    ]));
  }
  Widget _sc(String l, String v, IconData i, Color c) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Icon(i, color: c, size: 24), const SizedBox(height: 4), Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)), Text(l, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))])));
  Widget _ds(String l, bool ok) => ListTile(leading: Icon(ok ? Icons.check_circle : Icons.pending, color: ok ? const Color(0xFF4CAF50) : const Color(0xFFFFA726)), title: Text(l), trailing: Text(ok ? 'Verified' : 'Pending', style: TextStyle(color: ok ? const Color(0xFF4CAF50) : const Color(0xFFFFA726), fontWeight: FontWeight.w500)));
  Widget _ir(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Color(0xFF9CA3AF))), Text(v, style: const TextStyle(fontWeight: FontWeight.w500))]));
}
