import 'package:flutter/material.dart';
import '../models/delivery_model.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';

String _inr(num v) => '₹${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

/// Payment type pill: "Cash on delivery · Collect ₹X", "Cash on delivery · Collected ₹X" or "Paid online".
class PaymentBadge extends StatelessWidget {
  final bool isCod;
  final bool isPaid;
  final num total;
  const PaymentBadge({super.key, required this.isCod, required this.isPaid, required this.total});

  @override
  Widget build(BuildContext context) {
    final collect = isCod && !isPaid;
    final bg = collect ? const Color(0xFFFEF3C7) : AppColors.doneBg;
    final fg = collect ? const Color(0xFF92400E) : AppColors.doneText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(collect ? Icons.payments_outlined : Icons.verified_outlined, size: 16, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isCod
                  ? 'Cash on delivery · ${isPaid ? 'Collected' : 'Collect'} ${_inr(total)}'
                  : 'Paid online · ${_inr(total)}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with the full order bill for the driver.
Future<void> showInvoiceSheet(BuildContext context, Map<String, dynamic> order) {
  final List<OrderLineItem> items = (order['line_items'] as List?)?.cast<OrderLineItem>() ?? const [];
  final num subtotal = order['subtotal'] ?? 0;
  final num shipping = order['shipping'] ?? 0;
  final num discount = order['discount'] ?? 0;
  final num total = order['total_price'] ?? 0;
  final bool isCod = order['is_cod'] == true;
  final bool isPaid = order['is_paid'] == true;
  final DateTime? placedAt = order['placed_at'] as DateTime?;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Image.asset('assets/brand/logo_mark.png', width: 36, height: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order invoice', style: AppStyle.title),
                      Text(
                        '${order['id'] ?? ''}${placedAt != null ? ' · ${placedAt.toLocal().day}/${placedAt.toLocal().month}/${placedAt.toLocal().year}' : ''}',
                        style: AppStyle.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PaymentBadge(isCod: isCod, isPaid: isPaid, total: total),
            const SizedBox(height: 16),
            Text('Deliver to', style: AppStyle.caption),
            const SizedBox(height: 2),
            Text('${order['customer'] ?? 'Customer'}', style: AppStyle.title.copyWith(fontSize: 15)),
            if ((order['address'] ?? '').toString().isNotEmpty)
              Text('${order['address']}', style: AppStyle.caption.copyWith(fontSize: 12.5)),
            const Divider(height: 28),
            if (items.isEmpty)
              Text('Item details are not available for this order.', style: AppStyle.caption)
            else
              ...items.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.name, style: AppStyle.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 14)),
                            Text(
                              '${i.variant.isNotEmpty ? '${i.variant} · ' : ''}${i.quantity} × ${_inr(i.price)}',
                              style: AppStyle.caption.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(_inr(i.subtotal), style: AppStyle.title.copyWith(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            const Divider(height: 24),
            _row('Items total', _inr(subtotal)),
            if (discount > 0) _row('Discount', '− ${_inr(discount)}'),
            _row('Delivery fee', shipping > 0 ? _inr(shipping) : 'Free'),
            const SizedBox(height: 6),
            _row(isCod && !isPaid ? 'To collect' : isCod ? 'Total collected' : 'Total paid', _inr(total), bold: true),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold ? AppStyle.title.copyWith(fontSize: 16) : AppStyle.subtitle.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(value, style: bold ? AppStyle.title.copyWith(fontSize: 16) : AppStyle.subtitle.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
