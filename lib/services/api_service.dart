import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://api.dadchico.in/api/v1';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<http.Response> post(String endpoint, Map<String, dynamic> body, {Map<String, String>? extraHeaders}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final combinedHeaders = {...headers, ...?extraHeaders};
    return await http.post(
      url,
      headers: combinedHeaders,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body, {Map<String, String>? extraHeaders}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final combinedHeaders = {...headers, ...?extraHeaders};
    return await http.patch(
      url,
      headers: combinedHeaders,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> get(String endpoint, {Map<String, String>? extraHeaders}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final combinedHeaders = {...headers, ...?extraHeaders};
    return await http.get(
      url,
      headers: combinedHeaders,
    );
  }
}
