import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/home_controller.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../utils/map_utils.dart';
import 'customer_notes_box.dart';
import 'invoice_sheet.dart';
import 'live_eta_line.dart';

String _inr(num v) => '₹${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

/// One delivery. New and active orders show the next stop, cash to collect, customer
/// instructions, Call / Navigate and a single primary action for the current stage:
/// Accept → "Picked up at (store)" → Mark delivered. Stops, invoice and full route are
/// under "Order details". Finished orders ([isActive] false) get a compact row.
class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isActive;

  const OrderCard({super.key, required this.order, this.isActive = true});

  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    if (!isActive) return _FinishedCard(order: order);
    final HomeController c = Get.find<HomeController>();
    final bool isCancelled = _isCancelled(order);
    final String status = order['status'] ?? '';
    final bool isNew = status == 'UNASSIGNED';
    final String deliveryId = order['delivery_id'] ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: isCancelled ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(order: order),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NextStop(order: order),
                if (!isNew && !isCancelled) LiveEtaLine(deliveryId: deliveryId),
                const SizedBox(height: 12),
                if (isCancelled) _cancelReason(order) else _CashBox(order: order),
                CustomerNotesBox(notes: order['customer_notes'], margin: const EdgeInsets.only(top: 10)),
                if (!isCancelled) ...[
                  const SizedBox(height: 14),
                  _QuickActions(order: order),
                  const SizedBox(height: 10),
                  _PrimaryAction(order: order),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          Obx(() {
            final expanded = c.expandedOrderIds.contains(order['id']);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => c.toggleOrderExpansion(order['id']),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          expanded ? 'Hide details' : 'Order details · ${(order['stops'] as List?)?.length ?? 0} stops',
                          style: AppStyle.subtitle.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: expanded ? 0.5 : 0,
                          child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: expanded ? _Details(order: order) : const SizedBox(width: double.infinity),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

bool _canDeliver(String? status) => status == 'PICKED_UP' || status == 'IN_TRANSIT';

bool _isCancelled(Map<String, dynamic> order) => order['status'] == 'CANCELLED';

bool _hasCoords(Object? lat, Object? lng) => lat is num && lng is num && !(lat == 0 && lng == 0);

/// Open turn-by-turn in Google Maps (free deep link), falling back to an address search.
Future<void> _navigate(Object? lat, Object? lng, String? address) async {
  try {
    if (_hasCoords(lat, lng)) {
      await MapUtils.openMapWithCoords((lat as num).toDouble(), (lng as num).toDouble());
    } else if ((address ?? '').isNotEmpty) {
      await MapUtils.openMap(address!);
    }
  } catch (_) {
    _snack("Couldn't open maps", 'Install Google Maps or try again.');
  }
}

Future<void> _call(String? phone) async {
  final p = (phone ?? '').trim();
  if (p.isEmpty) return;
  try {
    await launchUrl(Uri(scheme: 'tel', path: p));
  } catch (_) {
    _snack("Couldn't start the call", p);
  }
}

void _snack(String title, String message) {
  if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
  Get.snackbar(title, message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.navy,
      colorText: Colors.white);
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> order;
  const _Header({required this.order});

  @override
  Widget build(BuildContext context) {
    final num earnings = order['earnings'] ?? 0;
    final num km = order['distance'] ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          _StatusTag(status: order['status'] ?? ''),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '#${order['id'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.caption.copyWith(fontSize: 13),
            ),
          ),
          if (km > 0) ...[
            Text('${km % 1 == 0 ? km.toInt() : km.toStringAsFixed(1)} km', style: AppStyle.caption.copyWith(fontSize: 13)),
            const SizedBox(width: 10),
          ],
          if (earnings > 0)
            Text(
              'Earn ${_inr(earnings)}',
              style: AppStyle.subtitle.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

class _NextStop extends StatelessWidget {
  final Map<String, dynamic> order;
  const _NextStop({required this.order});

  @override
  Widget build(BuildContext context) {
    final isStore = order['next_type'] == 'store';
    final int total = order['total_stores'] ?? 0;
    final int picked = order['picked_count'] ?? 0;
    final String label = _isCancelled(order)
        ? 'ORDER CANCELLED'
        : isStore
            ? (total > 1 ? 'PICKUP ${picked + 1} OF $total' : 'PICKUP')
            : 'DELIVER TO';
    final String address = (order['next_address'] ?? '').toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isStore ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isStore ? Icons.storefront_rounded : Icons.home_rounded,
            color: isStore ? AppColors.primaryOrange : AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppStyle.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
              ),
              const SizedBox(height: 2),
              Text(
                (order['next_name'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyle.heading2.copyWith(fontWeight: FontWeight.w700),
              ),
              if (address.isNotEmpty)
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.caption.copyWith(fontSize: 13, height: 1.3),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cash to collect (COD, unpaid) stands out; prepaid orders get a quiet note.
class _CashBox extends StatelessWidget {
  final Map<String, dynamic> order;
  const _CashBox({required this.order});

  @override
  Widget build(BuildContext context) {
    final bool isCod = order['is_cod'] == true;
    final bool isPaid = order['is_paid'] == true;
    final num total = order['total_price'] ?? 0;
    if (!isCod || isPaid) {
      return Row(
        children: [
          const Icon(Icons.verified_rounded, size: 18, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isCod ? 'Cash collected · ${_inr(total)}' : 'Paid online · no cash to collect',
              style: AppStyle.subtitle.copyWith(color: AppColors.doneText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_rounded, color: Color(0xFF92400E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Collect cash',
              style: AppStyle.title.copyWith(color: const Color(0xFF92400E)),
            ),
          ),
          Text(
            _inr(total),
            style: AppStyle.heading1.copyWith(fontSize: 22, color: const Color(0xFF78350F)),
          ),
        ],
      ),
    );
  }
}

/// One-tap Call customer + Navigate to the next stop. 48 px high for gloves on a bike.
class _QuickActions extends StatelessWidget {
  final Map<String, dynamic> order;
  const _QuickActions({required this.order});

  @override
  Widget build(BuildContext context) {
    final isNew = order['status'] == 'UNASSIGNED';
    final phone = (order['phone'] ?? '').toString();
    return Row(
      children: [
        // The customer's number is only needed once the order is yours.
        if (!isNew && phone.isNotEmpty) ...[
          Expanded(
            child: _BigButton(
              label: 'Call customer',
              icon: Icons.call_rounded,
              color: AppColors.primaryGreen,
              outlined: true,
              onTap: () => _call(phone),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: _BigButton(
            label: 'Navigate',
            icon: Icons.navigation_rounded,
            color: AppColors.primaryBlue,
            outlined: isNew,
            onTap: () => _navigate(order['next_step_lat'], order['next_step_lng'], order['next_address']),
          ),
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback? onTap;
  final double height;
  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    this.outlined = false,
    this.onTap,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ],
    );
    return SizedBox(
      height: height,
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.45), width: 1.4),
                shape: shape,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: child,
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: shape,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: child,
            ),
    );
  }
}

/// The one thing to do next. Fixed height, so the spinner never shifts the layout.
class _PrimaryAction extends StatelessWidget {
  final Map<String, dynamic> order;
  const _PrimaryAction({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HomeController>();
    final String status = order['status'] ?? '';
    final String id = order['delivery_id'] ?? '';
    final String? vendorId = order['next_vendor_id'];

    if (status == 'UNASSIGNED') {
      return Obx(() {
        final busy = c.isBusy(id);
        final online = c.isOnline.value;
        return _bar(
          label: busy ? 'Accepting…' : (online ? 'Accept order' : 'Go online to accept'),
          icon: online ? Icons.check_circle_rounded : Icons.wifi_off_rounded,
          busy: busy,
          onTap: busy || !online ? null : () => c.acceptOrder(id),
        );
      });
    }
    if (status == 'ASSIGNED' && order['next_type'] == 'store' && vendorId != null) {
      return Obx(() {
        final busy = c.isBusy('$id:$vendorId');
        return _bar(
          label: busy ? 'Saving…' : 'Picked up at ${order['next_name']}',
          icon: Icons.inventory_2_rounded,
          color: AppColors.primaryOrange,
          busy: busy,
          onTap: busy ? null : () => c.pickupVendor(id, vendorId),
        );
      });
    }
    if (order['all_picked'] == true && _canDeliver(status)) {
      return Obx(() {
        final busy = c.isBusy(id);
        return _bar(
          label: busy ? 'Saving…' : 'Mark delivered',
          icon: Icons.done_all_rounded,
          busy: busy,
          onTap: busy ? null : () => _confirmDelivery(context, order),
        );
      });
    }
    return const SizedBox.shrink();
  }

  Widget _bar({
    required String label,
    required IconData icon,
    required bool busy,
    required VoidCallback? onTap,
    Color color = AppColors.primaryGreen,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                    )
                  : Icon(icon, size: 22),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every stop, plus the invoice and the full route in Google Maps.
class _Details extends StatelessWidget {
  final Map<String, dynamic> order;
  const _Details({required this.order});

  @override
  Widget build(BuildContext context) {
    final stops = ((order['stops'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final isCancelled = _isCancelled(order);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stops.length; i++) _StopTile(order: order, stop: stops[i], last: i == stops.length - 1),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _BigButton(
                  label: 'Invoice',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.textPrimary,
                  outlined: true,
                  height: 44,
                  onTap: () => showInvoiceSheet(context, order),
                ),
              ),
              if (!isCancelled) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _BigButton(
                    label: 'Full route',
                    icon: Icons.route_rounded,
                    color: AppColors.primaryGreen,
                    outlined: true,
                    height: 44,
                    onTap: () => _openFullRoute(stops),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _openFullRoute(List<Map<String, dynamic>> stops) async {
    final stores = stops.where((s) => s['type'] == 'store' && _hasCoords(s['lat'], s['lng']));
    final customer = stops.where((s) => s['type'] == 'customer').firstOrNull;
    if (customer == null || !_hasCoords(customer['lat'], customer['lng'])) {
      return _navigate(null, null, customer?['address']);
    }
    try {
      await MapUtils.openFullRoute(
        waypoints: [
          for (final s in stores) {'lat': (s['lat'] as num).toDouble(), 'lng': (s['lng'] as num).toDouble()},
        ],
        destination: {'lat': (customer['lat'] as num).toDouble(), 'lng': (customer['lng'] as num).toDouble()},
      );
    } catch (_) {
      _snack("Couldn't open maps", 'Install Google Maps or try again.');
    }
  }
}

class _StopTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> stop;
  final bool last;
  const _StopTile({required this.order, required this.stop, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HomeController>();
    final isCustomer = stop['type'] == 'customer';
    final isPicked = stop['status'] == 'picked';
    final isCancelled = _isCancelled(order);
    final canPick = !isCustomer && !isPicked && order['status'] == 'ASSIGNED' && !isCancelled;
    final color = isPicked
        ? AppColors.primaryGreen
        : isCustomer
            ? AppColors.primaryBlue
            : AppColors.primaryOrange;
    final items = (stop['items'] ?? '').toString();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(
                    isPicked ? Icons.check_rounded : (isCustomer ? Icons.home_rounded : Icons.storefront_rounded),
                    size: 15,
                    color: color,
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: const Color(0xFFE2E8F0))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (stop['name'] ?? '').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyle.title.copyWith(fontSize: 15),
                        ),
                      ),
                      if (isPicked)
                        Text('Picked up',
                            style: AppStyle.caption.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if ((stop['address'] ?? '').toString().isNotEmpty)
                    Text(
                      stop['address'],
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.caption.copyWith(fontSize: 12.5),
                    ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(items, style: AppStyle.subtitle.copyWith(fontSize: 13, color: AppColors.textPrimary)),
                  ],
                  if (!isCancelled && !isPicked) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (canPick)
                          Obx(() {
                            final key = '${order['delivery_id']}:${stop['vendor_id']}';
                            final busy = c.isBusy(key);
                            return _chipButton(
                              busy ? 'Saving…' : 'Picked up',
                              Icons.inventory_2_rounded,
                              AppColors.primaryOrange,
                              filled: true,
                              onTap: busy ? null : () => c.pickupVendor(order['delivery_id'], stop['vendor_id']),
                            );
                          }),
                        if (isCustomer && order['status'] != 'UNASSIGNED' && (order['phone'] ?? '').toString().isNotEmpty)
                          _chipButton('Call', Icons.call_rounded, AppColors.primaryGreen, onTap: () => _call(order['phone'])),
                        _chipButton(
                          'Directions',
                          Icons.near_me_rounded,
                          AppColors.primaryBlue,
                          onTap: () => _navigate(stop['lat'], stop['lng'], stop['address']),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipButton(String label, IconData icon, Color color, {bool filled = false, VoidCallback? onTap}) {
    return SizedBox(
      height: 40,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        style: TextButton.styleFrom(
          foregroundColor: filled ? Colors.white : color,
          backgroundColor: filled ? color : color.withValues(alpha: 0.08),
          disabledForegroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

/// Delivered / cancelled orders in "Done today".
class _FinishedCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _FinishedCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isCancelled = _isCancelled(order);
    final num earnings = order['earnings'] ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showInvoiceSheet(context, order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order['customer'] ?? 'Customer', style: AppStyle.title),
                    const SizedBox(height: 2),
                    Text('#${order['id'] ?? ''}', style: AppStyle.caption),
                    if (isCancelled) ...[
                      const SizedBox(height: 8),
                      _cancelReason(order),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusTag(status: isCancelled ? 'CANCELLED' : 'DELIVERED'),
                  if (!isCancelled && earnings > 0) ...[
                    const SizedBox(height: 6),
                    Text(_inr(earnings), style: AppStyle.title.copyWith(color: AppColors.primaryGreen)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red "Order cancelled · reason" note shown instead of payment / actions.
Widget _cancelReason(Map<String, dynamic> order) {
  final reason = (order['cancel_reason'] ?? '').toString().trim();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: AppColors.cancelledBg, borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cancel_outlined, size: 16, color: AppColors.cancelledText),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            reason.isNotEmpty ? 'Order cancelled · $reason' : 'Order cancelled · no action needed',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.cancelledText, fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}

class _StatusTag extends StatelessWidget {
  final String status;
  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    var (label, bg, fg) = (status, AppColors.pickingUpBg, AppColors.pickingUpText);
    switch (status) {
      case 'UNASSIGNED':
        (label, bg, fg) = ('New order', AppColors.primaryBlue.withValues(alpha: 0.1), AppColors.primaryBlue);
      case 'ASSIGNED':
        label = 'Picking up';
      case 'PICKED_UP':
      case 'IN_TRANSIT':
        (label, bg, fg) = ('Out for delivery', AppColors.assignedBg, AppColors.assignedText);
      case 'DELIVERED':
        (label, bg, fg) = ('Delivered', AppColors.doneBg, AppColors.doneText);
      case 'CANCELLED':
        (label, bg, fg) = ('Cancelled', AppColors.cancelledBg, AppColors.cancelledText);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Ask before marking delivered; for cash orders remind the partner to collect the amount.
Future<void> _confirmDelivery(BuildContext context, Map<String, dynamic> order) async {
  final bool isCod = order['is_cod'] == true && order['is_paid'] != true;
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
