/**
 * Home Screen - Main Map Screen
 * Core screen with Google Maps, location search, ride booking.
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/location_provider.dart';
import '../providers/ride_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pickup_drop_widget.dart';
import '../widgets/fare_estimate_sheet.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();
  LatLng? _pickupLocation;
  LatLng? _dropLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoadingLocation = false;
  bool _showFareSheet = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final location = LatLng(position.latitude, position.longitude);
        setState(() {
          _pickupLocation = location;
          _pickupController.text = 'Current Location';
        });
        _updatePickupMarker(location);
        _animateToLocation(location);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e'), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _animateToLocation(LatLng location) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 15),
      ),
    );
  }

  void _updatePickupMarker(LatLng location) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'pickup');
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      );
    });
  }

  void _onMapLongPress(LatLng location) {
    if (_dropLocation == null) {
      setState(() {
        _dropLocation = location;
        _dropController.text = 'Dropped pin location';
        _markers.removeWhere((m) => m.markerId.value == 'drop');
        _markers.add(
          Marker(
            markerId: const MarkerId('drop'),
            position: location,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Drop'),
          ),
        );
      });
    } else {
      setState(() {
        _pickupLocation = location;
        _pickupController.text = 'Dropped pin location';
        _updatePickupMarker(location);
        _dropLocation = null;
        _dropController.clear();
        _markers.removeWhere((m) => m.markerId.value == 'drop');
      });
    }

    // If both locations are set, draw route
    if (_pickupLocation != null && _dropLocation != null) {
      _drawRoute();
    }
  }

  Future<void> _drawRoute() async {
    if (_pickupLocation == null || _dropLocation == null) return;

    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_pickupLocation!, _dropLocation!],
          color: AppTheme.primaryColor,
          width: 4,
          jointType: JointType.round,
        ),
      );
      _showFareSheet = true;
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(26.1445, 91.7362), // Guwahati default
              zoom: 12,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onLongPress: _onMapLongPress,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            padding: const EdgeInsets.only(top: 120, bottom: 300),
          ),

          // Top Search Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: PickupDropWidget(
                pickupController: _pickupController,
                dropController: _dropController,
                onPickupChanged: (location) {
                  setState(() => _pickupLocation = location);
                  _updatePickupMarker(location);
                  _animateToLocation(location);
                },
                onDropChanged: (location) {
                  setState(() => _dropLocation = location);
                  setState(() {
                    _markers.removeWhere((m) => m.markerId.value == 'drop');
                    _markers.add(
                      Marker(
                        markerId: const MarkerId('drop'),
                        position: location,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        infoWindow: const InfoWindow(title: 'Drop'),
                      ),
                    );
                  });
                  _drawRoute();
                },
                onClearDrop: () {
                  setState(() {
                    _dropLocation = null;
                    _dropController.clear();
                    _markers.removeWhere((m) => m.markerId.value == 'drop');
                    _polylines.clear();
                    _showFareSheet = false;
                  });
                },
                useCurrentLocation: _getCurrentLocation,
              ),
            ),
          ),

          // Current Location Button
          Positioned(
            right: 16,
            bottom: 280,
            child: FloatingActionButton(
              mini: true,
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white,
              child: _isLoadingLocation
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: AppTheme.primaryColor),
            ),
          ),

          // Fare Estimate Bottom Sheet
          if (_showFareSheet && _pickupLocation != null && _dropLocation != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FareEstimateSheet(
                pickupLocation: _pickupLocation!,
                dropLocation: _dropLocation!,
                onBookRide: () {
                  // Navigate to booking confirmation
                  Navigator.pushNamed(context, '/booking', arguments: {
                    'pickup': _pickupLocation,
                    'drop': _dropLocation,
                  });
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 0),
    );
  }
}
