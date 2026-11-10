import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../constants/app_location.dart';
import '../models/place_types.dart';
import '../providers/location_provider.dart';
import 'main_navigation_screen.dart';

class LocationPermissionScreen extends ConsumerWidget {
  const LocationPermissionScreen({super.key});

  void _proceedToMain(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
    );
  }

  void _showManualLocationSheet(BuildContext context, WidgetRef ref) {
    final presets = <(String, String, GeoCoordinates)>[
      (
        AppLocation.defaultJakartaLabel,
        'Area Senopati, Kuningan & Blok M',
        AppLocation.defaultJakarta,
      ),
      (
        AppLocation.bandungLabel,
        'Area Dago, Braga & Dipatiukur',
        AppLocation.bandung,
      ),
      (AppLocation.depokLabel, 'Area Margonda & Kampus UI', AppLocation.depok),
      (
        AppLocation.mockYogyakartaLabel,
        'Area Kampus UGM & Kaliurang (Mode Demo)',
        AppLocation.mockYogyakartaOrigin,
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Pilih Lokasi Manual',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pilih kota atau area nugas untuk menampilkan rekomendasi terdekat:',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                ...presets.map((preset) {
                  final (label, subtitle, coords) = preset;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTealLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.location_city_rounded,
                        color: AppColors.primaryTeal,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () {
                      try {
                        ref
                            .read(currentLocationProvider.notifier)
                            .setManualLocation(coords, label);
                      } catch (_) {}
                      Navigator.pop(sheetCtx);
                      if (context.mounted) {
                        _proceedToMain(context);
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.lightCreamBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top small indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.cardBorder,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Center Visual & Text
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated-like radar circle graphic
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryTealLight.withOpacity(
                                  0.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryTeal.withOpacity(
                                    0.15,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryTeal,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryTeal
                                            .withOpacity(0.35),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    size: 36,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Title
                            const Text(
                              'Cari spot terdekat\ndari kamu',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Description
                            const Text(
                              'Aktifkan lokasi supaya SpotNugas bisa memberikan rekomendasi tempat terbaik di sekitarmu.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.textBody,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Privacy micro badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.lightCream,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: AppColors.textMuted,
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Lokasimu aman dan hanya digunakan saat nugas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Bottom Buttons
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(currentLocationProvider.notifier)
                                        .detectDeviceLocation(force: true);
                                  } catch (_) {}
                                  if (context.mounted) {
                                    _proceedToMain(context);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryTeal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.my_location_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Aktifkan Lokasi',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: () =>
                                    _showManualLocationSheet(context, ref),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryTealDark,
                                  side: const BorderSide(
                                    color: AppColors.cardBorder,
                                    width: 1.5,
                                  ),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Pilih Lokasi Manual',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
