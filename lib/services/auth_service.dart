import 'dart:convert';
import 'api_service.dart';

class AuthService extends ApiService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await post('/auth/login', {
        'identifier': email,
        'password': password,
      });

      final decoded = jsonDecode(response.body);
      return decoded;
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }
}
