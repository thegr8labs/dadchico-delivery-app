import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import 'brand_lockup.dart';

/// Green app header with the Dadchico Delivery lockup and the online/offline switch.
class TopBanner extends StatelessWidget {
  const TopBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.find<HomeController>();

    return Obx(() {
      final online = controller.isOnline.value;
      final toggling = controller.togglingOnline.value;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 14, left: 20, right: 12),
        color: online ? AppColors.primaryGreen : const Color(0xFF475569),
        child: Row(
          children: [
            const BrandLockup(logoHeight: 22, onDark: true, alignment: CrossAxisAlignment.start),
            const Spacer(),
            Material(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: toggling ? null : () => controller.toggleOnline(!online),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        online ? 'Online' : 'Offline',
                        style: AppStyle.subtitle.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 26,
                        child: toggling
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                              )
                            : Switch(
                                value: online,
                                onChanged: (v) => controller.toggleOnline(v),
                                activeThumbColor: AppColors.primaryGreen,
                                activeTrackColor: Colors.white,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
