import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../controllers/home_controller.dart';
import '../utils/map_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'invoice_sheet.dart';

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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      order['id'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.subtitle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            order['next_step'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyle.title,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                        _buildDot(
                          order['all_picked'] == true
                              ? AppColors.primaryGreen
                              : Colors.grey.shade200,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${order['picked_count'] ?? 0}/${order['total_stores'] ?? 0} picked",
                      style: AppStyle.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PaymentBadge(
                      isCod: order['is_cod'] == true,
                      isPaid: order['is_paid'] == true,
                      total: order['total_price'] ?? 0,
                    ),
                  ],
                ),
              ),
            ),
            // Next step once every store is picked — visible without expanding the card
            if (order['all_picked'] == true && _canDeliver(order['status']))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Obx(() {
                  final busy = homeController.isBusy(order['delivery_id']);
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : () => _confirmDelivery(context, order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.done_all_rounded, color: Colors.white),
                      label: Text(
                        busy ? 'Saving…' : 'Mark delivered',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => showInvoiceSheet(context, order),
                            child: _buildActionButton(
                              "Invoice",
                              Icons.receipt_long_outlined,
                              const Color(0xFFF1F5F9),
                              AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                              "Route",
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
                      Obx(() {
                        final busy = homeController.isBusy(order['delivery_id']);
                        final online = homeController.isOnline.value;
                        return SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: busy || !online ? null : () => homeController.acceptOrder(order['delivery_id']),
                            icon: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Icon(online ? Icons.check_circle_outline : Icons.wifi_off_rounded, color: Colors.white),
                            label: Text(
                              busy ? 'Accepting…' : (online ? 'Accept order' : 'Go online to accept'),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }),
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
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.title.copyWith(color: color, fontSize: 13),
            ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        stop['name'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyle.title.copyWith(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isPicked)
                      Text(
                        "₹${order['total_price'] ?? '0'}",
                        style: AppStyle.title.copyWith(
                          color: AppColors.primaryGreen,
                        ),
                      )
                    else if (!isCustomer && order['status'] == 'ASSIGNED')
                      Obx(() {
                        final busy = homeController.isBusy('${order['delivery_id']}:${stop['vendor_id']}');
                        return SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: busy
                                ? null
                                : () => homeController.pickupVendor(order['delivery_id'], stop['vendor_id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: busy
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Picked up', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        );
                      }),
                  ],
                ),
                Text(
                  stop['address'] ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
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

  static bool _canDeliver(String? status) => status == 'PICKED_UP' || status == 'IN_TRANSIT';

  Widget _buildStatusTag(String status) {
    Color bg = AppColors.pickingUpBg;
    Color text = AppColors.pickingUpText;
    String label = status;
    switch (status) {
      case 'UNASSIGNED':
        label = 'New Order';
        bg = AppColors.primaryBlue.withOpacity(0.1);
        text = AppColors.primaryBlue;
      case 'ASSIGNED':
        label = 'Picking up';
      case 'PICKED_UP':
      case 'IN_TRANSIT':
        label = 'Out for delivery';
        bg = AppColors.assignedBg;
        text = AppColors.assignedText;
      case 'DELIVERED':
        label = 'Delivered';
        bg = AppColors.doneBg;
        text = AppColors.doneText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
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


/// Ask before marking delivered; for cash orders remind the partner to collect the amount.
Future<void> _confirmDelivery(BuildContext context, Map<String, dynamic> order) async {
  final bool isCod = order['is_cod'] == true;
  final amount = order['total_price'];
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Mark as delivered?'),
      content: Text(
        isCod
            ? 'This is a Cash on Delivery order. Collect ₹${amount ?? 0} from ${order['customer'] ?? 'the customer'} before confirming.'
            : 'Confirm that order #${order['id']} was handed to ${order['customer'] ?? 'the customer'}.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not yet')),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(isCod ? 'Cash collected' : 'Delivered'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    Get.find<HomeController>().deliverOrder(order['delivery_id']);
  }
}
