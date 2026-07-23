import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
    static String baseUrl = 'https://zip-rick-4.onrender.com/api/v1';

  String? _token;

  Future<void> _loadToken() async {
    if (_token != null) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('customer_token');
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customer_token', token);
  }

  Future<String?> getToken() async {
    await _loadToken();
    return _token;
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_token');
  }

  Future<Map<String, String>> _headers() async {
    await _loadToken();
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
      await _saveToken(data['data']['tokens']['accessToken']);
    }
    return data;
  }

  Future<Map<String, dynamic>> getFareEstimate(double pickupLat, double pickupLng, double dropLat, double dropLng, {String rideMode = 'single'}) async {
    final res = await http.post(Uri.parse(baseUrl + '/rides/estimate'), headers: await _headers(), body: jsonEncode({'pickup_latitude': pickupLat, 'pickup_longitude': pickupLng, 'drop_latitude': dropLat, 'drop_longitude': dropLng, 'ride_mode': rideMode}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> bookRide(double pickupLat, double pickupLng, String pickupAddr, double dropLat, double dropLng, String dropAddr, String paymentMethod, String promoCode, {String rideMode = 'single', String? scheduledAt}) async {
    final body = {'pickup_latitude': pickupLat, 'pickup_longitude': pickupLng, 'pickup_address': pickupAddr, 'drop_latitude': dropLat, 'drop_longitude': dropLng, 'drop_address': dropAddr, 'route_distance': 5000, 'route_duration': 900, 'payment_method': paymentMethod, 'promo_code': promoCode, 'ride_mode': rideMode};
    if (scheduledAt != null) body['scheduled_at'] = scheduledAt;
    final res = await http.post(Uri.parse(baseUrl + '/rides/book'), headers: await _headers(), body: jsonEncode(body));
    if (res.statusCode == 401) { await clearToken(); }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getRideHistory() async {
    final res = await http.get(Uri.parse(baseUrl + '/rides/history'), headers: await _headers());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(Uri.parse(baseUrl + '/auth/me'), headers: await _headers());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getActiveRide() async {
    final res = await http.get(Uri.parse(baseUrl + '/rides/active'), headers: await _headers());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> cancelRide(String rideId, {String reason = 'User cancelled'}) async {
    final res = await http.post(Uri.parse(baseUrl + '/rides/' + rideId + '/cancel'), headers: await _headers(), body: jsonEncode({'reason': reason}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> sos() async {
    final res = await http.post(Uri.parse(baseUrl + '/sos'), headers: await _headers());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getSupportTickets() async {
    final res = await http.get(Uri.parse(baseUrl + '/support/tickets'), headers: await _headers());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createSupportTicket(String subject, String description) async {
    final res = await http.post(Uri.parse(baseUrl + '/support/tickets'), headers: await _headers(), body: jsonEncode({'subject': subject, 'description': description}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> updateProfile(String fullName) async {
    final res = await http.put(Uri.parse(baseUrl + '/auth/profile'), headers: await _headers(), body: jsonEncode({'full_name': fullName}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getReferralCode() async {
    final res = await http.get(Uri.parse(baseUrl + '/referral/code'), headers: await _headers());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> applyReferral(String code) async {
    final res = await http.post(Uri.parse(baseUrl + '/referral/apply'), headers: await _headers(), body: jsonEncode({'code': code}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getReferralStats() async {
    final res = await http.get(Uri.parse(baseUrl + '/referral/stats'), headers: await _headers());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> rateRide(String rideId, int rating) async {
    final res = await http.post(Uri.parse(baseUrl + '/rides/' + rideId + '/rate'), headers: await _headers(), body: jsonEncode({'rating': rating}));
    return jsonDecode(res.body);
  }
}