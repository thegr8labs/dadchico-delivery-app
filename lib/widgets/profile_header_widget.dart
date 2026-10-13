import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';

/// Greeting row: initials avatar, name and vehicle.
class ProfileHeaderWidget extends StatelessWidget {
  const ProfileHeaderWidget({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? user = Get.find<StorageService>().getUser();
    final name = (user?.profile?.fullName ?? '').trim();
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'D'
        : (parts.length > 1 ? parts[0][0] + parts[1][0] : parts[0][0]).toUpperCase();
    final vehicle = user?.profile?.vehicleType ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryTint,
            child: Text(
              initials,
              style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(), style: AppStyle.caption),
                Text(
                  name.isNotEmpty ? name : 'Delivery partner',
                  style: AppStyle.heading2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (vehicle.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EDF2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.two_wheeler_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(vehicle[0].toUpperCase() + vehicle.substring(1), style: AppStyle.caption),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
