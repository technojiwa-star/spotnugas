import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../data/place_mock_data.dart';
import '../models/place.dart';
import '../models/saved_place_item.dart';
import '../providers/saved_places_provider.dart';
import '../widgets/place_card.dart';
import 'place_detail_screen.dart';

class SavedScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;

  const SavedScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = [
    'Semua',
    'Favorit',
    'Mau Dicoba',
    'Nugas Kelompok',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  List<Place> _resolvePlaces(List<SavedPlaceItem> savedItems) {
    final Map<String, Place> merged = {};

    for (final item in savedItems) {
      final found = PlaceMockData.byId(item.placeId);
      if (found != null) {
        found.isSaved = true;
        merged[found.id] = found;
      } else {
        final reconstructed = item.toPlace();
        merged[reconstructed.id] = reconstructed;
      }
    }

    for (final seed in PlaceMockData.places) {
      if (seed.isSaved && !merged.containsKey(seed.id)) {
        merged[seed.id] = seed;
      }
    }

    return merged.values.toList();
  }

  List<Place> _getPlacesForTab(int tabIndex, List<Place> allSaved) {
    switch (tabIndex) {
      case 0: // Semua
        return allSaved.isNotEmpty
            ? allSaved
            : PlaceMockData.places.take(3).toList();
      case 1: // Favorit
        return allSaved
            .where((p) => p.rating >= 4.7 || p.skorNugas >= 9.0)
            .toList();
      case 2: // Mau Dicoba
        return PlaceMockData.places.where((p) => !p.isSaved).take(2).toList();
      case 3: // Nugas Kelompok
        final savedGroup = allSaved
            .where(
              (p) =>
                  p.tags.contains('Nugas Kelompok') ||
                  p.category.toLowerCase().contains('coworking'),
            )
            .toList();
        return savedGroup.isNotEmpty
            ? savedGroup
            : PlaceMockData.places
                  .where((p) => p.tags.contains('Nugas Kelompok'))
                  .toList();
      default:
        return allSaved;
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedPlacesAsync = ref.watch(savedPlacesStreamProvider);
    final savedItems = savedPlacesAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <SavedPlaceItem>[],
    );
    final savedIds = savedItems.map((i) => i.placeId).toSet();

    final allSaved = _resolvePlaces(savedItems);

    return Scaffold(
      backgroundColor: AppColors.lightCreamBackground,
      appBar: AppBar(
        title: const Text('Tempat Tersimpan'),
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primaryTeal,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryTeal,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_tabs.length, (tabIndex) {
          final places = _getPlacesForTab(tabIndex, allSaved);

          if (places.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 64,
                    color: AppColors.textMuted.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum ada tempat tersimpan di kategori ini',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ketuk ikon bookmark pada tempat yang ingin kamu simpan',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              final isItemSaved = savedIds.contains(place.id) || place.isSaved;

              return PlaceCard(
                place: place,
                cardType: PlaceCardType.vertical,
                onTap: () => _openPlaceDetail(place),
                onBookmarkToggle: () async {
                  final nextSaved = !isItemSaved;
                  setState(() {
                    place.isSaved = nextSaved;
                  });
                  try {
                    await ref
                        .read(savedPlacesControllerProvider.notifier)
                        .setSaved(place, nextSaved);
                  } catch (_) {}

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        nextSaved
                            ? '${place.name} disimpan'
                            : '${place.name} dihapus dari tersimpan',
                      ),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            },
          );
        }),
      ),
    );
  }
}
