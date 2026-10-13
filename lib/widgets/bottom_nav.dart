import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../controllers/home_controller.dart';

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = Get.find();

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
        boxShadow: AppStyle.cardShadow,
      ),
      child: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              0,
              "Orders",
              CupertinoIcons.doc_text,
              CupertinoIcons.doc_text_fill,
              homeController,
            ),
            _buildNavItem(
              1,
              "Earnings",
              CupertinoIcons.creditcard,
              CupertinoIcons.creditcard_fill,
              homeController,
            ),
            _buildNavItem(
              2,
              "Profile",
              CupertinoIcons.person,
              CupertinoIcons.person_fill,
              homeController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String label,
    IconData icon,
    IconData activeIcon,
    HomeController controller,
  ) {
    bool isSelected = controller.selectedTab.value == index;
    return GestureDetector(
      onTap: () => controller.changeTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                border: const Border(
                  top: BorderSide(color: AppColors.primaryOrange, width: 2),
                ),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primaryOrange : AppColors.textLight,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppStyle.caption.copyWith(
                color: isSelected
                    ? AppColors.primaryOrange
                    : AppColors.textLight,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
