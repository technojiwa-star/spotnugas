import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class MobileFrame extends StatelessWidget {
  final Widget child;

  const MobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If the viewport width is typical mobile phone, render full screen
        if (constraints.maxWidth <= 500) {
          return child;
        }

        // On desktop/tablet/web screen, render a beautiful 390 x 844 iPhone-like frame with aspect ratio
        final targetHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight > 880
                  ? 844.0
                  : constraints.maxHeight * 0.96)
            : 844.0;
        final targetWidth = (targetHeight * (390.0 / 844.0)).clamp(
          320.0,
          420.0,
        );

        return Scaffold(
          backgroundColor: const Color(0xFF1B2321),
          body: Center(
            child: Container(
              width: targetWidth,
              height: targetHeight,
              decoration: BoxDecoration(
                color: AppColors.lightCreamBackground,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: const Color(0xFF333E3A), width: 4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
