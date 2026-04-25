import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../models/user_model.dart';

class StorageService extends GetxService {
  final _storage = GetStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  Future<void> saveAccessToken(String token) async {
    await _storage.write(_accessTokenKey, token);
  }

  String? getAccessToken() {
    return _storage.read(_accessTokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(_refreshTokenKey, token);
  }

  String? getRefreshToken() {
    return _storage.read(_refreshTokenKey);
  }

  Future<void> saveUser(UserModel user) async {
    await _storage.write(_userKey, user.toJson());
  }

  UserModel? getUser() {
    final userData = _storage.read(_userKey);
    if (userData != null) {
      return UserModel.fromJson(userData);
    }
    return null;
  }

  Future<void> clearAuth() async {
    await _storage.remove(_accessTokenKey);
    await _storage.remove(_refreshTokenKey);
    await _storage.remove(_userKey);
  }

  bool isLoggedIn() {
    return getAccessToken() != null;
  }
}
