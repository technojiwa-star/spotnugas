import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class FacilityChip extends StatelessWidget {
  final String label;
  final bool isCompact;

  const FacilityChip({super.key, required this.label, this.isCompact = false});

  IconData _getIcon(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('wi-fi') ||
        lower.contains('wifi') ||
        lower.contains('internet')) {
      return Icons.wifi_rounded;
    } else if (lower.contains('colokan') ||
        lower.contains('listrik') ||
        lower.contains('power')) {
      return Icons.power_rounded;
    } else if (lower.contains('ac') || lower.contains('dingin')) {
      return Icons.ac_unit_rounded;
    } else if (lower.contains('musala') ||
        lower.contains('mushola') ||
        lower.contains('ibadah')) {
      return Icons.mosque_rounded;
    } else if (lower.contains('parkir')) {
      return Icons.local_parking_rounded;
    } else if (lower.contains('kelompok') ||
        lower.contains('meeting') ||
        lower.contains('tim')) {
      return Icons.groups_rounded;
    } else if (lower.contains('hening') ||
        lower.contains('tenang') ||
        lower.contains('fokus')) {
      return Icons.volume_off_rounded;
    } else if (lower.contains('outdoor') || lower.contains('taman')) {
      return Icons.deck_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon(label);

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.lightCream,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primaryTealDark),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lightCreamBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primaryTeal),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
