import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';

/// "Next: Fresh Mart · about 12 min · 3.4 km" from the latest location response.
/// Rebuilds on its own (not the whole card) and eases in/out instead of jumping.
class LiveEtaLine extends StatelessWidget {
  final String deliveryId;
  const LiveEtaLine({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HomeController>();
    return Obx(() {
      final eta = c.location.etas[deliveryId];
      return AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topLeft,
        child: eta == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previous, ?current],
                          ),
                          child: Text(
                            eta.label,
                            key: ValueKey(eta.label),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyle.subtitle.copyWith(
                              color: AppColors.primaryGreenDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
    });
  }
}
