import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../controllers/home_controller.dart';
import '../controllers/auth_controller.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import '../widgets/top_banner.dart';
import '../widgets/profile_header_widget.dart';
import '../widgets/order_shimmer.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = Get.find<HomeController>();
    final StorageService storageService = Get.find<StorageService>();
    final AuthController authController = Get.find<AuthController>();
    final UserModel? user = storageService.getUser();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopBanner(),
          const ProfileHeaderWidget(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(() => homeController.isLoading.value 
                    ? const BigCardShimmer() 
                    : _buildProfileSummaryCard(homeController, user)),
                  const SizedBox(height: 10),
                  Obx(() => homeController.isLoading.value 
                    ? const ListShimmer() 
                    : _buildLifetimeStatsCard(homeController)),
                  const SizedBox(height: 10),
                  Obx(() => homeController.isLoading.value 
                    ? const BigCardShimmer() 
                    : _buildDetailsCard(user)),
                  const SizedBox(height: 20),
                  _buildLogoutButton(authController),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildProfileSummaryCard(
  HomeController homeController,
  UserModel? user,
) {
  String initials = "U";
  if (user?.profile?.fullName != null && user!.profile!.fullName.isNotEmpty) {
    List<String> names = user.profile!.fullName.split(" ");
    if (names.length >= 2) {
      initials = (names[0][0] + names[1][0]).toUpperCase();
    } else {
      initials = names[0][0].toUpperCase();
    }
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Column(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: const Color(0xFFFDE7D1),
          child: Text(
            initials,
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user?.profile?.fullName ?? "User Name",
          style: AppStyle.heading2.copyWith(
            fontSize: 20,
            color: AppColors.textPrimary.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user?.profile?.phone ?? "Phone Number",
          style: AppStyle.subtitle.copyWith(
            color: AppColors.textLight.withOpacity(0.9),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Color(0xFFFABE15), size: 22),
              const SizedBox(width: 4),
              Text(
                "4.6",
                style: AppStyle.title.copyWith(
                  fontSize: 16,
                  color: AppColors.textPrimary.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "(${homeController.stats['trips']} deliveries)",
                style: AppStyle.subtitle.copyWith(
                  color: AppColors.textLight.withOpacity(0.8),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildLifetimeStatsCard(HomeController homeController) {
  return Obx(
    () => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Lifetime Stats",
            style: AppStyle.subtitle.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  homeController.stats['earnings'] ?? '₹0',
                  "Total",
                  const Color(0xFFF0FDF4),
                  AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatBox(
                  homeController.stats['trips'] ?? '0',
                  "Deliveries",
                  const Color(0xFFFFF7ED),
                  const Color(0xFFF97316),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildStatBox(
  String value,
  String label,
  Color bgColor,
  Color textColor,
) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: AppStyle.title.copyWith(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppStyle.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Widget _buildDetailsCard(UserModel? user) {
  String joinedDate = "N/A";
  if (user?.profile?.createdAt != null) {
    try {
      DateTime dt = DateTime.parse(user!.profile!.createdAt!);
      joinedDate = DateFormat('MMM yyyy').format(dt);
    } catch (e) {
      print("Date parse error: $e");
    }
  }

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Details",
          style: AppStyle.subtitle.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        _buildDetailItem("Email", user?.email ?? "N/A"),
        const SizedBox(height: 20),
        _buildDetailItem("City", user?.profile?.city ?? "N/A"),
        const SizedBox(height: 20),
        _buildDetailItem(
          "Vehicle",
          "${user?.profile?.vehicleType ?? 'N/A'} - ${user?.profile?.vehicleNumber ?? ''}",
        ),
        const SizedBox(height: 20),
        _buildDetailItem("Joined", joinedDate),
      ],
    ),
  );
}

Widget _buildLogoutButton(AuthController controller) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: TextButton(
      onPressed: () {
        Get.dialog(
          AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text("Logout", style: AppStyle.heading2),
            content: Text(
              "Are you sure you want to logout from your account?",
              style: AppStyle.subtitle,
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  "Cancel",
                  style: AppStyle.title.copyWith(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  controller.logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Logout",
                  style: AppStyle.title.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout_rounded),
          const SizedBox(width: 10),
          Text(
            "Logout Account",
            style: AppStyle.title.copyWith(color: AppColors.error),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDetailItem(String label, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: AppStyle.body.copyWith(
          color: AppColors.textSecondary.withOpacity(0.7),
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: AppStyle.title.copyWith(
          fontSize: 16,
          color: AppColors.textPrimary.withOpacity(0.8),
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}
