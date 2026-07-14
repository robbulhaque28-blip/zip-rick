import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
    static String baseUrl = 'https://zip-rick-4.onrender.com/api/v1';

  String? _token;
  String? get token => _token;

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer ' + _token!,
    };
  }

  Future<Map<String, dynamic>> sendOTP(String phone) async {
    final res = await http.post(Uri.parse(baseUrl + '/auth/send-otp'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'phone': phone}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> verifyOTP(String phone, String otp, String name, String role) async {
    final res = await http.post(Uri.parse(baseUrl + '/auth/verify-otp'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'phone': phone, 'otp': otp, 'full_name': name, 'role': role}));
    final data = jsonDecode(res.body);
    if (data['success'] == true && data['data'] != null && data['data']['tokens'] != null) {
      _token = data['data']['tokens']['accessToken'];
    }
    return data;
  }

  Future<Map<String, dynamic>> getFareEstimate(double pickupLat, double pickupLng, double dropLat, double dropLng) async {
    final res = await http.post(Uri.parse(baseUrl + '/rides/estimate'), headers: _headers(), body: jsonEncode({'pickup_latitude': pickupLat, 'pickup_longitude': pickupLng, 'drop_latitude': dropLat, 'drop_longitude': dropLng}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> bookRide(double pickupLat, double pickupLng, String pickupAddr, double dropLat, double dropLng, String dropAddr, String paymentMethod, String promoCode) async {
    final res = await http.post(Uri.parse(baseUrl + '/rides/book'), headers: _headers(), body: jsonEncode({'pickup_latitude': pickupLat, 'pickup_longitude': pickupLng, 'pickup_address': pickupAddr, 'drop_latitude': dropLat, 'drop_longitude': dropLng, 'drop_address': dropAddr, 'route_distance': 5000, 'route_duration': 900, 'payment_method': paymentMethod, 'promo_code': promoCode}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getRideHistory() async {
    final res = await http.get(Uri.parse(baseUrl + '/rides/history'), headers: _headers());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(Uri.parse(baseUrl + '/auth/me'), headers: _headers());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getActiveRide() async {
    final res = await http.get(Uri.parse(baseUrl + '/rides/active'), headers: _headers());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> cancelRide(String rideId) async {
    final res = await http.post(Uri.parse(baseUrl + '/rides/' + rideId + '/cancel'), headers: _headers());
    return jsonDecode(res.body);
  }
}