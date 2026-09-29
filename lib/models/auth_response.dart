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
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map && json['data']['user'] is Map
          ? AuthData.fromJson(Map<String, dynamic>.from(json['data']))
          : null,
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
      user: UserModel.fromJson(Map<String, dynamic>.from(json['user'])),
      tokens: Tokens.fromJson(json['tokens'] is Map ? Map<String, dynamic>.from(json['tokens']) : const {}),
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
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString() ?? '',
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
