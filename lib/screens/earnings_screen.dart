import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../controllers/home_controller.dart';
import '../widgets/top_banner.dart';
import '../widgets/profile_header_widget.dart';
import '../widgets/order_shimmer.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopBanner(),
          const ProfileHeaderWidget(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEarningsHighlightCard(),
                  const SizedBox(height: 10),
                  Obx(
                    () =>
                        homeController.isLoading.value &&
                            homeController.rateSettings.isEmpty
                        ? const BigCardShimmer()
                        : _buildEarningRatesCard(homeController),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Today's Trips",
                    style: AppStyle.heading2.copyWith(
                      fontSize: 16,
                      color: AppColors.textPrimary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Obx(
                    () => homeController.isLoading.value && homeController.todaysTrips.isEmpty
                        ? Column(
                            children: List.generate(
                              3,
                              (index) => const ListShimmer(),
                            ),
                          )
                        : _buildTripsList(homeController),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsHighlightCard() {
    final HomeController homeController = Get.find<HomeController>();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => homeController.setEarningsPeriod('today'),
                child: Obx(
                  () => _buildCompactTab(
                    "Today",
                    homeController.selectedPeriod.value == 'today',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => homeController.setEarningsPeriod('this_week'),
                child: Obx(
                  () => _buildCompactTab(
                    "Week",
                    homeController.selectedPeriod.value == 'this_week',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => homeController.setEarningsPeriod('this_month'),
                child: Obx(
                  () => _buildCompactTab(
                    "Month",
                    homeController.selectedPeriod.value == 'this_month',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Total Earnings",
            style: AppStyle.subtitle.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Obx(
            () => homeController.isLoading.value
                ? const SizedBox(
                    height: 50,
                    child: Center(
                      child: CupertinoActivityIndicator(
                        color: Colors.white,
                        radius: 14,
                      ),
                    ),
                  )
                : Text(
                    homeController.earningsData['earnings']!,
                    style: AppStyle.heading1.copyWith(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem("Trips", homeController.earningsData['trips']!),
                _buildStatItem(
                  "Distance",
                  homeController.earningsData['distance']!,
                ),
                _buildStatItem("Tips", homeController.earningsData['tips']!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTab(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppStyle.subtitle.copyWith(
          color: isActive ? AppColors.primaryOrange : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppStyle.caption.copyWith(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppStyle.title.copyWith(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

Widget _buildEarningRatesCard(HomeController homeController) {
  final settings = homeController.rateSettings;
  final String baseFare = settings['baseFare']?.toString() ?? "0";
  final String perKmRate = settings['perKmRate']?.toString() ?? "0";
  final String bonus = settings['storePickupBonus']?.toString() ?? "0";
  final String surge = settings['peakHourSurge']?.toString() ?? "1.0";

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Your Earning Rates",
          style: AppStyle.subtitle.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildRateItem(
                "Base",
                "₹$baseFare",
                Icons.currency_rupee,
                Colors.green,
              ),
            ),
            Expanded(
              child: _buildRateItem(
                "Per Km",
                "₹$perKmRate",
                Icons.share_outlined,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildRateItem(
                "Store",
                "₹$bonus",
                Icons.store_outlined,
                Colors.orange,
              ),
            ),
            Expanded(
              child: _buildRateItem(
                "Surge",
                "${surge}x",
                Icons.bolt,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildRateItem(String label, String value, IconData icon, Color color) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppStyle.caption.copyWith(
              color: AppColors.textLight,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppStyle.title.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildTripsList(HomeController homeController) {
  final trips = homeController.todaysTrips;

  if (trips.isEmpty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No trips found for today",
            style: AppStyle.caption.copyWith(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  return Column(
    children: trips.map((trip) {
      final String name = trip['customer'] ?? 'Customer';
      final String distance = trip['distance']?.toString() ?? '0';
      final String stores = trip['total_stores']?.toString() ?? '0';
      final String amount = trip['earnings']?.toString() ?? '0';

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppStyle.title.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$distance km | $stores store",
                    style: AppStyle.caption.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              "₹$amount",
              style: AppStyle.title.copyWith(
                color: AppColors.primaryGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}
