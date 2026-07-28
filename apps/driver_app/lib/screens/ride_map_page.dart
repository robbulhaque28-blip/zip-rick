import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

/// Full-screen navigation map for the driver.
///
/// Shows the driver's live position, the pickup point and the drop point,
/// with a straight route line and a live distance/ETA readout. Opens from
/// the active ride screen so the driver can see where the customer is going.
class RideMapPage extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RideMapPage({super.key, required this.ride});

  @override
  State<RideMapPage> createState() => _RideMapPageState();
}

class _RideMapPageState extends State<RideMapPage> {
  final MapController _map = MapController();
  StreamSubscription<Position>? _posSub;
  Timer? _rideTimer;
  LatLng? _me;
  bool _followMe = true;
  bool _ready = false;

  /// Live copy of the ride.
  ///
  /// The page used to read widget.ride, which is a frozen snapshot taken when
  /// the map opened. If the driver marked arrival or started the trip while
  /// the map was still on screen, the status never changed here - so the map
  /// kept navigating to the PICKUP even after the ride had started and the
  /// driver should have been heading to the DROP.
  late Map<String, dynamic> _ride = Map<String, dynamic>.from(widget.ride);

  @override
  void initState() {
    super.initState();
    _start();
    // Keep the ride fresh so the map re-targets from pickup to drop the
    // moment the trip actually starts.
    _refreshRide();
    _rideTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshRide());
  }

  Future<void> _refreshRide() async {
    try {
      final r = await ApiService.getActiveRide();
      final live = r['data']?['ride'];
      if (!mounted || live == null) return;
      // Only accept updates for the ride this map was opened for.
      if (live['id']?.toString() != _ride['id']?.toString()) return;
      setState(() => _ride = Map<String, dynamic>.from(live));
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _rideTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && last.accuracy <= 100 && mounted) {
        setState(() => _me = LatLng(last.latitude, last.longitude));
      }
    } catch (_) {}

    try {
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((p) {
        if (!mounted) return;
        final here = LatLng(p.latitude, p.longitude);
        setState(() => _me = here);
        if (_followMe) {
          try {
            _map.move(here, _map.camera.zoom);
          } catch (_) {}
        }
      });
    } catch (_) {}

    if (mounted) {
      setState(() => _ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
    }
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  LatLng? get _pickup {
    final la = _num(_ride['pickup_latitude']);
    final lo = _num(_ride['pickup_longitude']);
    if (la == null || lo == null) return null;
    return LatLng(la, lo);
  }

  LatLng? get _drop {
    final la = _num(_ride['drop_latitude']);
    final lo = _num(_ride['drop_longitude']);
    if (la == null || lo == null) return null;
    return LatLng(la, lo);
  }

  /// The point the driver is currently heading towards.
  LatLng? get _target {
    final status = (_ride['status'] ?? '').toString();
    if (status == 'started') return _drop ?? _pickup;
    return _pickup ?? _drop;
  }

  bool get _goingToDrop => (_ride['status'] ?? '').toString() == 'started';

  double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  void _fitAll() {
    final pts = <LatLng>[];
    if (_me != null) pts.add(_me!);
    if (_pickup != null) pts.add(_pickup!);
    if (_drop != null) pts.add(_drop!);
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      try {
        _map.move(pts.first, 15);
      } catch (_) {}
      return;
    }
    double minLa = pts.first.latitude, maxLa = pts.first.latitude;
    double minLo = pts.first.longitude, maxLo = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLa) minLa = p.latitude;
      if (p.latitude > maxLa) maxLa = p.latitude;
      if (p.longitude < minLo) minLo = p.longitude;
      if (p.longitude > maxLo) maxLo = p.longitude;
    }
    try {
      _map.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLa, minLo), LatLng(maxLa, maxLo)),
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 260),
      ));
      setState(() => _followMe = false);
    } catch (_) {}
  }

  Future<void> _openExternal() async {
    final t = _target;
    if (t == null) return;
    final uri = Uri.parse(
        'google.navigation:q=${t.latitude},${t.longitude}&mode=d');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    final web = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${t.latitude},${t.longitude}&travelmode=driving');
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Maps')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _pickup;
    final drop = _drop;
    final target = _target;

    final center = _me ?? target ?? pickup ?? const LatLng(25.8433, 93.4325);

    double? km;
    if (_me != null && target != null) km = _distanceKm(_me!, target);
    final mins = km == null ? null : math.max(1, (km / 22.0 * 60).round());

    final line = <LatLng>[];
    if (_me != null) line.add(_me!);
    if (_goingToDrop) {
      if (drop != null) line.add(drop);
    } else {
      if (pickup != null) line.add(pickup);
      if (drop != null) line.add(drop);
    }

    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            center: center,
            zoom: 14.5,
            onPositionChanged: (pos, hasGesture) {
              if (hasGesture && _followMe) {
                setState(() => _followMe = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.vybe.driver',
            ),
            if (line.length >= 2)
              PolylineLayer(polylines: [
                Polyline(
                  points: line,
                  strokeWidth: 4.5,
                  color: AppColors.primary.withOpacity(0.75),
                ),
              ]),
            MarkerLayer(markers: [
              if (pickup != null)
                Marker(
                  point: pickup,
                  width: 130,
                  height: 58,
                  child: _Pin(
                    label: 'Pickup',
                    color: AppColors.accent,
                    icon: Icons.person_pin_circle_rounded,
                    dim: _goingToDrop,
                  ),
                ),
              if (drop != null)
                Marker(
                  point: drop,
                  width: 130,
                  height: 58,
                  child: _Pin(
                    label: 'Drop',
                    color: AppColors.danger,
                    icon: Icons.flag_rounded,
                    dim: false,
                  ),
                ),
              if (_me != null)
                Marker(
                  point: _me!,
                  width: 46,
                  height: 46,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(7),
                    child: Container(
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.electric_rickshaw_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ]),
          ],
        ),

        // Top bar
        Positioned(
          left: 14,
          right: 14,
          top: MediaQuery.of(context).padding.top + 10,
          child: Row(children: [
            _RoundBtn(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadow.card,
                ),
                child: Row(children: [
                  Icon(
                      _goingToDrop
                          ? Icons.flag_rounded
                          : Icons.person_pin_circle_rounded,
                      size: 17,
                      color: _goingToDrop
                          ? AppColors.danger
                          : AppColors.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _goingToDrop ? 'Going to drop' : 'Going to pickup',
                      style: AppText.bodyStrong.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),

        // Recentre / fit buttons
        Positioned(
          right: 14,
          bottom: 250,
          child: Column(children: [
            _RoundBtn(
              icon: _followMe
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              onTap: () {
                if (_me == null) return;
                setState(() => _followMe = true);
                try {
                  _map.move(_me!, 16);
                } catch (_) {}
              },
            ),
            const SizedBox(height: 9),
            _RoundBtn(icon: Icons.zoom_out_map_rounded, onTap: _fitAll),
          ]),
        ),

        // Bottom sheet
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.ink.withOpacity(0.14),
                    blurRadius: 26,
                    offset: const Offset(0, -6)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.navigation_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            km == null
                                ? 'Locating...'
                                : '${km.toStringAsFixed(1)} km away',
                            style: AppText.h3.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mins == null
                                ? 'Waiting for GPS'
                                : 'About $mins min by e-rickshaw',
                            style: AppText.label.copyWith(fontSize: 12),
                          ),
                        ]),
                  ),
                  if (!_ready)
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2)),
                ]),
                const SizedBox(height: 14),
                VybeRouteCard(
                  from: (_ride['pickup_address'] ?? 'Pickup').toString(),
                  to: (_ride['drop_address'] ?? 'Drop').toString(),
                ),
                const SizedBox(height: 14),
                VybeButton(
                  label: 'Open in Google Maps',
                  icon: Icons.assistant_navigation,
                  onPressed: _openExternal,
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Pin extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool dim;
  const _Pin(
      {required this.label,
      required this.color,
      required this.icon,
      required this.dim});

  @override
  Widget build(BuildContext context) {
    final o = dim ? 0.45 : 1.0;
    return Opacity(
      opacity: o,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            boxShadow: AppShadow.soft,
          ),
          child: Text(label,
              style: AppText.tiny.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 3),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: AppShadow.soft,
          ),
          child: Icon(icon, size: 13, color: Colors.white),
        ),
      ]),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: AppShadow.card,
          ),
          child: Icon(icon, size: 19, color: AppColors.ink),
        ),
      );
}
