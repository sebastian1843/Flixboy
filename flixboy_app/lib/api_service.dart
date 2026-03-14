import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.1.3:3000/api/v1';

  static String? _token;

  static void setToken(String token) {
    _token = token;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

 static Future<Map<String, dynamic>> register(
    String name, String email, String password) async {
  final response = await http.post(
    Uri.parse('$baseUrl/auth/register'),
    headers: _headers,
    body: jsonEncode({
      'fullName': name,
      'email': email,
      'password': password,
    }),
  );
  return jsonDecode(response.body);
}
  static Future<Map<String, dynamic>> getHomeContent() async {
    final response = await http.get(
      Uri.parse('$baseUrl/content/home'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getTrending() async {
    final response = await http.get(
      Uri.parse('$baseUrl/content/trending'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data['data'] ?? [];
  }
}