import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/geoapify_config.dart';
import '../constants/app_colors.dart';
import '../models/place.dart';
import '../models/place_review_model.dart';
import '../providers/auth_provider.dart';
import '../providers/review_provider.dart';
import '../providers/saved_places_provider.dart';
import '../widgets/facility_chip.dart';
import '../widgets/skor_nugas_badge.dart';
import 'auth/login_screen.dart';
import 'spot_ai_screen.dart';

class PlaceDetailScreen extends ConsumerStatefulWidget {
  final Place place;
  final Function(int)? onNavigateTab;

  const PlaceDetailScreen({super.key, required this.place, this.onNavigateTab});

  @override
  ConsumerState<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends ConsumerState<PlaceDetailScreen> {
  int _currentImageIndex = 0;
  late bool _isSavedLocal;

  @override
  void initState() {
    super.initState();
    _isSavedLocal = widget.place.isSaved;
  }

  void _askSpotAi() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpotAIScreen(
          initialQuery:
              'Tanya tentang ${widget.place.name}: bagaimana suasana nugas dan colokan di sana?',
        ),
      ),
    );
  }

  Future<void> _showDirections() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Membuka petunjuk arah ke ${widget.place.name}... (${widget.place.distanceLabel})',
        ),
        backgroundColor: AppColors.primaryTealDark,
        behavior: SnackBarBehavior.floating,
      ),
    );

    final lat = widget.place.latitude;
    final lng = widget.place.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  double _computeSubScore(double? baseScore, Iterable<double?> reviewScores) {
    final valid = reviewScores.whereType<double>().toList();
    if (valid.isEmpty) return baseScore ?? 0.0;
    final avgReview = valid.reduce((a, b) => a + b) / valid.length;
    if (baseScore == null || baseScore <= 0) {
      return double.parse(avgReview.toStringAsFixed(1));
    }
    return double.parse(((baseScore + avgReview) / 2.0).toStringAsFixed(1));
  }

  void _showGuestReviewBlockedDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => const GuestReviewBlockedDialog(),
    );
  }

  void _openReviewModal({
    PlaceReviewModel? existingReview,
    required String placeId,
  }) {
    final user = ref.read(currentUserProfileProvider).valueOrNull;
    if (user == null || user.isGuest) {
      _showGuestReviewBlockedDialog();
      return;
    }

    double currentRating = existingReview?.rating ?? 5.0;
    final commentController = TextEditingController(
      text: existingReview?.comment ?? '',
    );
    String selectedPurpose =
        existingReview?.visitPurpose ?? 'Skripsi / Belajar';
    double wifiScore = existingReview?.wifiRating ?? 4.5;
    double outletScore = existingReview?.outletRating ?? 4.5;
    double comfortScore = existingReview?.comfortRating ?? 4.5;
    double noiseScore = existingReview?.noiseRating ?? 4.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          existingReview != null
                              ? 'Edit Review Kamu'
                              : 'Tulis Review Tempat',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (existingReview != null)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Hapus Review?'),
                                content: const Text(
                                  'Review kamu akan dihapus permanen.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Batal'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              if (!sheetCtx.mounted) return;
                              Navigator.pop(sheetCtx);
                              await ref
                                  .read(reviewControllerProvider.notifier)
                                  .deleteReview(placeId: placeId);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Review berhasil dihapus'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Overall Rating Picker
                  const Text(
                    'Rating Keseluruhan:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (idx) {
                      final starVal = idx + 1.0;
                      return IconButton(
                        icon: Icon(
                          starVal <= currentRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 32,
                          color: AppColors.starGold,
                        ),
                        onPressed: () {
                          setSheetState(() {
                            currentRating = starVal;
                          });
                        },
                      );
                    }),
                  ),
                  Center(
                    child: Text(
                      '${currentRating.toStringAsFixed(1)} / 5.0',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Purpose selector
                  const Text(
                    'Tujuan Berkunjung:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          'Skripsi / Belajar',
                          'Kerja / Coding',
                          'Meeting Kelompok',
                          'Santai',
                        ].map((purpose) {
                          final isSelected = selectedPurpose == purpose;
                          return ChoiceChip(
                            label: Text(purpose),
                            selected: isSelected,
                            selectedColor: AppColors.primaryTealLight,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.primaryTealDark
                                  : AppColors.textMuted,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() {
                                  selectedPurpose = purpose;
                                });
                              }
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Sub-scores
                  _buildSubScoreSlider(
                    'Wi-Fi',
                    wifiScore,
                    Icons.wifi_rounded,
                    (val) => setSheetState(() => wifiScore = val),
                  ),
                  _buildSubScoreSlider(
                    'Colokan',
                    outletScore,
                    Icons.power_rounded,
                    (val) => setSheetState(() => outletScore = val),
                  ),
                  _buildSubScoreSlider(
                    'Kenyamanan',
                    comfortScore,
                    Icons.chair_rounded,
                    (val) => setSheetState(() => comfortScore = val),
                  ),
                  _buildSubScoreSlider(
                    'Ketenangan',
                    noiseScore,
                    Icons.volume_off_rounded,
                    (val) => setSheetState(() => noiseScore = val),
                  ),
                  const SizedBox(height: 14),

                  // Comment Input
                  const Text(
                    'Komentar Pengalaman Nugas:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText:
                          'Tulis pengalaman nugasmu (kecepatan wifi, posisi colokan, dll)...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.cardBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryTeal,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final text = commentController.text.trim();
                        if (text.length < 3) {
                          ScaffoldMessenger.of(sheetCtx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Komentar review minimal berisi 3 karakter.',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(sheetCtx);

                        try {
                          if (existingReview != null) {
                            await ref
                                .read(reviewControllerProvider.notifier)
                                .editReview(
                                  placeId: placeId,
                                  existingReview: existingReview,
                                  rating: currentRating,
                                  comment: text,
                                  visitPurpose: selectedPurpose,
                                  wifiRating: wifiScore,
                                  outletRating: outletScore,
                                  comfortRating: comfortScore,
                                  noiseRating: noiseScore,
                                );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Review berhasil diperbarui!'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.primaryTealDark,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          } else {
                            await ref
                                .read(reviewControllerProvider.notifier)
                                .submitReview(
                                  placeId: placeId,
                                  rating: currentRating,
                                  comment: text,
                                  visitPurpose: selectedPurpose,
                                  wifiRating: wifiScore,
                                  outletRating: outletScore,
                                  comfortRating: comfortScore,
                                  noiseRating: noiseScore,
                                );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Review berhasil dipublikasikan!',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.primaryTealDark,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal menyimpan review: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        existingReview != null
                            ? 'Simpan Perubahan'
                            : 'Kirim Review',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubScoreSlider(
    String label,
    double value,
    IconData icon,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryTeal),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: 1.0,
              max: 5.0,
              divisions: 8,
              activeColor: AppColors.primaryTeal,
              inactiveColor: AppColors.lightCream,
              onChanged: onChanged,
            ),
          ),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    // Simulated gallery images
    final galleryImages = [
      place.image,
      'assets/images/kopi-ruang.jpg',
      'assets/images/taman-kolektif.jpg',
    ];

    // Watch real reviews stream with fallback to mock seeds
    final reviewsAsync = ref.watch(
      placeReviewsStreamProvider((
        placeId: place.id,
        mockFallback: place.reviews,
      )),
    );

    final reviewsList = reviewsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => place.reviews
          .map((r) => PlaceReviewModel.fromLegacyReview(r, place.id))
          .toList(),
    );

    // Compute updated dynamic Skor Nugas
    final dynamicSkorNugas = ref
        .watch(reviewRepositoryProvider)
        .computeDynamicSkorNugas(place: place, reviews: reviewsList);

    // Watch current user profile
    final currentUser = ref.watch(currentUserProfileProvider).valueOrNull;
    final myReview = reviewsList
        .where((r) => r.userId == currentUser?.uid)
        .firstOrNull;

    // Watch bookmark state
    final isSavedAsync = ref.watch(isPlaceSavedProvider(place.id));
    final isCurrentlySaved = isSavedAsync.maybeWhen(
      data: (saved) => saved,
      orElse: () => _isSavedLocal,
    );

    return Scaffold(
      backgroundColor: AppColors.lightCreamBackground,
      body: Stack(
        children: [
          // Scrollable Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Large Image Gallery AppBar
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                elevation: 0,
                backgroundColor: AppColors.primaryTeal,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isCurrentlySaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isCurrentlySaved
                            ? AppColors.terracottaBrown
                            : Colors.white,
                        size: 20,
                      ),
                      onPressed: () async {
                        setState(() {
                          _isSavedLocal = !isCurrentlySaved;
                          widget.place.isSaved = _isSavedLocal;
                        });
                        try {
                          await ref
                              .read(savedPlacesControllerProvider.notifier)
                              .setSaved(place, _isSavedLocal);
                        } catch (_) {}

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isSavedLocal
                                  ? '${place.name} disimpan ke Tersimpan'
                                  : '${place.name} dihapus dari Tersimpan',
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.primaryTealDark,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      // PageView for Gallery
                      PageView.builder(
                        itemCount: galleryImages.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final img = galleryImages[index];
                          if (img.startsWith('http://') ||
                              img.startsWith('https://')) {
                            return Image.network(
                              img,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, _, _) =>
                                  _buildGalleryPlaceholder(),
                            );
                          }
                          if (img.isNotEmpty) {
                            return Image.asset(
                              img,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, _, _) =>
                                  _buildGalleryPlaceholder(),
                            );
                          }
                          return _buildGalleryPlaceholder();
                        },
                      ),
                      // Top gradient for back button visibility
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 90,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Bottom Indicator
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1}/${galleryImages.length} Foto',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Place Info Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category & Open/Close badge
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warmBeigeLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              place.category,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.terracottaBrown,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.statusOpen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: AppColors.statusOpen,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  place.openStatus,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.statusOpen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (place.isVerifiedPartner)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 13,
                                    color: AppColors.primaryTeal,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Mitra Resmi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryTealDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Name
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Meta details: Distance, Rating, Price
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: AppColors.starGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${reviewsList.length} review)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Icon(
                              Icons.near_me_outlined,
                              size: 15,
                              color: AppColors.primaryTeal,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              place.distance,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              place.priceLabel,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.terracottaBrown,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Address Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.primaryTeal,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                place.address ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textBody,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // HIGHLIGHT: SKOR NUGAS (Dynamic update from reviews)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Metrik Nugas SpotNugas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (dynamicSkorNugas != place.skorNugas) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTealLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Update Komunitas',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryTealDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SkorNugasBadge(score: dynamicSkorNugas, isLarge: true),
                      const SizedBox(height: 16),

                      // Specific Breakdown Scores
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            _buildScoreBar(
                              'Wi-Fi',
                              _computeSubScore(
                                place.wifiScore,
                                reviewsList.map((r) => r.wifiRating),
                              ),
                              Icons.wifi_rounded,
                            ),
                            const SizedBox(height: 12),
                            _buildScoreBar(
                              'Colokan',
                              _computeSubScore(
                                place.outletScore,
                                reviewsList.map((r) => r.outletRating),
                              ),
                              Icons.power_rounded,
                            ),
                            const SizedBox(height: 12),
                            _buildScoreBar(
                              'Kenyamanan Meja & Kursi',
                              _computeSubScore(
                                place.comfortScore,
                                reviewsList.map((r) => r.comfortRating),
                              ),
                              Icons.chair_rounded,
                            ),
                            const SizedBox(height: 12),
                            _buildScoreBar(
                              'Ketenangan / Suasana',
                              _computeSubScore(
                                place.noiseScore,
                                reviewsList.map((r) => r.noiseRating),
                              ),
                              Icons.volume_off_rounded,
                            ),
                            const SizedBox(height: 12),
                            _buildScoreBar(
                              'Harga & Value',
                              _computeSubScore(
                                place.priceValueScore,
                                reviewsList.map((r) => r.priceValueRating),
                              ),
                              Icons.payments_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Facilities Section
                      const Text(
                        'Fasilitas Penunjang',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: place.facilities
                            .map((fac) => FacilityChip(label: fac.label))
                            .toList(),
                      ),
                      const SizedBox(height: 24),

                      // Review Pengguna Section Header & Action Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Review Pengguna',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  '${reviewsList.length} Komentar',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryTeal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openReviewModal(
                              existingReview: myReview,
                              placeId: place.id,
                            ),
                            icon: Icon(
                              myReview != null
                                  ? Icons.edit_note_rounded
                                  : Icons.rate_review_rounded,
                              size: 16,
                            ),
                            label: Text(
                              myReview != null ? 'Edit Review' : 'Tulis Review',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Reviews List with Real vs Mock distinction
                      Column(
                        children: reviewsList
                            .map(
                              (rev) => _buildReviewCard(
                                rev,
                                isMine: rev.userId == currentUser?.uid,
                                onEditTap: () => _openReviewModal(
                                  existingReview: rev,
                                  placeId: place.id,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      // Geoapify Attribution
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            GeoapifyConfig.attributionText,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Directions Button
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        onPressed: _showDirections,
                        icon: const Icon(Icons.directions_rounded, size: 18),
                        label: const Text(
                          'Petunjuk Arah',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryTealDark,
                          side: const BorderSide(
                            color: AppColors.primaryTeal,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Tanya SpotAI Button
                    Expanded(
                      flex: 5,
                      child: ElevatedButton.icon(
                        onPressed: _askSpotAi,
                        icon: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Tanya SpotAI',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Score Progress Bar
  Widget _buildScoreBar(String label, double score, IconData icon) {
    final progress = (score / 5.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppColors.primaryTeal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${score.toStringAsFixed(1)} / 5',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.lightCream,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.primaryTeal,
            ),
            minHeight: 7,
          ),
        ),
      ],
    );
  }

  // Review Card with clear distinctions between real Firestore reviews vs mock demonstration seeds
  Widget _buildReviewCard(
    PlaceReviewModel review, {
    bool isMine = false,
    VoidCallback? onEditTap,
  }) {
    final isMock = review.isMockDemonstration;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMine ? AppColors.primaryTeal : AppColors.cardBorder,
          width: isMine ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isMock
                    ? AppColors.cardBorder
                    : AppColors.primaryTealLight,
                child: Text(
                  review.userName.isNotEmpty
                      ? review.userName.substring(0, 1).toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isMock
                        ? AppColors.textMuted
                        : AppColors.primaryTealDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.userName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Badge: Real Community vs Mock Seed
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isMock
                                ? Colors.grey.withOpacity(0.12)
                                : AppColors.primaryTealLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMock
                                    ? Icons.science_outlined
                                    : Icons.verified_rounded,
                                size: 10,
                                color: isMock
                                    ? AppColors.textMuted
                                    : AppColors.primaryTealDark,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isMock ? 'Demo Seed' : 'Komunitas',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isMock
                                      ? AppColors.textMuted
                                      : AppColors.primaryTealDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${review.visitPurpose ?? "Nugas"} • ${_formatReviewDate(review.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.starGold,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    review.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (isMine && onEditTap != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onEditTap,
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textBody,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatReviewDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Hari ini';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildGalleryPlaceholder() {
    return Container(
      color: AppColors.primaryTealDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.coffee_rounded,
              size: 56,
              color: Colors.white.withOpacity(0.8),
            ),
            const SizedBox(height: 8),
            Text(
              widget.place.category,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive guest review restriction modal dialog.
///
/// Designed to gracefully adapt across all screen widths (320dp to 600dp+)
/// and accessibility font scales without RenderFlex horizontal or vertical overflow.
class GuestReviewBlockedDialog extends StatelessWidget {
  const GuestReviewBlockedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      actionsOverflowButtonSpacing: 8,
      actionsOverflowDirection: VerticalDirection.down,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.primaryTeal,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Akses Terbatas Tamu',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Text(
          'Tamu tidak dapat mempublikasikan review untuk menjaga integritas komunitas SpotNugas.\n\nSilakan daftar atau masuk untuk membagikan pengalaman nugasmu.',
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textBody,
            height: 1.45,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: const Text(
            'Nanti Saja',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen(isFirstTime: false),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Daftar / Masuk',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
