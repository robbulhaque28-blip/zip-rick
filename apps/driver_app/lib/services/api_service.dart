import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://zip-rick-4.onrender.com/api/v1';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driver_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('driver_token');
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Future<Map<String, dynamic>> post(String path, Map body, {bool auth = true}) async {
    final res = await http.post(Uri.parse('$baseUrl$path'), headers: await _headers(auth: auth), body: jsonEncode(body));
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] == true) return data;
    throw Exception(data['message'] ?? 'Request failed');
  }

  static Future<Map<String, dynamic>> get(String path, {bool auth = true}) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: await _headers(auth: auth));
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] == true) return data;
    if (res.statusCode == 401) { await clearToken(); throw Exception('Session expired'); }
    throw Exception(data['message'] ?? 'Request failed');
  }

  static Future<Map<String, dynamic>> put(String path, Map body, {bool auth = true}) async {
    final res = await http.put(Uri.parse('$baseUrl$path'), headers: await _headers(auth: auth), body: jsonEncode(body));
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] == true) return data;
    throw Exception(data['message'] ?? 'Request failed');
  }

  static Future<Map<String, dynamic>> sendOtp(String phone) => post('/auth/send-otp', {'phone': phone}, auth: false);
  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp, {String role = 'driver', String? fullName}) {
    final body = <String, dynamic>{'phone': phone, 'otp': otp, 'role': role};
    if (fullName != null && fullName.isNotEmpty) body['full_name'] = fullName;
    return post('/auth/verify-otp', body, auth: false);
  }
  static Future<Map<String, dynamic>> getProfile() => get('/drivers/profile');
  static Future<Map<String, dynamic>> updateProfile(Map data) => put('/drivers/profile', data);
  static Future<Map<String, dynamic>> saveVehicle(Map data) => post('/drivers/vehicle', data);
  static Future<Map<String, dynamic>> toggleOnline() => post('/drivers/toggle-online', {});
  static Future<Map<String, dynamic>> getEarnings() => get('/drivers/earnings');
  static Future<Map<String, dynamic>> getRideHistory({int page = 1}) => get('/rides/history?page=$page&limit=20');
  static Future<Map<String, dynamic>> getActiveRide() => get('/rides/active');
  static Future<Map<String, dynamic>> getSearchingRides() => get('/rides/searching/available');
  static Future<Map<String, dynamic>> cancelRide(String rideId, {String reason = ''}) => post('/rides/$rideId/cancel', {'reason': reason});
  static Future<Map<String, dynamic>> createTicket(String subject, String message) => post('/support/tickets', {'subject': subject, 'message': message, 'role': 'driver'});
  static Future<Map<String, dynamic>> sendSOS(double lat, double lng) => post('/sos', {'latitude': lat, 'longitude': lng, 'type': 'driver'});
  static Future<Map<String, dynamic>> payRegistrationFee({int amount = 499}) => post('/drivers/registration/pay', {'amount': amount});
}
