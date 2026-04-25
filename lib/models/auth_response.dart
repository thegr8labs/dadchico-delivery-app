import 'user_model.dart';

class AuthResponse {
  final String status;
  final String message;
  final AuthData? data;

  AuthResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: json['data'] != null ? AuthData.fromJson(json['data']) : null,
    );
  }
}

class AuthData {
  final UserModel user;
  final Tokens tokens;

  AuthData({
    required this.user,
    required this.tokens,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      user: UserModel.fromJson(json['user']),
      tokens: Tokens.fromJson(json['tokens']),
    );
  }
}

class Tokens {
  final String accessToken;
  final String refreshToken;
  final String expiresAt;

  Tokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory Tokens.fromJson(Map<String, dynamic> json) {
    return Tokens(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      expiresAt: json['expiresAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt,
    };
  }
}
