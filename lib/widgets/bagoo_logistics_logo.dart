import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BagooLogisticsMark extends StatelessWidget {
  final double size;
  final double borderRadius;

  const BagooLogisticsMark({super.key, this.size = 36, this.borderRadius = 9});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'BagooPH Logistics',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.asset(
              'assets/branding/bagoo-logistics-mark.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => ColoredBox(
                color: AppColors.primary,
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: size * 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BagooLogisticsBrandHeader extends StatelessWidget {
  final double markSize;

  const BagooLogisticsBrandHeader({super.key, this.markSize = 56});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: BagooLogisticsMark(size: markSize, borderRadius: 14),
        ),
        const SizedBox(height: 12),
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Bagoo'),
              TextSpan(
                text: 'PH',
                style: TextStyle(color: AppColors.primary),
              ),
              TextSpan(
                text: ' Logistics',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
