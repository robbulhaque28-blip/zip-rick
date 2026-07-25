import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
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
  bool _bookingInProgress = false;
  bool _pinMode = false;

  @override
  void initState() { super.initState(); _loadSavedPlaces(); _getLocation(); }
  @override
  void dispose() { _pickupCtrl.dispose(); _dropCtrl.dispose(); _promoCtrl.dispose(); super.dispose(); }

  Future<void> _loadSavedPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('saved_places');
    if (data != null && mounted) setState(() => _savedPlaces = List<Map<String, dynamic>>.from(jsonDecode(data)));
  }

  Future<void> _savePlace(String name, LatLng loc) async {
    _savedPlaces.add({'name': name, 'lat': loc.latitude, 'lon': loc.longitude});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_places', jsonEncode(_savedPlaces));
    if (mounted) setState(() {});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name saved")));
  }

  Future<void> _getLocation() async {
    try {
      if (await Geolocator.requestPermission() == LocationPermission.whileInUse || await Geolocator.checkPermission() == LocationPermission.always) {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && !_locationDone && mounted) {
          final ll = LatLng(lastPos.latitude, lastPos.longitude);
          setState(() { _currentLoc = ll; _pickupLoc = ll; _pickupCtrl.text = "Current Location"; _loading = false; _locationDone = true; });
          _mapCtrl.move(ll, 15);
        }
        final precisePos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          final ll = LatLng(precisePos.latitude, precisePos.longitude);
          setState(() { _currentLoc = ll; _pickupLoc = ll; _pickupCtrl.text = "Current Location"; _loading = false; _locationDone = true; });
          _mapCtrl.move(ll, 15);
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (!_locationDone && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchPlaces(String q, bool isPickup) async {
    if (q.length < 3) { setState(() => _searchResults = []); return; }
    try {
      final r = await http.get(
        Uri.parse("https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=5&countrycodes=in"),
        headers: {"User-Agent": "Vybe/1.0"});
      if (r.statusCode == 200 && mounted) {
        final List d = jsonDecode(r.body);
        setState(() {
          _searchResults = d.map((e) => {
            "display_name": e["display_name"] ?? "",
            "lat": double.parse(e["lat"] ?? "0"),
            "lon": double.parse(e["lon"] ?? "0"),
            "isPickup": isPickup,
          }).toList();
        });
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

  void _showBookingPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 9, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 34, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 17),
            Text("Where to?", style: AppText.h2),
            const SizedBox(height: 15),
            if (_savedPlaces.isNotEmpty) ...[
              SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: [
                ..._savedPlaces.map((p) => Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                  onTap: () { _pickupLoc = LatLng(p['lat'], p['lon']); _pickupCtrl.text = p['name']; setSheet(() {}); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
                    child: Row(children: [
                      const Icon(Icons.bookmark_rounded, size: 13, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(p['name'] ?? '', style: AppText.label.copyWith(fontSize: 12, color: AppColors.body, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ))),
              ])),
              const SizedBox(height: 13),
            ],
            Container(
              decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
              child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(14, 12, 8, 8), child: Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: _pickupCtrl,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                    decoration: InputDecoration(
                      isDense: true, filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero, hintText: "Pickup location", hintStyle: AppText.label,
                    ),
                    onChanged: (v) => _searchPlaces(v, true),
                  )),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 17, color: AppColors.muted),
                    onPressed: () {
                      if (_pickupLoc == null) return;
                      showDialog(context: context, builder: (dCtx) {
                        final nCtrl = TextEditingController();
                        return AlertDialog(
                          title: const Text("Save place"),
                          content: TextField(controller: nCtrl, autofocus: true, decoration: const InputDecoration(hintText: "e.g. Home")),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancel")),
                            ElevatedButton(onPressed: () {
                              if (nCtrl.text.isNotEmpty) { _savePlace(nCtrl.text, _pickupLoc!); Navigator.pop(dCtx); }
                            }, child: const Text("Save")),
                          ],
                        );
                      });
                    },
                  ),
                ])),
                ..._searchResults.where((p) => p["isPickup"] == true).take(3).map((p) => _suggestion(p, setSheet)),
                const Divider(height: 1, indent: 14, endIndent: 14),
                Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: _dropCtrl,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                    decoration: InputDecoration(
                      isDense: true, filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero, hintText: "Where are you going?", hintStyle: AppText.label,
                    ),
                    onChanged: (v) => _searchPlaces(v, false),
                  )),
                ])),
                ..._searchResults.where((p) => p["isPickup"] == false).take(3).map((p) => _suggestion(p, setSheet)),
              ]),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _pinMode = true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Tap anywhere on the map to set your drop location"), duration: Duration(seconds: 5)));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.line, style: BorderStyle.solid),
                  color: AppColors.canvas,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_location_alt_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text("Pin drop location on map", style: AppText.label.copyWith(fontSize: 12.5, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 17),
            Text("RIDE TYPE", style: AppText.tiny),
            const SizedBox(height: 9),
            VybeRideOption(
              icon: Icons.electric_rickshaw_rounded,
              title: "Single",
              subtitle: "Private ride, direct route",
              price: "",
              selected: _rideMode == 'single',
              onTap: () => setSheet(() => _rideMode = 'single'),
            ),
            const SizedBox(height: 8),
            VybeRideOption(
              icon: Icons.groups_rounded,
              title: "Sharing",
              subtitle: "Shared ride, lower fare",
              price: "",
              selected: _rideMode == 'sharing',
              onTap: () => setSheet(() => _rideMode = 'sharing'),
            ),
            const SizedBox(height: 18),
            VybeButton(
              label: "Search for ride",
              icon: Icons.search_rounded,
              onPressed: () {
                if (_pickupLoc == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Pickup location not set. Tap the location button or search for a pickup point."), duration: Duration(seconds: 5)));
                  return;
                }
                if (_dropLoc == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Please choose a drop location first."), duration: Duration(seconds: 4)));
                  return;
                }
                Navigator.pop(ctx);
                _getFare();
              },
            ),
          ]),
        ),
      )),
    );
  }

  Widget _suggestion(Map<String, dynamic> p, StateSetter setSheet) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () { _selectPlace(p); setSheet(() {}); },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        child: Row(children: [
          const Icon(Icons.location_on_outlined, size: 15, color: AppColors.muted),
          const SizedBox(width: 11),
          Expanded(child: Text(p["display_name"].toString(), style: AppText.body.copyWith(fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    ),
  );

  Future<void> _getFare() async {
    if (_bookingInProgress) return;
    if (_pickupLoc == null || _dropLoc == null) return;
    _bookingInProgress = true;
    setState(() => _isBooking = true);
    try {
      final r = await _api.getFareEstimate(_pickupLoc!.latitude, _pickupLoc!.longitude, _dropLoc!.latitude, _dropLoc!.longitude, rideMode: _rideMode);
      if (!mounted) return;
      if (r["success"] == true) {
        _showPayment((r["data"]?["total_fare"] ?? 30).toInt(), r["data"]);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r["error"]?["message"] ?? "Could not get fare")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Could not reach server. Check your connection and try again."), duration: Duration(seconds: 4)));
    } finally {
      _bookingInProgress = false;
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showPayment(int amount, Map<String, dynamic>? fare) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 9, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 34, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 17),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Confirm your trip", style: AppText.h2),
                const SizedBox(height: 3),
                Text(_rideMode == 'sharing' ? "Shared ride" : "Private ride", style: AppText.label),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text("₹${amount - _discount}", style: AppText.h1.copyWith(fontSize: 26)),
                if (_discount > 0) Text("₹$amount", style: AppText.label.copyWith(fontSize: 12, decoration: TextDecoration.lineThrough)),
              ]),
            ]),
            const SizedBox(height: 16),
            VybeRouteCard(from: _pickupCtrl.text, to: _dropCtrl.text),
            const SizedBox(height: 13),
            if (fare != null) VybeCard(
              bordered: true,
              padding: const EdgeInsets.all(15),
              child: Column(children: [
                _fr("Base fare", "₹${fare['base_fare']?.toStringAsFixed(0) ?? '30'}"),
                _fr("Distance", "₹${fare['distance_fare']?.toStringAsFixed(0) ?? '0'}"),
                _fr("Time", "₹${fare['time_fare']?.toStringAsFixed(0) ?? '0'}"),
                if ((fare['night_charges'] ?? 0) > 0) _fr("Night charges", "₹${fare['night_charges']?.toStringAsFixed(0)}"),
                if ((fare['peak_charges'] ?? 0) > 0) _fr("Peak charges", "₹${fare['peak_charges']?.toStringAsFixed(0)}"),
                if (_discount > 0) _fr("Discount", "-₹$_discount", color: AppColors.success),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                _fr("Total", "₹${amount - _discount}", bold: true),
              ]),
            ),
            const SizedBox(height: 15),
            Text("WHEN", style: AppText.tiny),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: _Toggle(
                label: "Now", selected: _scheduledTime == null,
                onTap: () => setModal(() => _scheduledTime = null))),
              const SizedBox(width: 9),
              Expanded(child: _Toggle(
                label: _scheduledTime == null ? "Schedule" : "${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}",
                selected: _scheduledTime != null,
                onTap: () async {
                  final now = DateTime.now();
                  final pickedDate = await showDatePicker(context: context, initialDate: now.add(const Duration(hours: 1)), firstDate: now, lastDate: now.add(const Duration(hours: 24)));
                  if (pickedDate != null && ctx.mounted) {
                    final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
                    if (pickedTime != null) {
                      final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                      setModal(() => _scheduledTime = dt);
                    }
                  }
                })),
            ]),
            const SizedBox(height: 15),
            Text("PROMO CODE", style: AppText.tiny),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: TextField(
                controller: _promoCtrl,
                textCapitalization: TextCapitalization.characters,
                style: AppText.bodyStrong.copyWith(fontSize: 13.5, letterSpacing: 1.1),
                decoration: const InputDecoration(hintText: "Enter code", isDense: true),
              )),
              const SizedBox(width: 9),
              SizedBox(height: 48, width: 88, child: ElevatedButton(
                onPressed: () {
                  final code = _promoCtrl.text.trim().toUpperCase();
                  if (code == "ZIP50") { setModal(() { _discount = (amount * 0.5).toInt(); _appliedPromo = code; }); }
                  else if (code == "ZIP20") { setModal(() { _discount = 20; _appliedPromo = code; }); }
                  else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid code"))); }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: AppColors.ink,
                ),
                child: Text("Apply", style: AppText.button.copyWith(color: Colors.white, fontSize: 13.5)),
              )),
            ]),
            const SizedBox(height: 19),
            Text("PAY WITH", style: AppText.tiny),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: SizedBox(height: 52, child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(ctx); _bookRide("cash"); },
                icon: const Icon(Icons.payments_rounded, size: 17),
                label: Text("Cash", style: AppText.button.copyWith(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ))),
              const SizedBox(width: 11),
              Expanded(child: SizedBox(height: 52, child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(ctx); _bookRide("upi"); },
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 17),
                label: Text("UPI", style: AppText.button.copyWith(color: Colors.white)),
              ))),
            ]),
          ]),
        ),
      )),
    );
  }

  Widget _fr(String l, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3.5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: bold ? AppText.bodyStrong.copyWith(fontSize: 14) : AppText.body.copyWith(fontSize: 13)),
      Text(v, style: bold ? AppText.price.copyWith(fontSize: 17) : AppText.bodyStrong.copyWith(fontSize: 13, color: color ?? AppColors.ink)),
    ]),
  );

  Future<void> _bookRide(String pm) async {
    if (_pickupLoc == null || _dropLoc == null) return;
    setState(() => _isBooking = true);
    try {
      final scheduledStr = _scheduledTime?.toIso8601String();
      final r = await _api.bookRide(_pickupLoc!.latitude, _pickupLoc!.longitude, _pickupCtrl.text, _dropLoc!.latitude, _dropLoc!.longitude, _dropCtrl.text, pm, _appliedPromo ?? "", rideMode: _rideMode, scheduledAt: scheduledStr);
      if (!mounted) return;
      if (r["success"] == true && r["data"] != null && r["data"]["ride"] != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RideTrackingPage(rideData: r["data"]["ride"])));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r["error"]?["message"] ?? "Booking failed"), duration: const Duration(seconds: 5)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Booking error: $e"), duration: const Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _sos() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.warning_rounded, color: AppColors.danger, size: 24),
        const SizedBox(width: 9),
        Text("Emergency SOS", style: AppText.h3.copyWith(color: AppColors.danger)),
      ]),
      content: Text("This alerts our support team immediately with your location.", style: AppText.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            try { await _api.sos(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS sent"))); } catch (_) {}
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text("Send SOS")),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      _loading
        ? const Center(child: CircularProgressIndicator())
        : FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              center: _currentLoc ?? const LatLng(0, 0),
              zoom: 15,
              onTap: (tapPos, latlng) {
                if (_pinMode) {
                  setState(() { _dropLoc = latlng; _dropCtrl.text = "Pinned location"; _pinMode = false; });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Drop location set"), duration: Duration(seconds: 2)));
                }
              },
              onLongPress: (tapPos, latlng) {
                setState(() {
                  if (_dropLoc == null) { _dropLoc = latlng; _dropCtrl.text = "Pinned"; }
                  else { _pickupLoc = latlng; _pickupCtrl.text = "Pinned"; _dropLoc = null; _dropCtrl.clear(); }
                });
              },
            ),
            children: [
              TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.vybe.customer"),
              if (_pickupLoc != null && _dropLoc != null) PolylineLayer(polylines: [
                Polyline(points: [_pickupLoc!, _dropLoc!], strokeWidth: 3.5, color: AppColors.primary.withOpacity(0.75)),
              ]),
              MarkerLayer(markers: [
                if (_pickupLoc != null) Marker(point: _pickupLoc!, width: 22, height: 22, child: Container(
                  decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3.5),
                    boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 9)]))),
                if (_dropLoc != null) Marker(point: _dropLoc!, width: 22, height: 22, child: Container(
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.white, width: 3.5),
                    boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.35), blurRadius: 9)]))),
              ]),
            ],
          ),

      // Top bar
      Positioned(left: 16, right: 16, top: MediaQuery.of(context).padding.top + 10, child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: _showBookingPanel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadow.card),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: _dropCtrl.text.isNotEmpty ? AppColors.danger : AppColors.accent,
                shape: _dropCtrl.text.isNotEmpty ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: _dropCtrl.text.isNotEmpty ? BorderRadius.circular(2) : null)),
              const SizedBox(width: 12),
              Expanded(child: Text(
                _dropCtrl.text.isNotEmpty ? _dropCtrl.text : "Where are you going?",
                style: _dropCtrl.text.isNotEmpty
                  ? AppText.bodyStrong.copyWith(fontSize: 13.5)
                  : AppText.body.copyWith(fontSize: 13.5, color: AppColors.muted),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.search_rounded, size: 18, color: AppColors.muted),
            ]),
          ),
        )),
        const SizedBox(width: 9),
        _SquareBtn(icon: Icons.headset_mic_rounded, onTap: () => Navigator.pushNamed(context, '/support')),
        const SizedBox(width: 9),
        _SquareBtn(icon: Icons.warning_rounded, color: AppColors.danger, onTap: _sos),
      ])),

      // My location button
      Positioned(right: 16, bottom: 106, child: GestureDetector(
        onTap: _getLocation,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), boxShadow: AppShadow.card),
          child: const Icon(Icons.my_location_rounded, size: 20, color: AppColors.primary),
        ),
      )),

      // Bottom CTA
      Positioned(left: 16, right: 16, bottom: 24, child: VybeFadeIn(child: GestureDetector(
        onTap: _showBookingPanel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.32), blurRadius: 18, offset: const Offset(0, 6))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.electric_rickshaw_rounded, color: Colors.white, size: 19),
            const SizedBox(width: 10),
            Text("Book a ride", style: AppText.button.copyWith(color: Colors.white, fontSize: 15)),
          ]),
        ),
      ))),

      // Pin mode banner
      if (_pinMode) Positioned(left: 16, right: 16, bottom: 86, child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadow.lifted),
        child: Row(children: [
          const Icon(Icons.touch_app_rounded, color: Colors.white, size: 19),
          const SizedBox(width: 11),
          Expanded(child: Text("Tap the map to set drop location", style: AppText.bodyStrong.copyWith(color: Colors.white, fontSize: 13))),
          GestureDetector(onTap: () => setState(() => _pinMode = false), child: const Icon(Icons.close_rounded, color: Colors.white, size: 19)),
        ]),
      )),

      // Loading overlay
      if (_isBooking) Positioned.fill(child: Container(
        color: AppColors.ink.withOpacity(0.45),
        child: Center(child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(strokeWidth: 2.5),
            const SizedBox(height: 17),
            Text("Please wait...", style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
          ]),
        )),
      )),
    ]),
  );
}

class _SquareBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color? color;
  const _SquareBtn({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 46, height: 46,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadow.card),
      child: Icon(icon, size: 19, color: color ?? AppColors.body),
    ),
  );
}

class _Toggle extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _Toggle({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: selected ? AppColors.primary : AppColors.line),
      ),
      child: Center(child: Text(label, style: AppText.button.copyWith(
        fontSize: 13.5, color: selected ? Colors.white : AppColors.body))),
    ),
  );
}
