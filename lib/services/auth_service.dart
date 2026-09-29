import 'api_service.dart';

class AuthService extends ApiService {
  /// Returns the decoded login response, or throws an [ApiException] with a readable message.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await post('/auth/login', {
      'identifier': email.trim(),
      'password': password,
    });
    return ApiService.decode(response, fallback: 'Login failed. Check your email and password.');
  }

  /// Best-effort server logout (clears server cookies / refresh token).
  Future<void> logout() async {
    try {
      await post('/auth/logout', {}, extraHeaders: ApiService.authHeaders());
    } catch (_) {
      // Ignore — local sign-out always succeeds.
    }
  }
}
