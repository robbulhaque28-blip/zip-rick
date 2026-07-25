import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

final ApiService _api = ApiService();

class RideDetailPage extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RideDetailPage({super.key, required this.ride});
  @override State<RideDetailPage> createState() => _RideDetailPageState();
}

class _RideDetailPageState extends State<RideDetailPage> {
  Map<String, dynamic>? _fullData;
  bool _loading = true;

  @override void initState() { super.initState(); _loadDetail(); }

  Future<void> _loadDetail() async {
    try {
      final r = await _api.getRideDetail(widget.ride['id']);
      if (r['success'] && r['data']?['ride'] != null) {
        if (mounted) setState(() { _fullData = r['data']['ride']; _loading = false; });
      } else { if (mounted) setState(() => _loading = false); }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.danger;
      default: return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _fullData ?? widget.ride;
    final pickupLat = double.tryParse('${r['pickup_latitude'] ?? '0'}') ?? 0;
    final pickupLng = double.tryParse('${r['pickup_longitude'] ?? '0'}') ?? 0;
    final dropLat = double.tryParse('${r['drop_latitude'] ?? '0'}') ?? 0;
    final dropLng = double.tryParse('${r['drop_longitude'] ?? '0'}') ?? 0;
    final driver = r['driver'];
    final driverName = driver?['user']?['full_name'] ?? 'N/A';
    final driverPhone = driver?['user']?['phone'] ?? '';
    final vehicle = driver?['vehicle'];
    final fare = r['total_fare']?.toString() ?? '0';
    final status = (r['status'] ?? '').toString();
    final hasRoute = pickupLat != 0 && dropLat != 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
            VybeFadeIn(child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(height: 190, child: Stack(children: [
                FlutterMap(
                  options: MapOptions(center: LatLng(pickupLat, pickupLng), zoom: 13),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.vybe.customer'),
                    if (hasRoute) PolylineLayer(polylines: [
                      Polyline(points: [LatLng(pickupLat, pickupLng), LatLng(dropLat, dropLng)], strokeWidth: 3.5, color: AppColors.primary.withOpacity(0.75)),
                    ]),
                    MarkerLayer(markers: [
                      Marker(point: LatLng(pickupLat, pickupLng), width: 20, height: 20, child: Container(
                        decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)))),
                      if (hasRoute) Marker(point: LatLng(dropLat, dropLng), width: 20, height: 20, child: Container(
                        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 3)))),
                    ]),
                  ],
                ),
                Positioned(top: 11, left: 11, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9), boxShadow: AppShadow.soft),
                  child: Text('#${r['ride_number'] ?? ''}', style: AppText.bodyStrong.copyWith(fontSize: 12)),
                )),
              ])),
            )),
            const SizedBox(height: 14),
            VybeFadeIn(delayMs: 60, child: VybeCard(child: Column(children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TOTAL FARE', style: AppText.tiny),
                  const SizedBox(height: 4),
                  Text('₹$fare', style: AppText.h1.copyWith(fontSize: 27)),
                ])),
                VybeBadge(text: status.replaceAll('_', ' '), color: _statusColor(status)),
              ]),
              const SizedBox(height: 15),
              VybeRouteCard(from: r['pickup_address'] ?? 'Pickup', to: r['drop_address'] ?? 'Drop'),
            ]))),
            const SizedBox(height: 14),
            VybeFadeIn(delayMs: 110, child: VybeCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('FARE BREAKDOWN', style: AppText.tiny),
              const SizedBox(height: 13),
              _fr('Base fare', '₹${r['base_fare'] ?? '0'}'),
              _fr('Distance', '₹${r['distance_fare'] ?? '0'}'),
              _fr('Time', '₹${r['time_fare'] ?? '0'}'),
              if ((r['night_charges'] ?? 0) > 0) _fr('Night charges', '₹${r['night_charges']}'),
              if ((r['peak_charges'] ?? 0) > 0) _fr('Peak charges', '₹${r['peak_charges']}'),
              if ((r['promo_discount'] ?? 0) > 0) _fr('Discount', '-₹${r['promo_discount']}', color: AppColors.success),
              const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Divider(height: 1)),
              _fr('Total', '₹$fare', bold: true),
            ]))),
            if (driver != null) ...[
              const SizedBox(height: 14),
              VybeFadeIn(delayMs: 160, child: VybeCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DRIVER', style: AppText.tiny),
                const SizedBox(height: 13),
                Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(
                      driverName.toString().trim().isEmpty ? 'D' : driverName.toString().trim()[0].toUpperCase(),
                      style: AppText.h3.copyWith(color: AppColors.primary))),
                  ),
                  const SizedBox(width: 13),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(driverName, style: AppText.bodyStrong.copyWith(fontSize: 14.5)),
                    if (vehicle != null) ...[
                      const SizedBox(height: 3),
                      Text('${vehicle['vehicle_number'] ?? ''}  ·  ${vehicle['vehicle_model'] ?? ''}', style: AppText.label.copyWith(fontSize: 11.5)),
                    ],
                  ])),
                  if (driverPhone.toString().isNotEmpty) IconButton(
                    onPressed: () async { await launchUrl(Uri.parse('tel:$driverPhone')); },
                    icon: const Icon(Icons.call_rounded, size: 18, color: AppColors.success),
                    style: IconButton.styleFrom(backgroundColor: AppColors.success.withOpacity(0.10)),
                  ),
                ]),
              ]))),
            ],
          ]),
    );
  }

  Widget _fr(String l, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: bold ? AppText.bodyStrong.copyWith(fontSize: 14) : AppText.body.copyWith(fontSize: 13.5)),
      Text(v, style: bold
        ? AppText.price.copyWith(fontSize: 17)
        : AppText.bodyStrong.copyWith(fontSize: 13.5, color: color ?? AppColors.ink)),
    ]),
  );
}
