import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../models/auth_response.dart';
import '../utils/app_colors.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  final StorageService _storageService = Get.find<StorageService>();
  
  var isLoading = false.obs;
  var isPasswordHidden = true.obs;

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  void login(String email, String password) async {
    isLoading.value = true;
    try {
      final responseMap = await _authService.login(email, password);
      final authResponse = AuthResponse.fromJson(responseMap);

      if (authResponse.status == 'success' && authResponse.data != null) {
        // Save tokens
        await _storageService.saveAccessToken(authResponse.data!.tokens.accessToken);
        await _storageService.saveRefreshToken(authResponse.data!.tokens.refreshToken);
        
        // Save user profile details
        await _storageService.saveUser(authResponse.data!.user);

        Get.snackbar(
          "Success",
          "Welcome back, ${authResponse.data!.user.profile?.fullName ?? 'Driver'}",
          backgroundColor: AppColors.primaryGreen,
          colorText: Colors.white,
        );

        Get.offAllNamed('/home');
      } else {
        Get.snackbar(
          "Error",
          authResponse.message.isNotEmpty ? authResponse.message : "Login failed",
          backgroundColor: AppColors.error,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Something went wrong. Please try again.",
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      print("Login Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void logout() async {
    await _storageService.clearAuth();
    Get.offAllNamed('/login');
  }
}
