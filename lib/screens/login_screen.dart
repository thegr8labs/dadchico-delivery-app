// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text("Welcome Back 👋", style: AppStyle.heading1),
            const SizedBox(height: 8),
            Text(
              "Enter your credentials to login to your delivery account.",
              style: AppStyle.subtitle,
            ),
            const SizedBox(height: 40),
            // Email Field
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                boxShadow: AppStyle.cardShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Email Address",
                  hintStyle: AppStyle.subtitle.copyWith(color: Colors.grey),
                  border: InputBorder.none,
                  icon: Icon(
                    Icons.email_outlined,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                style: AppStyle.title,
              ),
            ),
            const SizedBox(height: 20),
            // Password Field
            Obx(
              () => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  boxShadow: AppStyle.cardShadow,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: passwordController,
                  obscureText: authController.isPasswordHidden.value,
                  decoration: InputDecoration(
                    hintText: "Password",
                    hintStyle: AppStyle.subtitle.copyWith(color: Colors.grey),
                    border: InputBorder.none,
                    icon: Icon(
                      Icons.lock_outline,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        authController.isPasswordHidden.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => authController.togglePasswordVisibility(),
                    ),
                  ),
                  style: AppStyle.title,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Obx(
              () => SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: authController.isLoading.value
                      ? null
                      : () {
                          if (emailController.text.isNotEmpty &&
                              passwordController.text.isNotEmpty) {
                            authController.login(
                              emailController.text,
                              passwordController.text,
                            );
                          } else {
                            Get.snackbar(
                              "Error",
                              "Please enter email and password",
                              backgroundColor: AppColors.error,
                              colorText: Colors.white,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: authController.isLoading.value
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Login",
                          style: AppStyle.title.copyWith(color: Colors.white),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Text(
                "By logging in, you agree to our Terms & Privacy Policy.",
                style: AppStyle.caption,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
