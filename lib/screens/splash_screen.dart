import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../widgets/brand_lockup.dart';

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

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Get.offNamed(_storageService.isLoggedIn() ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const BrandLockup(logoHeight: 52)
                .animate()
                .fadeIn(duration: 450.ms)
                .scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutBack, duration: 550.ms),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primaryGreen),
            ).animate().fadeIn(delay: 500.ms),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text('Fresh groceries, delivered by you', style: AppStyle.caption),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }
}
