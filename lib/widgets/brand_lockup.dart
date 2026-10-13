import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';

/// Dadchico logo with "DELIVERY" underneath — the app's brand mark.
class BrandLockup extends StatelessWidget {
  final double logoHeight;
  final bool onDark;
  final CrossAxisAlignment alignment;

  const BrandLockup({
    super.key,
    this.logoHeight = 40,
    this.onDark = false,
    this.alignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : AppColors.primaryGreen;
    return Semantics(
      label: 'Dadchico Delivery',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment,
        children: [
          Image.asset(
            onDark ? 'assets/brand/logo_white.png' : 'assets/brand/logo.png',
            height: logoHeight,
          ),
          SizedBox(height: logoHeight * 0.12),
          Text(
            'DELIVERY',
            style: GoogleFonts.inter(
              fontSize: (logoHeight * 0.3).clamp(9, 18).toDouble(),
              fontWeight: FontWeight.w800,
              letterSpacing: logoHeight * 0.12,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
