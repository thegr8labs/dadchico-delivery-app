import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final StorageService _storageService = Get.find<StorageService>();

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (_storageService.isLoggedIn()) {
      Get.offNamed('/home');
    } else {
      Get.offNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: const Icon(
                Icons.delivery_dining_rounded,
                size: 80,
                color: AppColors.primaryGreen,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),
            const SizedBox(height: 24),
            Text(
              "DELIVERY APP",
              style: AppStyle.heading1.copyWith(
                color: Colors.white,
                letterSpacing: 4,
              ),
            ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),
          ],
        ),
      ),
    );
  }
}
