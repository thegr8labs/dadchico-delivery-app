import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../models/user_model.dart';

/// Tokens live in the platform keystore / keychain (flutter_secure_storage) and are
/// cached in memory so the API layer can read them synchronously. Older installs kept
/// them in GetStorage (a plain file); [init] moves them over once so drivers stay
/// signed in. The non-secret profile stays in GetStorage.
class StorageService extends GetxService {
  StorageService({FlutterSecureStorage? secure}) : _secure = secure ?? const FlutterSecureStorage();

  final _storage = GetStorage();
  final FlutterSecureStorage _secure;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  String? _access;
  String? _refresh;

  /// Loads the tokens, migrating them out of GetStorage the first time. Call before runApp.
  Future<StorageService> init() async {
    try {
      _access = await _secure.read(key: _accessTokenKey);
      _refresh = await _secure.read(key: _refreshTokenKey);
    } catch (e) {
      // A keystore reset (e.g. after an OS restore): treat as signed out.
      debugPrint('Secure storage read failed: $e');
      _access = _refresh = null;
    }

    final oldAccess = _storage.read<String>(_accessTokenKey);
    final oldRefresh = _storage.read<String>(_refreshTokenKey);
    if (oldAccess != null || oldRefresh != null) {
      if ((_access ?? '').isEmpty && (oldAccess ?? '').isNotEmpty) {
        _access = oldAccess;
        _refresh = oldRefresh ?? _refresh;
        try {
          await _secure.write(key: _accessTokenKey, value: oldAccess);
          if (oldRefresh != null) await _secure.write(key: _refreshTokenKey, value: oldRefresh);
        } catch (e) {
          // Keep the old copy so the next launch can try again.
          debugPrint('Token migration failed: $e');
          return this;
        }
      }
      await _storage.remove(_accessTokenKey);
      await _storage.remove(_refreshTokenKey);
    }
    return this;
  }

  Future<void> saveAccessToken(String token) async {
    _access = token;
    try {
      await _secure.write(key: _accessTokenKey, value: token);
    } catch (e) {
      debugPrint('Could not save access token: $e');
    }
  }

  String? getAccessToken() => _access;

  Future<void> saveRefreshToken(String token) async {
    _refresh = token;
    try {
      await _secure.write(key: _refreshTokenKey, value: token);
    } catch (e) {
      debugPrint('Could not save refresh token: $e');
    }
  }

  String? getRefreshToken() => _refresh;

  Future<void> saveUser(UserModel user) async {
    await _storage.write(_userKey, user.toJson());
  }

  UserModel? getUser() {
    final userData = _storage.read(_userKey);
    if (userData is Map) {
      try {
        return UserModel.fromJson(Map<String, dynamic>.from(userData));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearAuth() async {
    _access = _refresh = null;
    await _storage.remove(_userKey);
    // Leftovers from before the move to secure storage, just in case.
    await _storage.remove(_accessTokenKey);
    await _storage.remove(_refreshTokenKey);
    try {
      await _secure.delete(key: _accessTokenKey);
      await _secure.delete(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('Could not clear tokens: $e');
    }
  }

  bool isLoggedIn() {
    final token = getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
