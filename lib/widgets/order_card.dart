import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../controllers/home_controller.dart';
import '../utils/map_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isActive;

  const OrderCard({super.key, required this.order, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = Get.find<HomeController>();

    if (!isActive) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          //boxShadow: AppStyle.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order['customer'] ?? 'Customer', style: AppStyle.title),
                  const SizedBox(height: 4),
                  Text(order['id'] ?? '', style: AppStyle.caption),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.doneBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Done",
                style: TextStyle(
                  color: AppColors.doneText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Obx(() {
      final isExpanded = homeController.expandedOrderIds.contains(order['id']);

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          //boxShadow: AppStyle.cardShadow,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  _buildStatusTag(order['status']),
                  const SizedBox(width: 12),
                  Text(
                    order['id'],
                    style: AppStyle.subtitle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (order['next_step_lat'] != null &&
                          order['next_step_lng'] != null) {
                        MapUtils.openMapWithCoords(
                          order['next_step_lat'],
                          order['next_step_lng'],
                        );
                      } else {
                        MapUtils.openMap(order['next_step']);
                      }
                    },
                    icon: const Icon(
                      Icons.near_me,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Navigate",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ), // vertical removed
                      minimumSize: Size.zero, // removes default min height
                      tapTargetSize: MaterialTapTargetSize
                          .shrinkWrap, // removes tap target padding
                    ),
                  ),
                ],
              ),
            ),
            // Content
            GestureDetector(
              onTap: () => homeController.toggleOrderExpansion(order['id']),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order['next_step'], style: AppStyle.title),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: isExpanded ? 0.5 : 0,
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress Dots
                    Row(
                      children: [
                        _buildDot(AppColors.primaryGreen),
                        _buildLine(Colors.grey.shade200),
                        _buildDot(
                          order['progress'] > 0
                              ? AppColors.primaryOrange
                              : Colors.grey.shade300,
                        ),
                        _buildLine(Colors.grey.shade200),
                        _buildDot(Colors.grey.shade200),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${(order['progress'] * 2).toInt()}/2 picked",
                      style: AppStyle.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded Section
            if (isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => MapUtils.openMap(order['next_step']),
                            child: _buildActionButton(
                              "Map",
                              Icons.map_outlined,
                              const Color(0xFFEFF6FF),
                              AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final stops = order['stops'] as List;
                              final stores = stops
                                  .where((s) => s['type'] == 'store')
                                  .toList();
                              final customer = stops.firstWhere(
                                (s) => s['type'] == 'customer',
                              );

                              MapUtils.openFullRoute(
                                waypoints: stores
                                    .map(
                                      (s) => {
                                        'lat': s['lat'] as double,
                                        'lng': s['lng'] as double,
                                      },
                                    )
                                    .toList(),
                                destination: {
                                  'lat': customer['lat'] as double,
                                  'lng': customer['lng'] as double,
                                },
                              );
                            },
                            child: _buildActionButton(
                              "Full Route",
                              Icons.route_outlined,
                              const Color(0xFFF0FDF4),
                              AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Stops List
                    ...(order['stops'] as List)
                        .map((stop) => _buildStopItem(stop))
                        .toList(),
                    const SizedBox(height: 10),
                    // Bottom Button (Only show Accept for Unassigned)
                    if (order['status'] == 'UNASSIGNED')
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            homeController.acceptOrder(order['delivery_id']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Accept",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color bg,
    Color color,
  ) {
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppStyle.title.copyWith(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStopItem(Map<String, dynamic> stop) {
    final HomeController homeController = Get.find<HomeController>();
    bool isPicked = stop['status'] == 'picked';
    bool isCustomer = stop['type'] == 'customer';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCustomer ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPicked
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : isCustomer
                  ? AppColors.primaryBlue.withOpacity(0.1)
                  : AppColors.primaryOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPicked
                  ? Icons
                        .check_circle // Tick icon for picked
                  : isCustomer
                  ? Icons.near_me_outlined
                  : Icons.storefront_outlined,
              size: 20,
              color: isPicked
                  ? AppColors.primaryGreen
                  : isCustomer
                  ? AppColors.primaryBlue
                  : AppColors.primaryOrange,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stop['name'],
                      style: AppStyle.title.copyWith(fontSize: 15),
                    ),
                    if (isPicked)
                      Text(
                        "₹${order['total_price'] ?? '0'}",
                        style: AppStyle.title.copyWith(
                          color: AppColors.primaryGreen,
                        ),
                      )
                    else if (!isCustomer && order['status'] == 'ASSIGNED')
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () {
                            homeController.pickupVendor(
                              order['delivery_id'],
                              stop['vendor_id'],
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Pick",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  stop['address'],
                  style: AppStyle.caption.copyWith(fontSize: 12),
                ),
                if (stop['items'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    stop['items'],
                    style: AppStyle.subtitle.copyWith(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                if (isPicked) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Picked at ${stop['time']}",
                    style: AppStyle.caption.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else if (!isCustomer) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      if (stop['lat'] != null && stop['lng'] != null) {
                        MapUtils.openMapWithCoords(stop['lat'], stop['lng']);
                      } else {
                        MapUtils.openMap(stop['address']);
                      }
                    },
                    child: _buildMiniButton(
                      "Directions",
                      Icons.near_me_outlined,
                    ),
                  ),
                ] else if (isCustomer) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final String phone = order['phone'] ?? '';
                              if (phone.isNotEmpty) {
                                final Uri launchUri = Uri(
                                  scheme: 'tel',
                                  path: phone,
                                );
                                await launchUrl(launchUri);
                              }
                            },
                            child: _buildMiniButton(
                              "Call",
                              Icons.phone_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (stop['lat'] != null && stop['lng'] != null) {
                                MapUtils.openMapWithCoords(
                                  stop['lat'],
                                  stop['lng'],
                                );
                              } else {
                                MapUtils.openMap(stop['address']);
                              }
                            },
                            child: _buildMiniButton(
                              "Directions",
                              Icons.near_me_outlined,
                            ),
                          ),
                        ],
                      ),
                      if (order['all_picked'] == true)
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () {
                              homeController.deliverOrder(order['delivery_id']);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Deliver",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniButton(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    Color bg = AppColors.pickingUpBg;
    Color text = AppColors.pickingUpText;
    if (status == 'Assigned') {
      bg = AppColors.assignedBg;
      text = AppColors.assignedText;
    } else if (status == 'New Order') {
      bg = AppColors.primaryBlue.withOpacity(0.1);
      text = AppColors.primaryBlue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildLine(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 30,
      height: 1.5,
      color: color,
    );
  }
}
