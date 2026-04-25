import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../controllers/home_controller.dart';

class TopBanner extends StatelessWidget {
  const TopBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.find<HomeController>();
    
    return Obx(
      () => Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 60, bottom: 10),
        decoration: BoxDecoration(
          color: controller.isOnline.value
              ? AppColors.primaryGreen
              : Colors.grey,
        ),
        child: Center(
          child: Text(
            controller.isOnline.value ? "Online" : "Offline",
            style: AppStyle.title.copyWith(
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
