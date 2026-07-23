import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:latlong2/latlong.dart';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _connected = false;
  String? _rideStatus;

  // Driver location for smooth animation
  LatLng? _driverLatLng;
  LatLng? _previousDriverLatLng;
  double _driverHeading = 0;

  bool get connected => _connected;
  LatLng? get driverLatLng => _driverLatLng;
  LatLng? get previousDriverLatLng => _previousDriverLatLng;
  double get driverHeading => _driverHeading;
  String? get rideStatus => _rideStatus;

  Future<void> init(String token) async {
    _socket = io.io('https://zip-rick-4.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      _connected = true;
      notifyListeners();
    });

    _socket!.on('ride:accepted', (data) {
      _rideStatus = 'accepted';
      notifyListeners();
    });

    _socket!.on('ride:driver_arrived', (data) {
      _rideStatus = 'arrived';
      notifyListeners();
    });

    _socket!.on('ride:started', (data) {
      _rideStatus = 'started';
      notifyListeners();
    });

    _socket!.on('ride:completed', (data) {
      _rideStatus = 'completed';
      notifyListeners();
    });

    _socket!.on('ride:driver_location', (data) {
      if (data is Map) {
        final loc = data as Map<String, dynamic>;
        final newLat = double.tryParse(loc['latitude']?.toString() ?? '') ?? 0;
        final newLng = double.tryParse(loc['longitude']?.toString() ?? '') ?? 0;
        final newPoint = LatLng(newLat, newLng);
        
        if (_driverLatLng != null) {
          _previousDriverLatLng = _driverLatLng;
          // Calculate heading
          final dx = newPoint.longitude - _driverLatLng!.longitude;
          final dy = newPoint.latitude - _driverLatLng!.latitude;
          _driverHeading = (dx.abs() > 0.000001 || dy.abs() > 0.000001)
              ? (dy == 0 ? (dx > 0 ? 90 : -90) : (dx / dy) * 180 / 3.14159)
              : _driverHeading;
        }
        
        _driverLatLng = newPoint;
        notifyListeners();
      }
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      notifyListeners();
    });

    _socket!.connect();
  }

  void emit(String event, Map data) {
    _socket?.emit(event, data);
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
