import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/home_controller.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../widgets/order_card.dart';
import '../widgets/order_shimmer.dart';
import '../widgets/profile_header_widget.dart';
import '../widgets/stat_card.dart';
import '../widgets/top_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController c = Get.find<HomeController>();

    return Column(
      children: [
        const TopBanner(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: () => Future.wait([c.fetchOrders(silent: true), c.fetchProfileSummary(period: 'today')]),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: ProfileHeaderWidget()),
                SliverToBoxAdapter(child: _OfflineNotice(controller: c)),
                SliverToBoxAdapter(child: _Stats(controller: c)),
                SliverPersistentHeader(pinned: true, delegate: _TabsHeader(controller: c)),
                Obx(() => _OrderList(controller: c, tab: c.ordersTab.value)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  final HomeController controller;
  const _OfflineNotice({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isOnline.value) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.power_settings_new_rounded, color: AppColors.primaryOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You're offline. Go online to receive and accept new orders.",
                style: AppStyle.body.copyWith(color: const Color(0xFF9A3412)),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: controller.togglingOnline.value ? null : () => controller.toggleOnline(true),
              child: const Text('Go online'),
            ),
          ],
        ),
      );
    });
  }
}

class _Stats extends StatelessWidget {
  final HomeController controller;
  const _Stats({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Obx(
        () => Row(
          children: [
            Expanded(
              child: StatCard(
                title: "Today's earnings",
                value: controller.stats['earnings'] ?? '₹0',
                icon: Icons.currency_rupee_rounded,
                iconColor: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                title: 'Trips today',
                value: controller.stats['trips'] ?? '0',
                icon: Icons.alt_route_rounded,
                iconColor: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                title: 'Online',
                value: controller.stats['online_hours'] ?? '0h',
                icon: Icons.schedule_rounded,
                iconColor: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned "New / Active / Done" segmented control.
class _TabsHeader extends SliverPersistentHeaderDelegate {
  final HomeController controller;
  _TabsHeader({required this.controller});

  @override
  double get minExtent => 68;
  @override
  double get maxExtent => 68;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Obx(() {
        final tabs = [
          ('New', controller.unassignedDeliveries.length),
          ('Active', controller.activeDeliveries.length),
          ('Done today', controller.todaysFinished.length),
        ];
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final selected = controller.ordersTab.value == i;
              final (label, count) = tabs[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controller.ordersTab.value = i,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: selected
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyle.subtitle.copyWith(
                              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              color: i == 0 ? AppColors.primaryGreen : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: i == 0 ? Colors.white : AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  @override
  bool shouldRebuild(covariant _TabsHeader oldDelegate) => false;
}

class _OrderList extends StatelessWidget {
  final HomeController controller;
  final int tab;
  const _OrderList({required this.controller, required this.tab});

  // Obx must read the order lists itself — the parent Obx only tracks the selected tab,
  // so without this the list only refreshed when scrolling rebuilt it.
  @override
  Widget build(BuildContext context) => Obx(() => _buildList(context));

  Widget _buildList(BuildContext context) {
    if (controller.ordersLoading.value) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        sliver: SliverList.list(children: const [OrderShimmer(), OrderShimmer()]),
      );
    }

    final orders = switch (tab) {
      0 => controller.unassignedDeliveries,
      1 => controller.activeDeliveries,
      _ => controller.todaysFinished,
    };

    if (orders.isEmpty) {
      if (controller.ordersError.value.isNotEmpty) {
        return SliverToBoxAdapter(
          child: _EmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load orders",
            message: controller.ordersError.value,
            actionLabel: 'Try again',
            onAction: () => controller.fetchOrders(),
          ),
        );
      }
      final (icon, title, message) = switch (tab) {
        0 => controller.isOnline.value
            ? (
                Icons.notifications_active_outlined,
                'Waiting for new orders',
                "We'll alert you as soon as an order from your stores is ready. Keep the app open or notifications on.",
              )
            : (Icons.power_settings_new_rounded, "You're offline", 'Go online to start receiving delivery requests.'),
        1 => (Icons.local_shipping_outlined, 'No active deliveries', 'Accepted orders show up here with pickup and drop steps.'),
        _ => (Icons.emoji_events_outlined, 'No deliveries yet today', 'Completed deliveries and earnings will appear here.'),
      };
      return SliverToBoxAdapter(child: _EmptyState(icon: icon, title: title, message: message));
    }

    final updated = controller.lastUpdated.value;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      sliver: SliverList.builder(
        itemCount: orders.length + 1,
        itemBuilder: (context, i) {
          if (i == orders.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  updated == null ? 'Pull down to refresh' : 'Updated ${DateFormat('h:mm a').format(updated)} · pull to refresh',
                  style: AppStyle.caption,
                ),
              ),
            );
          }
          return OrderCard(order: orders[i], isActive: tab != 2);
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: AppColors.primaryTint, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: AppColors.primaryGreen),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppStyle.title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: AppStyle.subtitle, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh_rounded), label: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
