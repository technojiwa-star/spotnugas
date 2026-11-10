import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/geoapify_config.dart';
import '../constants/app_colors.dart';
import '../data/dummy_data.dart';
import '../models/place.dart';
import '../providers/place_provider.dart';
import '../constants/app_location.dart';
import '../providers/location_provider.dart';
import '../providers/saved_places_provider.dart';
import '../services/device_location_service.dart';
import '../widgets/place_card.dart';
import '../widgets/custom_search_bar.dart';
import 'search_results_screen.dart';
import 'place_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'Semua';
  List<Place> _places = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (GeoapifyConfig.hasApiKey &&
          mounted &&
          ref.read(currentLocationProvider).source != LocationSource.manual) {
        ref.read(currentLocationProvider.notifier).detectDeviceLocation();
      }
    });
  }

  Future<void> _loadPlaces() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    final locState = ref.read(currentLocationProvider);
    if (!locState.hasSelectedLocation) {
      setState(() {
        _places = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }
    try {
      setState(() {
        _places = [];
        _isLoading = true;
        _errorMessage = null;
      });
      final repo = ref.read(placeRepositoryProvider);
      final origin = locState.coordinates;
      if (kDebugMode) {
        debugPrint(
          '[SpotNugas][HomeScreen] _loadPlaces start: label="${locState.label}", source=${locState.source}, repo=${repo.runtimeType}',
        );
      }
      final places = await repo.getNearbyPlaces(origin: origin);
      final filteredCount = _selectedCategory == 'Semua'
          ? places.length
          : places.where(_matchesSelectedCategory).length;
      if (kDebugMode) {
        debugPrint(
          '[SpotNugas][HomeScreen] _loadPlaces success: apiPlaces=${places.length}, selectedCategory="$_selectedCategory", afterFilter=$filteredCount',
        );
      }
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _places = places;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('[SpotNugas][HomeScreen] _loadPlaces failed');
      }
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _errorMessage = 'Periksa koneksi internet lalu coba lagi.';
          _isLoading = false;
        });
      }
    }
  }

  void _openPlaceDetail(Place place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(
          place: place,
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }

  Future<void> _toggleBookmark(Place place) async {
    final nextSaved = !place.isSaved;
    setState(() {
      place.isSaved = nextSaved;
    });
    try {
      await ref
          .read(savedPlacesControllerProvider.notifier)
          .setSaved(place, nextSaved);
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextSaved
              ? '${place.name} disimpan ke Favorit'
              : '${place.name} dihapus dari Tersimpan',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryTealDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _matchesSelectedCategory(Place p) {
    if (_selectedCategory == 'Semua') return true;
    if (p.tags.contains(_selectedCategory)) return true;
    final lower = _selectedCategory.toLowerCase();
    final catLower = p.category.toLowerCase();
    if (catLower.contains(lower)) return true;
    if (lower.contains('wifi') || lower.contains('wi-fi')) {
      return p.facilities.contains(PlaceFacility.wifi) ||
          (p.wifiScore ?? 0) >= 4.5 ||
          catLower.contains('cafe') ||
          catLower.contains('coworking');
    }
    if (lower.contains('colokan')) {
      return p.facilities.contains(PlaceFacility.powerOutlet) ||
          (p.outletScore ?? 0) >= 4.5 ||
          catLower.contains('coworking') ||
          catLower.contains('cafe');
    }
    if (lower.contains('hemat')) {
      return p.priceLevel == PlacePriceLevel.free ||
          p.priceLevel == PlacePriceLevel.inexpensive ||
          catLower.contains('perpustakaan') ||
          catLower.contains('cafe');
    }
    if (lower.contains('malam') || lower.contains('24 jam')) {
      return p.openStatusLabel.toLowerCase().contains('24') ||
          p.suitableFor.contains(PlaceSuitability.lateNight) ||
          p.isOpenNow == true;
    }
    if (lower.contains('fokus') || lower.contains('tenang')) {
      return p.facilities.contains(PlaceFacility.quietZone) ||
          p.suitableFor.contains(PlaceSuitability.soloFocus) ||
          catLower.contains('perpustakaan') ||
          catLower.contains('coworking');
    }
    if (lower.contains('kelompok')) {
      return p.facilities.contains(PlaceFacility.groupSeating) ||
          p.suitableFor.contains(PlaceSuitability.groupWork) ||
          catLower.contains('coworking') ||
          catLower.contains('cafe');
    }
    return false;
  }

  void _showNotificationsSheet(BuildContext context, String locationLabel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              const Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primaryTeal,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Info & Aktivitas SpotNugas',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTealLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primaryTeal,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Area Aktif: $locationLabel',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                subtitle: Text(
                  'Menampilkan ${_places.length} spot nugas terbaik di sekitarmu.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warmBeigeLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.terracottaBrown,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Tips Nugas Hari Ini',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                subtitle: const Text(
                  'Gunakan filter "Wi-Fi Cepat" atau "Banyak Colokan" untuk menemukan spot fokus terbaik.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Automatically re-query nearby places whenever the active location coordinates change
    // or when initial GPS detection completes while places are still empty.
    ref.listen<LocationState>(currentLocationProvider, (previous, next) {
      if (previous?.coordinates != next.coordinates ||
          previous?.hasSelectedLocation != next.hasSelectedLocation ||
          (previous?.isLoading == true && !next.isLoading && _places.isEmpty)) {
        _loadPlaces();
      }
    });

    // Filtered by selected chip if not 'Semua'
    final filteredPlaces = _selectedCategory == 'Semua'
        ? _places
        : _places.where(_matchesSelectedCategory).toList();

    final locationState = ref.watch(currentLocationProvider);
    final locationLabel = locationState.label;

    return Scaffold(
      backgroundColor: AppColors.lightCreamBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPlaces,
          color: AppColors.primaryTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header & User Location
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => _showLocationPickerModal(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                  horizontal: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 16,
                                      color: AppColors.terracottaBrown,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        locationLabel,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    if (locationState.isLoading)
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primaryTeal,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: AppColors.textMuted,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Halo! Mau nugas\ndi mana hari ini? ☕',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notification Icon
                      GestureDetector(
                        onTap: () =>
                            _showNotificationsSheet(context, locationLabel),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Stack(
                            children: [
                              const Icon(
                                Icons.notifications_none_rounded,
                                size: 22,
                                color: AppColors.textDark,
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.terracottaBrown,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Permission Notice Banner (shown if location permission not granted and not manual)
                if (locationState.permissionStatus !=
                        LocationPermissionStatus.granted &&
                    locationState.source != LocationSource.manual)
                  _buildLocationNoticeBanner(context, locationState),

                // 2. Large Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: CustomSearchBar(
                    hintText: 'Cari cafe, coworking, atau tempat nugas...',
                    readOnly: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchResultsScreen(
                            initialCategory: _selectedCategory,
                            onNavigateTab: widget.onNavigateTab,
                          ),
                        ),
                      );
                    },
                    onFilterTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchResultsScreen(
                            initialCategory: _selectedCategory,
                            onNavigateTab: widget.onNavigateTab,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 3. Quick Category Chips
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: DummyData.categories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = DummyData.categories[index];
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryTeal
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryTeal
                                  : AppColors.cardBorder,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryTeal.withOpacity(
                                        0.25,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 4. SpotAI Callout Banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: GestureDetector(
                    onTap: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(2); // Switch to SpotAI tab
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryTeal,
                            AppColors.primaryTealDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryTeal.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.lightCream,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanya SpotAI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Rekomendasi instan sesuai budget & colokan',
                                  style: TextStyle(
                                    color: AppColors.lightCream,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content state rendering: Loading, Error, Empty, or Places
                if (!locationState.hasSelectedLocation)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 30,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Pilih lokasi untuk menemukan tempat nugas terdekat.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showLocationPickerModal(context),
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text('Pilih Lokasi'),
                        ),
                      ],
                    ),
                  )
                else if (_isLoading && _places.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 40,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryTeal,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Mencari tempat nugas di sekitar lokasi...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_errorMessage != null && _places.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 30,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: AppColors.terracottaBrown,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Gagal Memuat Tempat',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textBody,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadPlaces,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text(
                              'Coba Lagi',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_places.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 40,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Belum ada tempat nugas ditemukan di sekitar lokasi ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _loadPlaces,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Muat Ulang'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // 5. Section: "Rekomendasi Buat Kamu"
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Rekomendasi Buat Kamu',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchResultsScreen(
                                  onNavigateTab: widget.onNavigateTab,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Lihat Semua',
                            style: TextStyle(
                              color: AppColors.primaryTeal,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Featured Place
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PlaceCard(
                      place: _places.first,
                      cardType: PlaceCardType.vertical,
                      onTap: () => _openPlaceDetail(_places.first),
                      onBookmarkToggle: () => _toggleBookmark(_places.first),
                    ),
                  ),

                  // 6. Section: "Dekat Kamu" (Horizontally scrollable cards)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dekat Kamu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Di bawah 5 km',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 235,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _places.length,
                      itemBuilder: (context, index) {
                        final place = _places[index];
                        return PlaceCard(
                          place: place,
                          cardType: PlaceCardType.horizontal,
                          onTap: () => _openPlaceDetail(place),
                          onBookmarkToggle: () => _toggleBookmark(place),
                        );
                      },
                    ),
                  ),

                  // 7. Section: "Spot Populer Lainnya"
                  if (filteredPlaces.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: const Text(
                        'Favorit Mahasiswa & Remote Worker',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: filteredPlaces.skip(1).take(5).map((place) {
                          return PlaceCard(
                            place: place,
                            cardType: PlaceCardType.vertical,
                            onTap: () => _openPlaceDetail(place),
                            onBookmarkToggle: () => _toggleBookmark(place),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],

                // Attribution Footer
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      GeoapifyConfig.attributionText,
                      style: const TextStyle(
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
      ),
    );
  }

  Widget _buildLocationNoticeBanner(
    BuildContext context,
    LocationState locState,
  ) {
    final isPermanentlyDenied =
        locState.permissionStatus == LocationPermissionStatus.permanentlyDenied;
    final isServiceDisabled =
        locState.permissionStatus == LocationPermissionStatus.serviceDisabled;

    final String title;
    final String message;
    final String actionText;
    final VoidCallback onAction;

    if (isServiceDisabled) {
      title = 'GPS Perangkat Nonaktif';
      message =
          'Nyalakan layanan lokasi di HP kamu untuk menemukan spot nugas terdekat.';
      actionText = 'Aktifkan GPS';
      onAction = () =>
          ref.read(currentLocationProvider.notifier).openLocationSettings();
    } else if (isPermanentlyDenied) {
      title = 'Izin Lokasi Dinonaktifkan';
      message =
          'Beri izin lokasi di Pengaturan Aplikasi agar SpotNugas bisa mendeteksi posisimu.';
      actionText = 'Buka Pengaturan';
      onAction = () =>
          ref.read(currentLocationProvider.notifier).openAppSettings();
    } else if (locState.permissionStatus == LocationPermissionStatus.timeout ||
        locState.permissionStatus == LocationPermissionStatus.error) {
      final isTimeout =
          locState.permissionStatus == LocationPermissionStatus.timeout;
      title = isTimeout ? 'Lokasi GPS Belum Ditemukan' : 'Deteksi Lokasi Gagal';
      message = isTimeout
          ? 'GPS belum mendapatkan posisi. Coba lagi atau pilih kota secara manual.'
          : 'Lokasi perangkat belum tersedia. Coba lagi atau pilih kota secara manual.';
      actionText = 'Coba Lagi';
      onAction = () => ref
          .read(currentLocationProvider.notifier)
          .detectDeviceLocation(force: true);
    } else {
      title = 'Izin Lokasi Belum Aktif';
      message =
          'Aktifkan izin lokasi untuk mencari spot nugas terdekat secara otomatis.';
      actionText = 'Aktifkan';
      onAction = () => ref
          .read(currentLocationProvider.notifier)
          .detectDeviceLocation(force: true);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off_rounded,
              color: AppColors.terracottaBrown,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textBody,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: AppColors.primaryTeal.withOpacity(0.12),
                foregroundColor: AppColors.primaryTealDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                actionText,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationPickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final locState = ref.watch(currentLocationProvider);
            final notifier = ref.read(currentLocationProvider.notifier);

            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.cardBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Pilih Lokasi Nugas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(bottomSheetContext),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Current / GPS Option
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: locState.source == LocationSource.deviceGps
                              ? AppColors.primaryTealLight.withOpacity(0.35)
                              : AppColors.lightCream,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: locState.source == LocationSource.deviceGps
                                ? AppColors.primaryTeal.withOpacity(0.5)
                                : AppColors.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryTeal,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Lokasi Saat Ini (GPS)',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (locState.source ==
                                          LocationSource.deviceGps) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryTeal,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            locState.isApproximate
                                                ? 'Perkiraan'
                                                : 'Aktif',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    locState.source == LocationSource.deviceGps
                                        ? locState.label
                                        : 'Gunakan sensor GPS perangkat',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (locState.isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryTeal,
                                ),
                              )
                            else
                              TextButton(
                                onPressed: () async {
                                  await notifier.detectDeviceLocation(
                                    force: true,
                                  );
                                  if (bottomSheetContext.mounted) {
                                    Navigator.pop(bottomSheetContext);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryTealDark,
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Text(
                                  locState.source == LocationSource.deviceGps
                                      ? 'Perbarui'
                                      : 'Deteksi',
                                ),
                              ),
                          ],
                        ),
                      ),

                      if (locState.permissionStatus ==
                          LocationPermissionStatus.permanentlyDenied) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => notifier.openAppSettings(),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.settings_outlined,
                                  size: 14,
                                  color: AppColors.primaryTealDark,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Buka Pengaturan Aplikasi untuk izin lokasi',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryTealDark,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),
                      const Text(
                        'Pilihan Kota / Preset:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // City Presets
                      _buildCityOption(
                        bottomSheetContext: bottomSheetContext,
                        notifier: notifier,
                        activeLabel: locState.label,
                        label: AppLocation.defaultJakartaLabel,
                        coords: AppLocation.defaultJakarta,
                        isMock: false,
                      ),
                      _buildCityOption(
                        bottomSheetContext: bottomSheetContext,
                        notifier: notifier,
                        activeLabel: locState.label,
                        label: AppLocation.bandungLabel,
                        coords: AppLocation.bandung,
                        isMock: false,
                      ),
                      _buildCityOption(
                        bottomSheetContext: bottomSheetContext,
                        notifier: notifier,
                        activeLabel: locState.label,
                        label: AppLocation.depokLabel,
                        coords: AppLocation.depok,
                        isMock: false,
                      ),
                      _buildCityOption(
                        bottomSheetContext: bottomSheetContext,
                        notifier: notifier,
                        activeLabel: locState.label,
                        label: AppLocation.mockYogyakartaLabel,
                        coords: AppLocation.mockYogyakartaOrigin,
                        isMock: true,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCityOption({
    required BuildContext bottomSheetContext,
    required LocationNotifier notifier,
    required String activeLabel,
    required String label,
    required GeoCoordinates coords,
    required bool isMock,
  }) {
    final isSelected = activeLabel == label;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
      leading: Icon(
        isMock ? Icons.science_outlined : Icons.location_city_rounded,
        size: 20,
        color: isSelected ? AppColors.primaryTeal : AppColors.textMuted,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? AppColors.primaryTealDark : AppColors.textDark,
        ),
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primaryTeal,
              size: 18,
            )
          : null,
      onTap: () {
        notifier.setManualLocation(coords, label);
        Navigator.pop(bottomSheetContext);
      },
    );
  }
}
