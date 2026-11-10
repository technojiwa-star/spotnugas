import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(isFirstTime: true),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightCreamBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.laptop_chromebook_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SpotNugas',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryTealDark,
                        ),
                      ),
                    ],
                  ),
                  if (_currentPage < 2)
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: const Text(
                        'Lewati',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [_buildPage1(), _buildPage2(), _buildPage3()],
              ),
            ),

            // Bottom Navigation Area
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primaryTeal
                              : AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == 2 ? 'Mulai Sekarang' : 'Lanjut',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Onboarding 1: “Temukan spot nugas di sekitarmu”
  Widget _buildPage1() {
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration / Card Graphics
            Container(
              height: 245,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.lightCream,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
              ),
              padding: const EdgeInsets.all(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 10,
                    left: 8,
                    child: _buildBadgeCard(
                      '☕ Cafe & Coffee Shop',
                      Icons.coffee_rounded,
                      AppColors.terracottaBrown,
                    ),
                  ),
                  Positioned(
                    top: 60,
                    right: 8,
                    child: _buildBadgeCard(
                      '📚 Perpustakaan Tenang',
                      Icons.local_library_rounded,
                      AppColors.primaryTeal,
                    ),
                  ),
                  Positioned(
                    bottom: 60,
                    left: 8,
                    child: _buildBadgeCard(
                      '💼 Coworking Space',
                      Icons.work_outline_rounded,
                      AppColors.warmBeigeDark,
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 8,
                    child: _buildBadgeCard(
                      '⚡ Meja Nugas Siap Pakai',
                      Icons.power_rounded,
                      AppColors.primaryTealDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.explore_rounded,
                      color: AppColors.primaryTeal,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Temukan spot nugas\ndi sekitarmu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Temukan cafe, perpustakaan, coworking space, dan tempat ramah laptop terdekat yang diverifikasi cocok untuk nugas santai maupun fokus penuh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textBody,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Onboarding 2: “Cari sesuai kebutuhanmu”
  Widget _buildPage2() {
    final features = [
      {
        'title': 'Wi-Fi Cepat & Stabil',
        'icon': Icons.wifi_rounded,
        'color': AppColors.primaryTeal,
      },
      {
        'title': 'Colokan Melimpah',
        'icon': Icons.power_rounded,
        'color': AppColors.terracottaBrown,
      },
      {
        'title': 'Harga Mahasiswa (Hemat)',
        'icon': Icons.payments_rounded,
        'color': AppColors.warmBeigeDark,
      },
      {
        'title': 'Suasana Tenang / Ramai',
        'icon': Icons.volume_off_rounded,
        'color': AppColors.primaryTealDark,
      },
      {
        'title': 'Jarak Terdekat dari Kamu',
        'icon': Icons.near_me_rounded,
        'color': AppColors.primaryTeal,
      },
    ];

    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warmBeigeLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: features.map((f) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: (f['color'] as Color).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            f['icon'] as IconData,
                            size: 15,
                            color: f['color'] as Color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f['title'] as String,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 17,
                          color: AppColors.primaryTeal,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Cari sesuai kebutuhanmu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Filter tempat berdasarkan kecepatan Wi-Fi, ketersediaan colokan, budget per kunjungan, suasana hening, hingga jarak terdekat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textBody,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Onboarding 3: “Bingung pilih tempat? Tanya SpotAI”
  Widget _buildPage3() {
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryTealLight, AppColors.lightCream],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // AI Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Asisten SpotAI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // User Prompt bubble
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.terracottaBrown,
                        borderRadius: BorderRadius.circular(
                          14,
                        ).copyWith(bottomRight: const Radius.circular(4)),
                      ),
                      child: const Text(
                        '“Cari tempat nugas kelompok ada colokan budget 50k”',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // AI Response preview
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          14,
                        ).copyWith(topLeft: const Radius.circular(4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppColors.primaryTeal,
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '94% cocok • Taman Kolektif',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryTealDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Meja kelompok luas + Wi-Fi 100Mbps kencang.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textBody,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Bingung pilih tempat?\nTanya SpotAI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Asisten cerdas SpotAI siap merekomendasikan dan membandingkan spot nugas terbaik sesuai preferensi, waktu, dan anggaranmu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textBody,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
