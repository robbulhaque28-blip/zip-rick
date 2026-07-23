import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'ride_tracking_page.dart';

final ApiService _api = ApiService();

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  final MapController _mapCtrl = MapController();
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  LatLng? _currentLoc;
  LatLng? _pickupLoc, _dropLoc;
  bool _loading = true, _isBooking = false, _locationDone = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _appliedPromo;
  int _discount = 0;
  String _rideMode = 'single';
  DateTime? _scheduledTime;
  List<Map<String, dynamic>> _savedPlaces = [];

  @override
  void initState() { super.initState(); _loadSavedPlaces(); _getLocation(); }
  @override void dispose() { _pickupCtrl.dispose(); _dropCtrl.dispose(); _promoCtrl.dispose(); super.dispose(); }

  Future<void> _loadSavedPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('saved_places');
    if (data != null) setState(() => _savedPlaces = List<Map<String, dynamic>>.from(jsonDecode(data)));
  }

  Future<void> _savePlace(String name, LatLng loc) async {
    _savedPlaces.add({'name': name, 'lat': loc.latitude, 'lon': loc.longitude});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_places', jsonEncode(_savedPlaces));
    setState(() {});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name saved!")));
  }

  Future<void> _getLocation() async {
    try {
      if (await Geolocator.requestPermission() == LocationPermission.whileInUse || await Geolocator.checkPermission() == LocationPermission.always) {
        // First try last known position (instant)
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && !_locationDone) {
          final ll = LatLng(lastPos.latitude, lastPos.longitude);
          setState(() { _currentLoc = ll; _pickupLoc = ll; _pickupCtrl.text = "Current Location"; _loading = false; _locationDone = true; });
          _mapCtrl.move(ll, 15);
        }
        // Then get precise GPS location (might take a few seconds)
        final precisePos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (precisePos != null && mounted) {
          final ll = LatLng(precisePos.latitude, precisePos.longitude);
          setState(() { _currentLoc = ll; _pickupLoc = ll; _pickupCtrl.text = "Current Location"; _loading = false; _locationDone = true; });
          _mapCtrl.move(ll, 15);
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!_locationDone) setState(() => _loading = false);
    }
  }

  Future<void> _searchPlaces(String q, bool isPickup) async {
    if (q.length < 3) { setState(() => _searchResults = []); return; }
    try {
      final r = await http.get(Uri.parse("https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=5&countrycodes=in"), headers: {"User-Agent": "Vybe/1.0"});
      if (r.statusCode == 200) {
        final List d = jsonDecode(r.body);
        setState(() { _searchResults = d.map((e) => {"display_name": e["display_name"] ?? "", "lat": double.parse(e["lat"] ?? "0"), "lon": double.parse(e["lon"] ?? "0"), "isPickup": isPickup}).toList(); });
      }
    } catch (_) {}
  }

  void _selectPlace(Map<String, dynamic> p) {
    final ll = LatLng(p["lat"], p["lon"]);
    setState(() {
      if (p["isPickup"] == true) { _pickupLoc = ll; _pickupCtrl.text = p["display_name"].toString(); }
      else { _dropLoc = ll; _dropCtrl.text = p["display_name"].toString(); }
      _searchResults = [];
    });
    _mapCtrl.move(ll, 15);
  }

  bool _bookingInProgress = false;

  void _showBookingPanel() {
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setSheet) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text("Where to?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Saved places chips
              if (_savedPlaces.isNotEmpty) ...[
                SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
                  ..._savedPlaces.map((p) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(
                    avatar: const Icon(Icons.favorite, size: 16, color: Color(0xFF6C63FF)),
                    label: Text(p['name'] ?? '', style: const TextStyle(fontSize: 12)),
                    onPressed: () { _pickupLoc = LatLng(p['lat'], p['lon']); _pickupCtrl.text = p['name']; setSheet(() {}); },
                  ))),
                ])),
                const SizedBox(height: 12),
              ],
              Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Column(children: [
                  TextField(controller: _pickupCtrl, decoration: InputDecoration(labelText: "Pickup", prefixIcon: const Icon(Icons.circle, color: Colors.green, size: 12), border: InputBorder.none, contentPadding: const EdgeInsets.all(16), suffixIcon: IconButton(icon: const Icon(Icons.favorite_border, size: 18), onPressed: () { if (_pickupLoc != null) { showDialog(context: context, builder: (dCtx) { final nCtrl = TextEditingController(); return AlertDialog(title: const Text("Save Place"), content: TextField(controller: nCtrl, decoration: const InputDecoration(labelText: "Name (e.g. Home)")), actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancel")), ElevatedButton(onPressed: () { if (nCtrl.text.isNotEmpty) { _savePlace(nCtrl.text, _pickupLoc!); Navigator.pop(dCtx); } }, child: const Text("Save"))]); }); } })),
                    onChanged: (v) => _searchPlaces(v, true)),
                  ..._searchResults.where((p) => p["isPickup"] == true).take(3).map((p) => ListTile(dense: true, leading: const Icon(Icons.location_on, size: 16), title: Text(p["display_name"].toString(), style: const TextStyle(fontSize: 13)), onTap: () { _selectPlace(p); setSheet(() {}); })),
                  const Divider(height: 1),
                  TextField(controller: _dropCtrl, decoration: InputDecoration(labelText: "Drop", prefixIcon: const Icon(Icons.location_on, color: Colors.red, size: 12), border: InputBorder.none, contentPadding: const EdgeInsets.all(16)), onChanged: (v) => _searchPlaces(v, false)),
                  ..._searchResults.where((p) => p["isPickup"] == false).take(3).map((p) => ListTile(dense: true, leading: const Icon(Icons.location_on, size: 16), title: Text(p["display_name"].toString(), style: const TextStyle(fontSize: 13)), onTap: () { _selectPlace(p); setSheet(() {}); })),
                ])),
              // Ride mode selector
              Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setSheet(() => _rideMode = 'single'),
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(
                      color: _rideMode == 'single' ? const Color(0xFF6C63FF) : Colors.grey.shade100,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8))),
                      child: Text('Single', textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: _rideMode == 'single' ? Colors.white : Colors.black87, fontSize: 14)),
                    ),
                  )),
                  Expanded(child: GestureDetector(
                    onTap: () => setSheet(() => _rideMode = 'sharing'),
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(
                      color: _rideMode == 'sharing' ? const Color(0xFF00D9A6) : Colors.grey.shade100,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8))),
                      child: Text('Sharing', textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: _rideMode == 'sharing' ? Colors.white : Colors.black87, fontSize: 14)),
                    ),
                  )),
                ]),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
                onPressed: _pickupLoc == null || _dropLoc == null ? null : () { Navigator.pop(ctx); _getFare(); },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("Search for Ride", style: TextStyle(fontSize: 16)))),
          ])),
        );
      })),
  }

  Future<void> _getFare() async {
    if (_bookingInProgress) return;
    _bookingInProgress = true;
    if (_pickupLoc == null || _dropLoc == null) return;
    setState(() => _isBooking = true);
    try {
      final r = await _api.getFareEstimate(_pickupLoc!.latitude, _pickupLoc!.longitude, _dropLoc!.latitude, _dropLoc!.longitude, rideMode: _rideMode);
      if (r["success"]) { setState(() => _isBooking = false); _bookingInProgress = false; _showPayment((r["data"]?["total_fare"] ?? 30).toInt(), r["data"]); }
      else { setState(() => _isBooking = false); _bookingInProgress = false; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r["error"]?["message"] ?? "Error"))); }
    } catch (e) { setState(() => _isBooking = false); _bookingInProgress = false; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection error"))); }
  }

  void _showPayment(int amount, Map<String, dynamic>? fare) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Your Trip", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx), visualDensity: VisualDensity.compact)]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Row(children: [const Icon(Icons.circle, color: Colors.green, size: 10), const SizedBox(width: 12), Expanded(child: Text(_pickupCtrl.text, style: const TextStyle(fontSize: 14)))]),
            const SizedBox(height: 4), Row(children: [const SizedBox(width: 5), Column(children: List.generate(3, (_) => Container(width: 2, height: 3, margin: const EdgeInsets.symmetric(vertical: 1), color: Colors.grey.shade400)))]),
            const SizedBox(height: 4), Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 14), const SizedBox(width: 10), Expanded(child: Text(_dropCtrl.text, style: const TextStyle(fontSize: 14)))]),
          ])),
        const SizedBox(height: 16),
        if (fare != null) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _fr("Base fare", "₹${fare['base_fare']?.toStringAsFixed(0) ?? '30'}"),
            const Divider(height: 12), _fr("Distance", "₹${fare['distance_fare']?.toStringAsFixed(0) ?? '0'}"),
            const Divider(height: 12), _fr("Time", "₹${fare['time_fare']?.toStringAsFixed(0) ?? '0'}"),
            if ((fare['night_charges'] ?? 0) > 0) ...[const Divider(height: 12), _fr("Night charges", "₹${fare['night_charges']?.toStringAsFixed(0)}")],
            if ((fare['peak_charges'] ?? 0) > 0) ...[const Divider(height: 12), _fr("Peak charges", "₹${fare['peak_charges']?.toStringAsFixed(0)}")],
            if (_discount > 0) ...[const Divider(height: 12), _fr("Discount", "-₹$_discount", color: Colors.green)],
            const Divider(height: 12), _fr("Total", "₹${amount - _discount}", bold: true),
          ])),
        const SizedBox(height: 12),
        // Schedule ride toggle
        Container(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setModal(() { _scheduledTime = null; }),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(
                color: _scheduledTime == null ? const Color(0xFF6C63FF) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10)),
                child: Text('Now', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: _scheduledTime == null ? Colors.white : Colors.black87, fontSize: 14)),
              ),
            )),
            Expanded(child: GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                final pickedDate = await showDatePicker(context: context, initialDate: now.add(const Duration(hours: 1)), firstDate: now, lastDate: now.add(const Duration(hours: 24)));
                if (pickedDate != null && ctx.mounted) {
                  final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
                  if (pickedTime != null) {
                    final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                    setModal(() { _scheduledTime = dt; });
                  }
                }
              },
              child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(
                color: _scheduledTime != null ? const Color(0xFF00D9A6) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10)),
                child: Text('Schedule', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: _scheduledTime != null ? Colors.white : Colors.black87, fontSize: 14)),
              ),
            )),
          ])),
        if (_scheduledTime != null) Padding(padding: const EdgeInsets.only(top: 8, left: 4), child: Text('Scheduled for: ${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')} on ${_scheduledTime!.day}/${_scheduledTime!.month}', style: const TextStyle(fontSize: 13, color: Color(0xFF00D9A6), fontWeight: FontWeight.w500))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _promoCtrl, decoration: InputDecoration(labelText: "Promo", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: () {
            final code = _promoCtrl.text.trim().toUpperCase();
            if (code == "ZIP50") { setModal(() { _discount = (amount * 0.5).toInt(); _appliedPromo = code; }); }
            else if (code == "ZIP20") { setModal(() { _discount = 20; _appliedPromo = code; }); }
            else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid code"))); }
          }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)), child: const Text("Apply")),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: SizedBox(height: 52, child: ElevatedButton(onPressed: () { Navigator.pop(ctx); _bookRide("cash"); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Cash")))),
          const SizedBox(width: 12),
          Expanded(child: SizedBox(height: 52, child: ElevatedButton(onPressed: () { Navigator.pop(ctx); _bookRide("upi"); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("UPI")))),
        ]),
      ]))));
  }

  Widget _fr(String l, String v, {bool bold = false, Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: TextStyle(color: color ?? const Color(0xFF9CA3AF), fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
    Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color, fontSize: 14)),
  ]));

  Future<void> _bookRide(String pm) async {
    if (_pickupLoc == null || _dropLoc == null) return;
    setState(() => _isBooking = true);
    try {
      final scheduledStr = _scheduledTime?.toIso8601String();
      final r = await _api.bookRide(_pickupLoc!.latitude, _pickupLoc!.longitude, _pickupCtrl.text, _dropLoc!.latitude, _dropLoc!.longitude, _dropCtrl.text, pm, _appliedPromo ?? "", rideMode: _rideMode, scheduledAt: scheduledStr);
      if (r["success"]) { if (!mounted) return; Navigator.push(context, MaterialPageRoute(builder: (_) => RideTrackingPage(rideData: r["data"]["ride"]))); }
      else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r["error"]?["message"] ?? "Booking failed"))); }
    } catch (_) {}
    setState(() => _isBooking = false);
  }

  void _sos() {
    showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.warning_rounded, color: Colors.red, size: 28), SizedBox(width: 8), Text("SOS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
      content: const Text("Alert our support team?"), actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async { Navigator.pop(ctx); try { await _api.sos(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS sent!"))); } catch (_) {} },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Send SOS")),
      ],
    ));
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Vybe", style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent, elevation: 0,
      actions: [
        Container(margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.headset_mic, color: Color(0xFF6C63FF)), onPressed: () => Navigator.pushNamed(context, '/support'))),
        Container(margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.warning_rounded, color: Colors.red), onPressed: _sos)),
      ]),
    body: Stack(children: [
      _loading
        ? const Center(child: CircularProgressIndicator())
        : FlutterMap(mapController: _mapCtrl, options: MapOptions(center: _currentLoc ?? const LatLng(0, 0), zoom: 15, onLongPress: (tapPos, latlng) {
            setState(() { if (_dropLoc == null) { _dropLoc = latlng; _dropCtrl.text = "Pinned"; } else { _pickupLoc = latlng; _pickupCtrl.text = "Pinned"; _dropLoc = null; _dropCtrl.clear(); } });
          }), children: [
            TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.vybe.customer"),
            MarkerLayer(markers: [
              if (_pickupLoc != null) Marker(point: _pickupLoc!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 35)),
              if (_dropLoc != null) Marker(point: _dropLoc!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 35)),
            ]),
          ]),
      Positioned(left: 16, right: 16, top: MediaQuery.of(context).padding.top + 8,
        child: GestureDetector(onTap: _showBookingPanel,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))]),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.search, color: Color(0xFF6C63FF))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_pickupCtrl.text.isNotEmpty ? _pickupCtrl.text : "Current Location", style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 2),
                Text(_dropCtrl.text.isNotEmpty ? _dropCtrl.text : "Where to?", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _dropCtrl.text.isNotEmpty ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF))),
              ])),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9CA3AF)),
            ]),
          ),
        ),
      ),
      Positioned(right: 16, bottom: 30, child: FloatingActionButton(mini: true, onPressed: _getLocation, backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Color(0xFF6C63FF)))),
    ]),
  );
}
