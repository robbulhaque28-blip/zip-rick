import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://zip-rick-4.onrender.com/api/v1';

  // Save & load auth token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // POST request
  static Future<Map<String, dynamic>> post(String path, Map body, {bool auth = true}) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Request failed');
  }

  // GET request
  static Future<Map<String, dynamic>> get(String path, {bool auth = true}) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] == true) {
      return data;
    }
    if (res.statusCode == 401) {
      await clearToken();
      throw Exception('Session expired. Please login again.');
    }
    throw Exception(data['message'] ?? 'Request failed');
  }

  // PUT request
  static Future<Map<String, dynamic>> put(String path, Map body, {bool auth = true}) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Request failed');
  }

  // --- Auth ---
  static Future<Map<String, dynamic>> sendOtp(String phone) {
    return post('/auth/send-otp', {'phone': phone}, auth: false);
  }

  // Verify OTP - returns { user, profile, tokens: { accessToken, refreshToken }, is_new_user }
  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp, {String role = 'driver', String? fullName}) {
    final body = <String, dynamic>{'phone': phone, 'otp': otp, 'role': role};
    if (fullName != null && fullName.isNotEmpty) body['full_name'] = fullName;
    return post('/auth/verify-otp', body, auth: false);
  }

  // --- Driver Profile ---
  static Future<Map<String, dynamic>> getProfile() {
    return get('/drivers/profile');
  }

  static Future<Map<String, dynamic>> updateProfile(Map data) {
    return put('/drivers/profile', data);
  }

  // --- Vehicle ---
  static Future<Map<String, dynamic>> saveVehicle(Map data) {
    return post('/drivers/vehicle', data);
  }

  // --- Online/Offline ---
  static Future<Map<String, dynamic>> toggleOnline() {
    return post('/drivers/toggle-online', {});
  }

  // --- Earnings ---
  static Future<Map<String, dynamic>> getEarnings() {
    return get('/drivers/earnings');
  }

  // --- Ride History ---
  static Future<Map<String, dynamic>> getRideHistory({int page = 1}) {
    return get('/rides/history?page=$page&limit=20');
  }

  // --- Active Ride ---
  static Future<Map<String, dynamic>> getActiveRide() {
    return get('/rides/active');
  }

  // --- Searching Rides (polling) ---
  static Future<Map<String, dynamic>> getSearchingRides() {
    return get('/rides/searching/available');
  }

  // --- Cancel Ride ---
  static Future<Map<String, dynamic>> cancelRide(String rideId, {String reason = ''}) {
    return post('/rides/$rideId/cancel', {'reason': reason});
  }

  // --- Support Tickets ---
  static Future<Map<String, dynamic>> createTicket(String subject, String message) {
    return post('/support/tickets', {'subject': subject, 'message': message, 'role': 'driver'});
  }

  static Future<Map<String, dynamic>> getTickets() {
    return get('/support/tickets');
  }

  // --- Registration Fee ---
  static Future<Map<String, dynamic>> payRegistrationFee({int amount = 499}) {
    return post('/drivers/registration/pay', {'amount': amount});
  }

  // --- SOS ---
  static Future<Map<String, dynamic>> sendSOS(double lat, double lng) {
    return post('/sos', {'latitude': lat, 'longitude': lng, 'type': 'driver'});
  }
}
