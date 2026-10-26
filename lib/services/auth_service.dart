import 'api_service.dart';

class AuthService extends ApiService {
  /// Returns the decoded login response, or throws an [ApiException] with a readable message.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await post('/auth/login', {
      'identifier': email.trim(),
      // Trim spaces picked up when copying the password from the invite email
      'password': password.trim(),
    });
    return ApiService.decode(response, fallback: 'Login failed. Check your email and password.');
  }

  /// Emails a password reset link. The server answers the same whether or not the email exists.
  Future<void> forgotPassword(String email) async {
    final response = await post('/auth/forgot-password', {'email': email.trim()});
    ApiService.decode(response, fallback: 'Could not send the reset link. Please try again.');
  }

  /// Best-effort server logout (clears server cookies / refresh token).
  /// [headers]: auth headers captured before the local session was cleared.
  Future<void> logout({Map<String, String>? headers}) async {
    try {
      await post('/auth/logout', {}, extraHeaders: headers ?? ApiService.authHeaders());
    } catch (_) {
      // Ignore — local sign-out always succeeds.
    }
  }
}
