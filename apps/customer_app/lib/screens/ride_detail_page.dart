import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

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
        setState(() { _fullData = r['data']['ride']; _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) {
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
    final status = r['status'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
        // Map
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(options: MapOptions(center: LatLng(pickupLat, pickupLng), zoom: 13), children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.vybe.customer'),
              MarkerLayer(markers: [
                Marker(point: LatLng(pickupLat, pickupLng), width: 30, height: 30, child: const Icon(Icons.location_on, color: Colors.green, size: 28)),
                Marker(point: LatLng(dropLat, dropLng), width: 30, height: 30, child: const Icon(Icons.location_on, color: Colors.red, size: 28)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Ride info card
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Ride #${r['ride_number'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Chip(label: Text(status), backgroundColor: status == 'completed' ? const Color(0xFF4CAF50).withOpacity(0.2) : const Color(0xFFFFA726).withOpacity(0.2)),
          ]),
          const Divider(height: 20),
          Row(children: [const Icon(Icons.circle, color: Colors.green, size: 12), const SizedBox(width: 8), Expanded(child: Text(r['pickup_address'] ?? 'Pickup', style: const TextStyle(fontSize: 14)))]),
          const SizedBox(height: 4),
          Row(children: [const SizedBox(width: 6), Column(children: List.generate(2, (_) => Container(width: 2, height: 3, margin: const EdgeInsets.symmetric(vertical: 1), color: Colors.grey.shade400)))]),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 14), const SizedBox(width: 7), Expanded(child: Text(r['drop_address'] ?? 'Drop', style: const TextStyle(fontSize: 14)))]),
        ]))),
        const SizedBox(height: 12),

        // Fare breakdown
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text('Fare Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(height: 16),
          _fr('Base Fare', '₹${r['base_fare'] ?? '0'}'),
          _fr('Distance', '₹${r['distance_fare'] ?? '0'}'),
          _fr('Time', '₹${r['time_fare'] ?? '0'}'),
          if ((r['night_charges'] ?? 0) > 0) _fr('Night Charges', '₹${r['night_charges']}'),
          if ((r['peak_charges'] ?? 0) > 0) _fr('Peak Charges', '₹${r['peak_charges']}'),
          if ((r['promo_discount'] ?? 0) > 0) _fr('Discount', '-₹${r['promo_discount']}', color: Colors.green),
          const Divider(height: 12),
          _fr('Total', '₹$fare', bold: true),
        ]))),
        const SizedBox(height: 12),

        // Driver info
        if (driver != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Driver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(height: 12),
          Row(children: [const Icon(Icons.person, size: 20), const SizedBox(width: 8), Text(driverName, style: const TextStyle(fontSize: 15))]),
          if (driverPhone.isNotEmpty) ...[const SizedBox(height: 4), Row(children: [const Icon(Icons.phone, size: 20), const SizedBox(width: 8), Text(driverPhone)]),
            IconButton(icon: const Icon(Icons.call, color: Colors.green, size: 20), onPressed: () async {
              if (driverPhone.isNotEmpty) await launchUrl(Uri.parse('tel:$driverPhone'));
            })],
          if (vehicle != null) ...[const SizedBox(height: 4), Row(children: [const Icon(Icons.directions_car, size: 20), const SizedBox(width: 8), Text('${vehicle['vehicle_number'] ?? ''} - ${vehicle['vehicle_model'] ?? ''}')])],
        ]))),
      ]),
    );
  }

  Widget _fr(String l, String v, {bool bold = false, Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: TextStyle(color: color ?? const Color(0xFF9CA3AF), fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
    Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color, fontSize: 14)),
  ]));
}
