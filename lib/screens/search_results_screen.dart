import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../data/dummy_data.dart';
import '../models/place.dart';
import '../providers/location_provider.dart';
import '../providers/place_provider.dart';
import '../providers/saved_places_provider.dart';
import '../repositories/place_repository.dart';
import '../widgets/place_card.dart';
import '../widgets/custom_search_bar.dart';
import 'place_detail_screen.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  final Function(int)? onNavigateTab;

  const SearchResultsScreen({
    super.key,
    this.initialCategory,
    this.onNavigateTab,
  });

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSort = 'Skor Nugas';
  String _activeCategory = 'Semua';
  List<Place> _filteredPlaces = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _searchGeneration = 0;

  final List<String> _sortOptions = [
    'Skor Nugas',
    'Terdekat',
    'Rating',
    'Termurah',
  ];

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialCategory ?? 'Semua';
    _applyFiltersAndSort();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _applyFiltersAndSort() async {
    if (!mounted) return;
    final generation = ++_searchGeneration;
    final location = ref.read(currentLocationProvider);
    setState(() {
      _filteredPlaces = [];
      _errorMessage = null;
      _isLoading = location.hasSelectedLocation;
    });
    if (!location.hasSelectedLocation) return;
    final query = _searchController.text.trim();
    PlaceSortOption sort;
    switch (_selectedSort) {
      case 'Terdekat':
        sort = PlaceSortOption.distance;
        break;
      case 'Rating':
        sort = PlaceSortOption.rating;
        break;
      case 'Termurah':
        sort = PlaceSortOption.price;
        break;
      case 'Skor Nugas':
      default:
        sort = PlaceSortOption.studyScore;
        break;
    }

    try {
      final repo = ref.read(placeRepositoryProvider);
      final results = await repo.searchPlaces(
        PlaceSearchQuery(
          text: query,
          tag: _activeCategory == 'Semua' ? null : _activeCategory,
          sort: sort,
          origin: location.coordinates,
        ),
      );
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _filteredPlaces = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _errorMessage = 'Pencarian gagal. Periksa koneksi lalu coba lagi.';
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
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primaryTealDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocationState>(currentLocationProvider, (prev, next) {
      if (prev?.coordinates != next.coordinates ||
          prev?.hasSelectedLocation != next.hasSelectedLocation) {
        _applyFiltersAndSort();
      }
    });
    final location = ref.watch(currentLocationProvider);

    return Scaffold(
      backgroundColor: AppColors.lightCreamBackground,
      appBar: AppBar(
        title: const Text('Tempat Nugas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CustomSearchBar(
                controller: _searchController,
                hintText: 'Cari cafe, coworking, atau colokan...',
                onChanged: (_) => _applyFiltersAndSort(),
              ),
            ),

            // Category Filter Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: DummyData.categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final cat = DummyData.categories[index];
                  final isSelected = _activeCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _activeCategory = cat;
                        });
                        _applyFiltersAndSort();
                      }
                    },
                    selectedColor: AppColors.terracottaBrown,
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textDark,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.terracottaBrown
                            : AppColors.cardBorder,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),

            // Sorting bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Urutkan:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _sortOptions.map((sort) {
                          final isSelected = _selectedSort == sort;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(sort),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedSort = sort;
                                  });
                                  _applyFiltersAndSort();
                                }
                              },
                              selectedColor: AppColors.primaryTeal,
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textDark,
                              ),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primaryTeal
                                      : AppColors.cardBorder,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Results count info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Menampilkan ${_filteredPlaces.length} spot terbaik',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color: AppColors.primaryTeal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedSort,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Vertical List of Places
            Expanded(
              child: !location.hasSelectedLocation
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Pilih lokasi di Beranda untuk mencari tempat nugas.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _applyFiltersAndSort,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    )
                  : _filteredPlaces.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: AppColors.textMuted.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tidak ada tempat yang cocok',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Coba ganti kata kunci atau pilih filter lain',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _filteredPlaces.length,
                      itemBuilder: (context, index) {
                        final place = _filteredPlaces[index];
                        return PlaceCard(
                          place: place,
                          cardType: PlaceCardType.vertical,
                          onTap: () => _openPlaceDetail(place),
                          onBookmarkToggle: () => _toggleBookmark(place),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
