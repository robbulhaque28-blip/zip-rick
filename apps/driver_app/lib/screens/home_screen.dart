import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/chat_bottom_sheet.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

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
  bool _acceptPending = false;
  StreamSubscription<Position>? _posSub;
  String? _destAddress;
  List<Map<String, dynamic>> _chatMessages = [];
  final _chatStreamCtrl = StreamController<Map<String, dynamic>>.broadcast();

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _fetchLocation(); _connectSocket(); _loadProfile(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _pollTimer?.cancel(); _posSub?.cancel(); _socket?.disconnect(); _socket?.dispose(); super.dispose(); }

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
    _socket!.on('ride:accept_error', (d) {
      if (!mounted) return;
      final msg = (d is Map ? d['message'] : null) ?? 'Could not accept this ride';
      setState(() { _hasActiveRide = false; _activeRide = null; _acceptPending = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg.toString()), duration: const Duration(seconds: 6), backgroundColor: AppColors.danger));
    });
    _socket!.on('ride:accepted_confirmation', (d) {
      if (!mounted) return;
      setState(() { _acceptPending = false; _hasActiveRide = true; });
      _loadActiveRide();
    });
    _socket!.on('ride:taken', (d) { if (mounted && _showingRideRequest) setState(() { _showingRideRequest = false; _rideRequest = null; }); });
    _socket!.on('ride:status_updated', (d) {
      if (!mounted) return;
      _loadActiveRide();
    });
    _socket!.on('ride:started', (d) {
      if (!mounted) return;
      _loadActiveRide();
    });
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
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() => _locationLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location is turned off. Please enable GPS.'), duration: Duration(seconds: 5)));
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission denied. Enable it in Settings.'), duration: Duration(seconds: 5)));
        }
        return;
      }

      // Cached fix only shows the map something while GPS warms up.
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && !_locationDone && mounted) {
        if (lastPos.accuracy <= 100) {
          setState(() { _currentLoc = LatLng(lastPos.latitude, lastPos.longitude); _locationLoading = false; });
        }
      }

      final precisePos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 25),
      );
      if (!mounted) return;
      setState(() { _currentLoc = LatLng(precisePos.latitude, precisePos.longitude); _locationLoading = false; _locationDone = true; });
      if (_socket != null && _socketConnected) _sendLocation();
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationLoading = false);
      if (!_locationDone) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not get an accurate GPS fix. Move to an open area.'), duration: Duration(seconds: 5)));
      }
    }
  }

  void _startLocationStream() {
    _posSub?.cancel();
    // Push a position every 20 m so the customer map tracks the driver live.
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _currentLoc = LatLng(pos.latitude, pos.longitude));
      _sendLocation();
    }, onError: (_) {});
  }

  void _stopLocationStream() { _posSub?.cancel(); _posSub = null; }

  void _sendLocation() {
    final loc = _currentLoc;
    if (loc == null) return;
    if (_socket != null && _socketConnected) {
      _socket!.emit('driver:location_update', {'latitude': loc.latitude, 'longitude': loc.longitude});
      return;
    }
    // Socket is down. Fall back to HTTP so the stored position does not go
    // stale and silently drop this driver out of matching.
    if (_isOnline) {
      ApiService.sendLocation(loc.latitude, loc.longitude).catchError((_) => <String, dynamic>{});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isOnline) _startLocationStream();
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
    final goingOnline = !_isOnline;

    // Going online without coordinates makes this driver invisible to ride
    // matching, so insist on a real fix before asking the server.
    if (goingOnline && _currentLoc == null) {
      setState(() => _togglingOnline = true);
      await _fetchLocation();
      if (!mounted) return;
      if (_currentLoc == null) {
        setState(() => _togglingOnline = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not get your location. Turn on GPS and try again.'),
          duration: Duration(seconds: 5)));
        return;
      }
    }

    setState(() => _togglingOnline = true);
    try {
      final r = await ApiService.toggleOnline(
        latitude: goingOnline ? _currentLoc?.latitude : null,
        longitude: goingOnline ? _currentLoc?.longitude : null,
        isOnline: goingOnline,
      );
      final data = r['data'];
      if (!mounted) return;
      setState(() { _isOnline = data?['is_online'] == true; _togglingOnline = false; });

      if (_isOnline) {
        // Confirm the server actually stored a position. If it did not, the
        // driver would sit online receiving nothing at all.
        final hasFix = data?['current_latitude'] != null && data?['current_longitude'] != null;
        if (!hasFix) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Online, but your location is not set yet. Ride requests may not arrive.'),
            duration: Duration(seconds: 6)));
        }
        _sendLocation();
        if (_socket?.connected == true) _socket!.emit('driver:go_online');
        _startPolling();
        _startLocationStream();
      } else {
        _stopPolling();
        _stopLocationStream();
        if (_socket?.connected == true) _socket!.emit('driver:go_offline');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _togglingOnline = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst("Exception: ", "")),
        duration: const Duration(seconds: 5)));
    }
  }

  void _startPolling() { _pollTimer?.cancel(); _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollForRides()); }
  void _stopPolling() { _pollTimer?.cancel(); _pollTimer = null; }

  Future<void> _pollForRides() async {
    // While on a ride, poll its status instead of looking for new requests.
    if (_hasActiveRide) { await _loadActiveRide(); return; }
    if (!_isOnline || _showingRideRequest) return;
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
    if (!_socketConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Not connected. Check your internet and try again.'), duration: Duration(seconds: 4)));
      return;
    }
    final rideId = (_rideRequest!['ride_id'] ?? _rideRequest!['id'])?.toString();
    setState(() { _acceptPending = true; _showingRideRequest = false; });
    _socket!.emit('ride:accept', {'ride_id': rideId});

    // Fall back to polling in case the confirmation event never arrives.
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || !_acceptPending) return;
    await _loadActiveRide();
    _startPolling();
    if (!mounted) return;
    if (_hasActiveRide) {
      setState(() => _acceptPending = false);
    } else {
      setState(() { _acceptPending = false; _rideRequest = null; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not accept. Your account may still be pending approval, or another driver took it.'),
        duration: Duration(seconds: 6)));
    }
  }

  void _rejectRide() {
    final id = _rideRequest?['ride_id']?.toString() ?? _rideRequest?['id']?.toString() ?? '';
    if (id.isNotEmpty) _declinedRideIds.add(id);
    setState(() { _showingRideRequest = false; _rideRequest = null; });
  }

  Future<void> _loadActiveRide() async {
    try { final r = await ApiService.getActiveRide(); setState(() { _activeRide = r['data']?['ride']; _hasActiveRide = _activeRide != null; }); }
    catch (_) { setState(() { _activeRide = null; _hasActiveRide = false; }); }
  }

  void _updateStatus(String e) {
    if (_socket != null && _activeRide != null) {
      _socket!.emit(e, {'ride_id': _activeRide!['id']});
      if (e == 'ride:complete') setState(() { _hasActiveRide = false; _activeRide = null; });
    }
  }

  Future<void> _showOtpDialog() async {
    final ctrl = TextEditingController();
    String err = '';
    bool busy = false;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: Text('Enter ride OTP', style: AppText.h3),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Ask the customer for their 4-digit code.', style: AppText.body.copyWith(fontSize: 13)),
        const SizedBox(height: 18),
        TextField(
          controller: ctrl, keyboardType: TextInputType.number, maxLength: 4,
          textAlign: TextAlign.center, autofocus: true,
          style: AppText.h1.copyWith(letterSpacing: 10, fontSize: 24),
          decoration: const InputDecoration(counterText: '', hintText: '----'),
        ),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10),
          child: Text(err, style: AppText.body.copyWith(color: AppColors.danger, fontSize: 12.5))),
      ]),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: busy ? null : () async {
          if (ctrl.text.trim().length != 4) { setD(() => err = 'Enter all 4 digits'); return; }
          setD(() { busy = true; err = ''; });
          try {
            await ApiService.post('/rides/' + (_activeRide?['id']?.toString() ?? '') + '/verify-otp', {'otp': ctrl.text.trim()});
            if (ctx.mounted) Navigator.pop(ctx);
            await _loadActiveRide();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride started')));
          } catch (e) {
            setD(() { busy = false; err = e.toString().replaceFirst('Exception: ', ''); });
          }
        }, child: const Text('Verify')),
      ],
    )));
  }

  void _showDestDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Destination filter', style: AppText.h3),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Set where you're heading to get rides along your route.", style: AppText.body.copyWith(fontSize: 13)),
        const SizedBox(height: 14),
        const TextField(decoration: InputDecoration(hintText: 'Enter destination')),
        const SizedBox(height: 10),
        const TextField(decoration: InputDecoration(hintText: 'Search radius', suffixText: 'km'), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          setState(() => _destAddress = 'Destination set');
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destination filter active')));
        }, child: const Text('Set')),
      ],
    ));
  }

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
    try {
      await ApiService.sendSOS(_currentLoc!.latitude, _currentLoc!.longitude);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS sent'), backgroundColor: AppColors.danger));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS failed')));
    }
  }

  void _showSupport() {
    final sC = TextEditingController(); final mC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text('Contact support', style: AppText.h3),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: sC, decoration: const InputDecoration(hintText: 'Subject')),
        const SizedBox(height: 10),
        TextField(controller: mC, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe your issue')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (sC.text.isEmpty || mC.text.isEmpty) return;
          try {
            await ApiService.createTicket(sC.text, mC.text);
            if (c.mounted) Navigator.pop(c);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket sent')));
          } catch (_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send')));
          }
        }, child: const Text('Submit')),
      ],
    ));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Log out?', style: AppText.h3),
      content: Text("You'll go offline and stop receiving rides.", style: AppText.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Log out')),
      ],
    ));
    if (ok != true) return;
    await ApiService.clearToken();
    if (_socket != null) { _socket!.emit('driver:go_offline'); _socket!.disconnect(); }
    _pollTimer?.cancel();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      SafeArea(child: [_homeTab(), _earningsTab(), _profileTab()][_bottomNavIndex]),
      if (_showingRideRequest && _rideRequest != null) _ridePopup(),
    ]),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, -3))],
      ),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          _NavItem(icon: Icons.explore_rounded, label: 'Home', active: _bottomNavIndex == 0, onTap: () => setState(() => _bottomNavIndex = 0)),
          _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Earnings', active: _bottomNavIndex == 1, onTap: () => setState(() => _bottomNavIndex = 1)),
          _NavItem(icon: Icons.person_rounded, label: 'Profile', active: _bottomNavIndex == 2, onTap: () => setState(() => _bottomNavIndex = 2)),
        ]),
      )),
    ),
  );

  // HOME TAB
  Widget _homeTab() {
    if (_hasActiveRide && _activeRide != null) return _activeRideView();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello, $_driverName', style: AppText.h3.copyWith(fontSize: 16)),
            const SizedBox(height: 2),
            Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(
                color: _socketConnected ? AppColors.success : AppColors.warning, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(_socketConnected ? 'Connected' : 'Reconnecting...', style: AppText.label.copyWith(fontSize: 11.5)),
            ]),
          ])),
          _Round(icon: Icons.headset_mic_rounded, onTap: _showSupport),
          const SizedBox(width: 8),
          _Round(icon: Icons.warning_rounded, color: AppColors.danger, onTap: _sendSOS),
        ]),
      ),
      const SizedBox(height: 14),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: VybeFadeIn(child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: _isOnline ? AppColors.success : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: _isOnline ? AppColors.success : AppColors.line),
          boxShadow: _isOnline ? [BoxShadow(color: AppColors.success.withOpacity(0.26), blurRadius: 18, offset: const Offset(0, 5))] : AppShadow.soft,
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _isOnline ? Colors.white.withOpacity(0.22) : AppColors.canvas,
              borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.power_settings_new_rounded, size: 21,
              color: _isOnline ? Colors.white : AppColors.muted),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isOnline ? "You're online" : "You're offline",
              style: AppText.h3.copyWith(fontSize: 15.5, color: _isOnline ? Colors.white : AppColors.ink)),
            const SizedBox(height: 2),
            Text(_isOnline ? 'Waiting for ride requests' : 'Go online to start earning',
              style: AppText.label.copyWith(fontSize: 11.5,
                color: _isOnline ? Colors.white.withOpacity(0.85) : AppColors.muted)),
          ])),
          Switch(
            value: _isOnline,
            onChanged: _togglingOnline ? null : (_) => _toggleOnline(),
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.4),
          ),
        ]),
      ))),
      const SizedBox(height: 13),
      Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(children: [
            _currentLoc != null
              ? FlutterMap(
                  options: MapOptions(center: _currentLoc!, zoom: 15),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.vybe.driver'),
                    MarkerLayer(markers: [Marker(point: _currentLoc!, width: 46, height: 46,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_isOnline ? AppColors.success : AppColors.muted).withOpacity(0.22),
                          shape: BoxShape.circle),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isOnline ? AppColors.success : AppColors.muted, shape: BoxShape.circle),
                          child: const Icon(Icons.electric_rickshaw_rounded, size: 16, color: Colors.white)),
                      ))]),
                  ])
              : Container(
                  color: AppColors.canvas,
                  child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const CircularProgressIndicator(strokeWidth: 2.4),
                    const SizedBox(height: 14),
                    Text('Finding your location...', style: AppText.body.copyWith(fontSize: 13)),
                  ]))),
            Positioned(right: 12, bottom: 12, child: GestureDetector(
              onTap: () { _locationDone = false; _fetchLocation(); },
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), boxShadow: AppShadow.card),
                child: const Icon(Icons.my_location_rounded, size: 19, color: AppColors.primary),
              ),
            )),
          ]),
        ),
      )),
      const SizedBox(height: 13),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        Expanded(child: SizedBox(height: 46, child: OutlinedButton.icon(
          onPressed: _showDestDialog,
          icon: const Icon(Icons.route_rounded, size: 17),
          label: Text(_destAddress ?? 'Destination', style: AppText.button.copyWith(fontSize: 13.5)),
        ))),
      ])),
      const SizedBox(height: 13),
    ]);
  }

  Widget _activeRideView() {
    final r = _activeRide!;
    final status = (r['status'] ?? '').toString();
    String st = status; Color sc = AppColors.primary; IconData si = Icons.navigation_rounded;
    if (status == 'driver_assigned') { st = 'Heading to pickup'; sc = AppColors.warning; si = Icons.directions_car_rounded; }
    else if (status == 'driver_arrived') { st = 'Waiting for customer'; sc = AppColors.success; si = Icons.check_circle_rounded; }
    else if (status == 'started') { st = 'Ride in progress'; sc = AppColors.primary; si = Icons.navigation_rounded; }
    else if (status == 'completed') { st = 'Ride completed'; sc = AppColors.success; si = Icons.celebration_rounded; }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
      Row(children: [
        Expanded(child: Text('Active ride', style: AppText.h2)),
        _Round(icon: Icons.warning_rounded, color: AppColors.danger, onTap: _sendSOS),
      ]),
      const SizedBox(height: 14),
      VybeFadeIn(child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: sc.withOpacity(0.09), borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: sc.withOpacity(0.25))),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(15)),
            child: Icon(si, color: sc, size: 22)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(st, style: AppText.h3.copyWith(fontSize: 15.5, color: sc)),
            const SizedBox(height: 2),
            Text('Fare  Rs ${r['total_fare'] ?? '--'}', style: AppText.label.copyWith(fontSize: 12)),
          ])),
        ]),
      )),
      if (status == 'driver_arrived') ...[
        const SizedBox(height: 12),
        VybeFadeIn(delayMs: 60, child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Row(children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 19),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ASK THE CUSTOMER', style: AppText.tiny.copyWith(color: Colors.white.withOpacity(0.65))),
              const SizedBox(height: 3),
              Text('They will read out a 4-digit code', style: AppText.label.copyWith(color: Colors.white.withOpacity(0.8), fontSize: 11.5)),
            ])),
          ]),
        )),
      ],
      const SizedBox(height: 12),
      VybeFadeIn(delayMs: 100, child: VybeRouteCard(
        from: r['pickup_address'] ?? 'Pickup',
        to: r['drop_address'] ?? 'Drop',
      )),
      const SizedBox(height: 16),
      if (status == 'driver_assigned') VybeButton(label: "I've arrived", icon: Icons.check_circle_rounded, color: AppColors.warning, onPressed: () => _updateStatus('ride:arrived')),
      if (status == 'driver_arrived') VybeButton(label: 'Enter OTP to start', icon: Icons.lock_open_rounded, color: AppColors.success, onPressed: _showOtpDialog),
      if (status == 'started') VybeButton(label: 'Complete ride', icon: Icons.flag_rounded, onPressed: () => _updateStatus('ride:complete')),
      if (status == 'completed') VybeButton(label: 'Done', icon: Icons.home_rounded, color: AppColors.success, onPressed: () => setState(() { _hasActiveRide = false; _activeRide = null; })),
      const SizedBox(height: 11),
      Row(children: [
        Expanded(child: SizedBox(height: 48, child: OutlinedButton.icon(
          onPressed: _openChat,
          icon: const Icon(Icons.chat_bubble_rounded, size: 16),
          label: Text('Chat', style: AppText.button.copyWith(fontSize: 13.5))))),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 48, child: OutlinedButton.icon(
          onPressed: _callCustomer,
          icon: const Icon(Icons.call_rounded, size: 16),
          label: Text('Call', style: AppText.button.copyWith(fontSize: 13.5)),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.success, side: BorderSide(color: AppColors.success.withOpacity(0.35)))))),
      ]),
    ]);
  }

  Widget _ridePopup() {
    final r = _rideRequest!;
    return Positioned(top: 0, left: 0, right: 0, child: Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 16, 18, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
          boxShadow: AppShadow.lifted,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.notifications_active_rounded, color: AppColors.warning, size: 14),
                const SizedBox(width: 6),
                Text('NEW RIDE', style: AppText.tiny.copyWith(color: AppColors.warning, fontSize: 10)),
              ]),
            ),
            const Spacer(),
            if (r['distance_km'] != null)
              Text('${r['distance_km']} km away', style: AppText.label.copyWith(fontSize: 11.5)),
          ]),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOU EARN', style: AppText.tiny),
              const SizedBox(height: 3),
              Text('Rs ${r['total_fare'] ?? '--'}', style: AppText.h1.copyWith(fontSize: 26)),
            ])),
          ]),
          const SizedBox(height: 14),
          VybeRouteCard(from: r['pickup_address'] ?? 'Pickup', to: r['drop_address'] ?? 'Drop'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: SizedBox(height: 50, child: OutlinedButton(
              onPressed: _rejectRide,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.muted, side: const BorderSide(color: AppColors.line)),
              child: Text('Decline', style: AppText.button.copyWith(color: AppColors.body))))),
            const SizedBox(width: 11),
            Expanded(flex: 2, child: SizedBox(height: 50, child: ElevatedButton(
              onPressed: _acceptRide,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: Text('Accept ride', style: AppText.button.copyWith(color: Colors.white, fontSize: 15))))),
          ]),
        ]),
      ),
    ));
  }

  // EARNINGS TAB
  Widget _earningsTab() => FutureBuilder<Map<String, dynamic>>(
    future: ApiService.getEarnings(),
    builder: (c, s) {
      if (s.connectionState == ConnectionState.waiting) return const VybeListSkeleton(count: 4);
      if (s.hasError) {
        return VybeEmpty(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load earnings',
          subtitle: 'Check your connection and try again.',
          action: SizedBox(width: 150, child: ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry'))),
        );
      }
      final d = s.data?['data'] ?? {};
      final daily = (d['daily_earnings'] as List?) ?? [];
      final maxAmount = daily.fold<double>(0, (p, x) => ((x['amount'] ?? 0) as num).toDouble() > p ? ((x['amount'] ?? 0) as num).toDouble() : p);
      return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
        Text('Earnings', style: AppText.h2),
        const SizedBox(height: 16),
        VybeFadeIn(child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOTAL EARNED', style: AppText.tiny.copyWith(color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 7),
            Text('Rs ${d['total_earnings'] ?? '0'}', style: AppText.h1.copyWith(color: Colors.white, fontSize: 29)),
            const SizedBox(height: 6),
            Text('${d['total_rides'] ?? '0'} rides completed', style: AppText.label.copyWith(color: Colors.white.withOpacity(0.75), fontSize: 12)),
          ]),
        )),
        const SizedBox(height: 12),
        VybeFadeIn(delayMs: 60, child: Row(children: [
          Expanded(child: _EarnCard(label: 'Today', value: 'Rs ${d['today_earnings'] ?? '0'}', icon: Icons.wb_sunny_rounded, color: AppColors.success)),
          const SizedBox(width: 11),
          Expanded(child: _EarnCard(label: 'This week', value: 'Rs ${d['week_earnings'] ?? '0'}', icon: Icons.date_range_rounded, color: AppColors.warning)),
        ])),
        if (daily.isNotEmpty) ...[
          const SizedBox(height: 12),
          VybeFadeIn(delayMs: 110, child: VybeCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('THIS WEEK', style: AppText.tiny),
            const SizedBox(height: 16),
            SizedBox(height: 108, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: daily.map<Widget>((day) {
              final amount = ((day['amount'] ?? 0) as num).toDouble();
              final h = maxAmount > 0 ? (amount / maxAmount * 74).clamp(4.0, 74.0) : 4.0;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${amount.toInt()}', style: AppText.tiny.copyWith(fontSize: 9, color: AppColors.primary)),
                  const SizedBox(height: 5),
                  Container(
                    width: double.infinity, height: h,
                    decoration: BoxDecoration(
                      color: amount > 0 ? AppColors.primary : AppColors.line,
                      borderRadius: BorderRadius.circular(5)),
                  ),
                  const SizedBox(height: 6),
                  Text('${day['day'] ?? ''}', style: AppText.label.copyWith(fontSize: 10)),
                ]),
              ));
            }).toList())),
          ]))),
        ],
        const SizedBox(height: 12),
        VybeFadeIn(delayMs: 160, child: VybeCard(child: Row(children: [
          const VybeIconBox(icon: Icons.trending_up_rounded, size: 42),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Monthly estimate', style: AppText.label.copyWith(fontSize: 11.5)),
            const SizedBox(height: 3),
            Text('Rs ${((double.tryParse('${d['week_earnings'] ?? '0'}') ?? 0) * 4.33).toStringAsFixed(0)}',
              style: AppText.h2.copyWith(fontSize: 21)),
          ])),
          const VybeBadge(text: 'Projected'),
        ]))),
      ]);
    },
  );

  // PROFILE TAB
  Widget _profileTab() {
    final docs = (_driverProfile?['documents'] as List?) ?? [];
    final docStatus = <String, bool>{};
    for (final d in docs) { if (d is Map) docStatus[d['document_type']?.toString() ?? ''] = d['status'] == 'approved'; }
    final v = _driverProfile?['vehicle'] as Map?;
    final regStatus = (_driverProfile?['registration_status'] ?? 'pending').toString();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
      VybeFadeIn(child: VybeCard(padding: const EdgeInsets.all(18), child: Row(children: [
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
          child: Center(child: Text(
            _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D',
            style: AppText.h2.copyWith(color: Colors.white, fontSize: 23))),
        ),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_driverName, style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          VybeBadge(text: _isOnline ? 'Online' : 'Offline', color: _isOnline ? AppColors.success : AppColors.muted),
        ])),
      ]))),
      const SizedBox(height: 12),
      VybeFadeIn(delayMs: 60, child: Row(children: [
        Expanded(child: _Stat(icon: Icons.star_rounded, value: '${_driverProfile?['rating_avg'] ?? '0.0'}', label: 'Rating', color: AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(icon: Icons.route_rounded, value: '${_driverProfile?['total_rides'] ?? '0'}', label: 'Rides', color: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(icon: Icons.verified_user_rounded, value: regStatus == 'approved' ? 'Yes' : 'No', label: 'Verified', color: AppColors.success)),
      ])),
      const SizedBox(height: 22),
      Text('DOCUMENTS', style: AppText.tiny),
      const SizedBox(height: 9),
      VybeFadeIn(delayMs: 110, child: VybeCard(padding: EdgeInsets.zero, child: Column(children: [
        _DocRow(label: 'Aadhaar', ok: docStatus['aadhaar_front'] == true || docStatus['aadhaar'] == true),
        const Divider(height: 1, indent: 15),
        _DocRow(label: 'Live photo', ok: docStatus['selfie'] == true),
        const Divider(height: 1, indent: 15),
        _DocRow(label: 'Vehicle RC', ok: docStatus['rc'] == true),
        const Divider(height: 1, indent: 15),
        _DocRow(label: 'Insurance', ok: docStatus['insurance'] == true),
      ]))),
      if (v != null) ...[
        const SizedBox(height: 20),
        Text('VEHICLE', style: AppText.tiny),
        const SizedBox(height: 9),
        VybeFadeIn(delayMs: 150, child: VybeCard(child: Column(children: [
          _InfoRow(label: 'Number', value: v['vehicle_number']?.toString() ?? 'N/A'),
          const SizedBox(height: 10),
          _InfoRow(label: 'Model', value: v['vehicle_model']?.toString() ?? 'N/A'),
        ]))),
      ],
      const SizedBox(height: 20),
      Text('REGISTRATION', style: AppText.tiny),
      const SizedBox(height: 9),
      VybeFadeIn(delayMs: 190, child: VybeCard(child: Column(children: [
        _InfoRow(label: 'Fee paid', value: _driverProfile?['registration_fee_paid'] == true ? 'Yes' : 'No'),
        const SizedBox(height: 10),
        _InfoRow(label: 'Status', value: regStatus.toUpperCase()),
      ]))),
      const SizedBox(height: 22),
      SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, size: 17),
        label: Text('Log out', style: AppText.button),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger.withOpacity(0.35))),
      )),
      const SizedBox(height: 18),
      Center(child: Text('Vybe Driver  v1.0.0', style: AppText.label.copyWith(fontSize: 11.5))),
    ]);
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 23, color: active ? AppColors.primary : AppColors.muted),
        const SizedBox(height: 4),
        Text(label, style: AppText.label.copyWith(
          fontSize: 11.5,
          color: active ? AppColors.primary : AppColors.muted,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
      ]),
    ),
  ));
}

class _Round extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color? color;
  const _Round({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), boxShadow: AppShadow.soft),
      child: Icon(icon, size: 18, color: color ?? AppColors.body),
    ),
  );
}

class _Stat extends StatelessWidget {
  final IconData icon; final String value; final String label; final Color color;
  const _Stat({required this.icon, required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => VybeCard(
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(height: 10),
      Text(value, style: AppText.h2.copyWith(fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label, style: AppText.label.copyWith(fontSize: 11)),
    ]),
  );
}

class _EarnCard extends StatelessWidget {
  final String label; final String value; final IconData icon; final Color color;
  const _EarnCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => VybeCard(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(height: 11),
      Text(value, style: AppText.h2.copyWith(fontSize: 19)),
      const SizedBox(height: 2),
      Text(label, style: AppText.label.copyWith(fontSize: 11.5)),
    ]),
  );
}

class _DocRow extends StatelessWidget {
  final String label; final bool ok;
  const _DocRow({required this.label, required this.ok});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    child: Row(children: [
      Icon(ok ? Icons.check_circle_rounded : Icons.pending_rounded,
        color: ok ? AppColors.success : AppColors.warning, size: 19),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: AppText.bodyStrong.copyWith(fontSize: 13.5))),
      VybeBadge(text: ok ? 'Verified' : 'Pending', color: ok ? AppColors.success : AppColors.warning),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label; final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: AppText.body.copyWith(fontSize: 13)),
      Text(value, style: AppText.bodyStrong.copyWith(fontSize: 13)),
    ],
  );
}
