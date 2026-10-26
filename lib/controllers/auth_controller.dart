import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/auth_response.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import 'home_controller.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  final StorageService _storageService = Get.find<StorageService>();

  var isLoading = false.obs;
  var isPasswordHidden = true.obs;

  /// Inline error shown under the form (keeps the message visible, unlike a snackbar).
  var errorMessage = ''.obs;

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  Future<void> login(String email, String password) async {
    if (isLoading.value) return;
    errorMessage.value = '';

    final trimmed = email.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      errorMessage.value = 'Enter your email and password.';
      return;
    }

    isLoading.value = true;
    try {
      final responseMap = await _authService.login(trimmed, password);
      final authResponse = AuthResponse.fromJson(responseMap);
      final data = authResponse.data;

      if (authResponse.status != 'success' || data == null || data.tokens.accessToken.isEmpty) {
        errorMessage.value = authResponse.message.isNotEmpty ? authResponse.message : 'Login failed. Please try again.';
        return;
      }

      if (data.user.userType != 'driver') {
        errorMessage.value = 'This account is not a delivery partner account. Use the Dadchico shopping app instead.';
        return;
      }

      await _storageService.saveAccessToken(data.tokens.accessToken);
      await _storageService.saveRefreshToken(data.tokens.refreshToken);
      await _storageService.saveUser(data.user);

      // Push notifications for new orders (no-op until Firebase is configured).
      if (Get.isRegistered<NotificationService>()) {
        final notifications = Get.find<NotificationService>();
        notifications.requestPermission().then((_) => notifications.registerDevice());
      }

      final name = data.user.profile?.fullName;
      Get.offAllNamed('/home');
      Get.snackbar(
        'Welcome back',
        name != null && name.isNotEmpty ? 'Hi $name, ready to deliver?' : 'You are signed in.',
        backgroundColor: AppColors.primaryGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
    } on ApiException catch (e) {
      // Only a bad email/password comes back as "Invalid credentials"; show the real reason
      // for anything else (e.g. locked after too many tries, or an inactive account).
      errorMessage.value = e.statusCode == 401 && e.message == 'Invalid credentials'
          ? 'Incorrect email or password.'
          : e.message;
    } catch (e) {
      debugPrint('Login error: $e');
      errorMessage.value = 'Something went wrong while signing in. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  bool _loggingOut = false;

  /// Signs out locally right away; the server calls (device token, logout) run in the
  /// background with the headers captured first. Safe to call more than once.
  Future<void> logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      final wasSignedIn = _storageService.isLoggedIn();
      final headers = ApiService.authHeaders();
      // Stop live location (don't create the home controller just for this).
      if (Get.isRegistered<HomeController>() && !Get.isPrepared<HomeController>()) {
        Get.find<HomeController>().stopLocationSharing();
      }
      await _storageService.clearAuth();
      if (Get.currentRoute != '/login') Get.offAllNamed('/login');
      if (!wasSignedIn) return;
      if (Get.isRegistered<NotificationService>()) {
        unawaited(Get.find<NotificationService>().unregisterDevice(headers: headers));
      }
      unawaited(_authService.logout(headers: headers));
    } finally {
      _loggingOut = false;
    }
  }
}
