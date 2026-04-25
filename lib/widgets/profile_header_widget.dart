import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../controllers/home_controller.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';

class ProfileHeaderWidget extends StatelessWidget {
  const ProfileHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.find<HomeController>();
    final StorageService storageService = Get.find<StorageService>();
    final UserModel? user = storageService.getUser();

    String initials = "U";
    if (user?.profile?.fullName != null && user!.profile!.fullName.isNotEmpty) {
      List<String> names = user.profile!.fullName.trim().split(" ");
      if (names.length >= 2) {
        initials = (names[0][0] + names[1][0]).toUpperCase();
      } else if (names.isNotEmpty && names[0].isNotEmpty) {
        initials = names[0][0].toUpperCase();
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFFDE7D1),
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.profile?.fullName ?? "Driver Name",
                  style: AppStyle.heading2,
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text("4.6", style: AppStyle.subtitle),
                    const SizedBox(width: 8),
                    const Text("|", style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    const Icon(Icons.pedal_bike, color: Colors.grey, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      user?.profile?.vehicleType ?? "Vehicle",
                      style: AppStyle.subtitle,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Obx(
            () => CupertinoSwitch(
              value: controller.isOnline.value,
              onChanged: (val) => controller.toggleOnline(val),
              activeColor: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}
