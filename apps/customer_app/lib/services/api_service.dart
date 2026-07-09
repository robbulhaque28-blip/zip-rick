import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static String baseUrl = 'http://192.168.31.87:3000/api/v1';

  String? _token;

  Future<Map<String, dynamic>> sendOTP(String phone) async {
    final url = Uri.parse('$baseUrl/auth/send-otp');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> verifyOTP(String phone, String otp, String name, String role) async {
    final url = Uri.parse('$baseUrl/auth/verify-otp');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
        'full_name': name,
        'role': role
      }),
    );
    final data = jsonDecode(res.body);
    if (data['success'] == true && data['data'] != null && data['data']['tokens'] != null) {
      _token = data['data']['tokens']['accessToken'];
    }
    return data;
  }
}