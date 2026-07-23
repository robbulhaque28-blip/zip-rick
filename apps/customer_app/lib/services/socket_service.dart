import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:latlong2/latlong.dart';

class ChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      rideId: json['ride_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderRole: json['sender_role']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _connected = false;
  String? _rideStatus;
  LatLng? _driverLatLng;

  // Chat messages
  final List<ChatMessage> _chatMessages = [];
  final StreamController<ChatMessage> _chatController = StreamController<ChatMessage>.broadcast();

  bool get connected => _connected;
  LatLng? get driverLatLng => _driverLatLng;
  String? get rideStatus => _rideStatus;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  Stream<ChatMessage> get chatStream => _chatController.stream;

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
        _driverLatLng = LatLng(newLat, newLng);
        notifyListeners();
      }
    });

    // Chat events
    _socket!.on('chat:received', (data) {
      if (data is Map) {
        final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
        _chatMessages.add(msg);
        _chatController.add(msg);
        notifyListeners();
      }
    });

    _socket!.on('chat:sent', (data) {
      if (data is Map) {
        final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
        _chatMessages.add(msg);
        _chatController.add(msg);
        notifyListeners();
      }
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      notifyListeners();
    });

    _socket!.connect();
  }

  void sendChat(String rideId, String message) {
    _socket?.emit('chat:send', {
      'ride_id': rideId,
      'message': message,
    });
  }

  void emit(String event, Map data) {
    _socket?.emit(event, data);
  }

  void dispose() {
    _chatController.close();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
