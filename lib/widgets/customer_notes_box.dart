import 'package:flutter/material.dart';

import '../utils/app_style.dart';

/// Highlighted "Customer instructions" box (gate code, landmark…). Renders nothing when empty.
class CustomerNotesBox extends StatelessWidget {
  final String? notes;
  final EdgeInsetsGeometry margin;
  const CustomerNotesBox({super.key, required this.notes, this.margin = EdgeInsets.zero});

  static const _bg = Color(0xFFEEF2FF);
  static const _border = Color(0xFFC7D2FE);
  static const _fg = Color(0xFF3730A3);

  @override
  Widget build(BuildContext context) {
    final text = notes?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: margin,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.sticky_note_2_outlined, size: 20, color: _fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer instructions',
                  style: AppStyle.caption.copyWith(color: _fg, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                ),
                const SizedBox(height: 3),
                Text(text, style: AppStyle.body.copyWith(color: const Color(0xFF1E1B4B), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
