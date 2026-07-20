import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _connected = false;
  Map<String, dynamic>? _driverLocation;
  String? _rideStatus;

  bool get connected => _connected;
  Map<String, dynamic>? get driverLocation => _driverLocation;
  String? get rideStatus => _rideStatus;

  Future<void> init(String token) async {
    _socket = io.io('https://zip-rick-4.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      _connected = true;
      notifyListeners();
      debugPrint('Socket connected');
    });

    _socket!.on('ride:accepted', (data) {
      _rideStatus = 'accepted';
      notifyListeners();
      debugPrint('Ride accepted: $data');
    });

    _socket!.on('ride:driver_arrived', (data) {
      _rideStatus = 'arrived';
      notifyListeners();
      debugPrint('Driver arrived');
    });

    _socket!.on('ride:started', (data) {
      _rideStatus = 'started';
      notifyListeners();
      debugPrint('Ride started');
    });

    _socket!.on('ride:completed', (data) {
      _rideStatus = 'completed';
      notifyListeners();
      debugPrint('Ride completed');
    });

    _socket!.on('ride:driver_location', (data) {
      if (data is Map) {
        _driverLocation = data as Map<String, dynamic>;
        notifyListeners();
      }
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      notifyListeners();
      debugPrint('Socket disconnected');
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
