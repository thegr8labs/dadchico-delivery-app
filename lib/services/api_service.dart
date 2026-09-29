import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'storage_service.dart';

/// Error with a message that is safe to show to the delivery partner.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = 'https://api.dadchico.in/api/v1';
  static const Duration timeout = Duration(seconds: 20);

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Auth headers for the signed-in driver (Bearer + cookie, both accepted by the API).
  static Map<String, String> authHeaders() {
    if (!Get.isRegistered<StorageService>()) return {};
    final token = Get.find<StorageService>().getAccessToken();
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token', 'Cookie': 'accessToken=$token'};
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body, {Map<String, String>? extraHeaders}) {
    return _send(() => http.post(
          Uri.parse('$baseUrl$endpoint'),
          headers: {...headers, ...?extraHeaders},
          body: jsonEncode(body),
        ));
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body, {Map<String, String>? extraHeaders}) {
    return _send(() => http.patch(
          Uri.parse('$baseUrl$endpoint'),
          headers: {...headers, ...?extraHeaders},
          body: jsonEncode(body),
        ));
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body, {Map<String, String>? extraHeaders}) {
    return _send(() => http.put(
          Uri.parse('$baseUrl$endpoint'),
          headers: {...headers, ...?extraHeaders},
          body: jsonEncode(body),
        ));
  }

  Future<http.Response> delete(String endpoint, {Map<String, dynamic>? body, Map<String, String>? extraHeaders}) {
    return _send(() => http.delete(
          Uri.parse('$baseUrl$endpoint'),
          headers: {...headers, ...?extraHeaders},
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<http.Response> get(String endpoint, {Map<String, String>? extraHeaders}) {
    return _send(() => http.get(
          Uri.parse('$baseUrl$endpoint'),
          headers: {...headers, ...?extraHeaders},
        ));
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on SocketException {
      throw const ApiException('No internet connection. Check your network and try again.');
    } on TimeoutException {
      throw const ApiException('The server is taking too long to respond. Please try again.');
    } on HandshakeException {
      throw const ApiException('Secure connection failed. Check your date & time settings and try again.');
    } on http.ClientException {
      throw const ApiException('Could not reach Dadchico. Check your internet connection.');
    }
  }

  /// Decode a JSON response, turning error responses into [ApiException]s with the server's message.
  static Map<String, dynamic> decode(http.Response response, {String fallback = 'Something went wrong. Please try again.'}) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300 && body != null) return body;

    final serverMessage = body?['message'] is String ? body!['message'] as String : null;
    if (response.statusCode == 401) {
      throw ApiException(serverMessage ?? 'Your session has expired. Please log in again.', statusCode: 401);
    }
    if (response.statusCode == 429) {
      throw const ApiException('Too many attempts. Please wait a minute and try again.', statusCode: 429);
    }
    if (response.statusCode >= 500) {
      throw ApiException('Dadchico is having trouble right now. Please try again shortly.', statusCode: response.statusCode);
    }
    throw ApiException(serverMessage ?? fallback, statusCode: response.statusCode);
  }
}
