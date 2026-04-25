// ignore_for_file: unused_import

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../controllers/home_controller.dart';
import '../widgets/stat_card.dart';
import '../widgets/order_card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/top_banner.dart';
import '../widgets/profile_header_widget.dart';
import '../widgets/order_shimmer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = Get.find<HomeController>();

    return Column(
      children: [
        const TopBanner(),
        const ProfileHeaderWidget(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dashboard Stats
                _buildDashboard(homeController),
                const SizedBox(height: 20),

                // New Requests Section (Real Data)
                Obx(() {
                  if (homeController.isLoading.value) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          Icons.notification_important_outlined,
                          "Loading Requests...",
                          AppColors.primaryBlue,
                        ),
                        const SizedBox(height: 10),
                        const OrderShimmer(),
                        const OrderShimmer(),
                      ],
                    );
                  }
                  if (homeController.unassignedDeliveries.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        Icons.notification_important_outlined,
                        "New Requests (${homeController.unassignedDeliveries.length})",
                        AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 10),
                      ...homeController.unassignedDeliveries
                          .map((order) => OrderCard(order: order))
                          .toList(),
                      const SizedBox(height: 20),
                    ],
                  );
                }),

                // Active Orders Section (Real Data)
                Obx(() {
                  if (homeController.isLoading.value) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          Icons.local_shipping_outlined,
                          "Loading Active...",
                          AppColors.primaryOrange,
                        ),
                        const SizedBox(height: 10),
                        const OrderShimmer(),
                      ],
                    );
                  }
                  if (homeController.activeDeliveries.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      _buildSectionHeader(
                        Icons.local_shipping_outlined,
                        "Active (${homeController.activeDeliveries.length})",
                        AppColors.primaryOrange,
                      ),
                      const SizedBox(height: 10),
                      ...homeController.activeDeliveries
                          .map((order) => OrderCard(order: order))
                          .toList(),
                      const SizedBox(height: 20),
                    ],
                  );
                }),

                // Done Section
                Obx(() {
                  if (homeController.isLoading.value) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          Icons.check_circle_outline,
                          "Loading Done...",
                          AppColors.primaryGreen,
                        ),
                        const SizedBox(height: 10),
                        const DoneShimmer(),
                      ],
                    );
                  }
                  if (homeController.doneDeliveries.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      _buildSectionHeader(
                        Icons.check_circle_outline,
                        "Done (${homeController.doneDeliveries.length})",
                        AppColors.primaryGreen,
                      ),
                      const SizedBox(height: 10),
                      ...homeController.doneDeliveries
                          .map((order) => OrderCard(order: order, isActive: false))
                          .toList(),
                      const SizedBox(height: 20),
                    ],
                  );
                }),

                const SizedBox(height: 10),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildDashboard(HomeController controller) {
  return Obx(
    () => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        StatCard(
          title: "Today",
          value: controller.stats['earnings']!,
          icon: Icons.currency_rupee,
          iconColor: AppColors.primaryGreen,
        ),
        StatCard(
          title: "Trips",
          value: controller.stats['trips']!,
          icon: Icons.alt_route,
          iconColor: AppColors.primaryOrange,
        ),
        StatCard(
          title: "Online",
          value: controller.stats['online_hours']!,
          icon: Icons.access_time,
          iconColor: AppColors.primaryBlue,
        ),
      ],
    ),
  );
}

Widget _buildSectionHeader(IconData icon, String title, Color color) {
  return Row(
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 8),
      Text(title, style: AppStyle.title.copyWith(color: AppColors.textPrimary)),
    ],
  );
}
