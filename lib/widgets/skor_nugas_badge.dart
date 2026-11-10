import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SkorNugasBadge extends StatelessWidget {
  final double score;
  final bool isLarge;

  const SkorNugasBadge({super.key, required this.score, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    if (isLarge) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryTealSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryTeal.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.laptop_chromebook_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        score > 0 ? score.toStringAsFixed(1) : '-',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryTealDark,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        score > 0 ? ' / 10' : ' (Belum dinilai)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    score > 0
                        ? 'Skor Nugas • Sangat Direkomendasikan'
                        : 'Skor Nugas • Belum Dinilai',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryTeal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Compact badge for place cards
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.laptop_mac_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            score > 0 ? score.toStringAsFixed(1) : '-',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
