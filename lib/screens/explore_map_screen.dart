import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../config/geoapify_config.dart';
import '../constants/app_colors.dart';
import '../models/place.dart';
import '../providers/location_provider.dart';
import '../providers/place_provider.dart';
import '../providers/saved_places_provider.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/place_card.dart';
import 'place_detail_screen.dart';

class ExploreMapScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;

  const ExploreMapScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends ConsumerState<ExploreMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  bool _isMapView = true;
  double _currentZoom = 14.0;
  String _selectedFilter = 'Semua';
  String _searchQuery = '';
  Place? _selectedPlace;
  List<Place> _places = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _loadGeneration = 0;
  bool _showStudyHotspotsOnly = false;

  final List<String> _filters = [
    'Semua',
    'Jarak (<2km)',
    'Harga Hemat',
    'Wi-Fi Cepat',
    'Banyak Colokan',
    'Suasana Tenang',
    'Buka Sekarang',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final text = _searchController.text;
      if (text != _searchQuery) {
        setState(() {
          _searchQuery = text;
          final filtered = _filteredPlaces;
          if (!filtered.any((p) => p.id == _selectedPlace?.id)) {
            _selectedPlace = filtered.isNotEmpty ? filtered.first : null;
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlaces();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    final location = ref.read(currentLocationProvider);
    setState(() {
      _places = [];
      _selectedPlace = null;
      _errorMessage = null;
      _isLoading = location.hasSelectedLocation;
    });
    if (!location.hasSelectedLocation) return;

    try {
      final repo = ref.read(placeRepositoryProvider);
      final places = await repo.getNearbyPlaces(origin: location.coordinates);
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _places = places;
          final filtered = _filteredPlaces;
          if (_selectedPlace == null ||
              !filtered.any((p) => p.id == _selectedPlace!.id)) {
            _selectedPlace = filtered.isNotEmpty ? filtered.first : null;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _errorMessage =
              'Gagal memuat tempat nugas. Periksa koneksi lalu coba lagi.';
          _isLoading = false;
        });
      }
    }
  }

  List<Place> get _filteredPlaces {
    var result = List<Place>.from(_places);

    if (_showStudyHotspotsOnly) {
      result = result
          .where((p) => (p.studyScore ?? p.skorNugas) >= 4.5)
          .toList();
    }

    switch (_selectedFilter) {
      case 'Jarak (<2km)':
        result = result.where((p) {
          if (p.distanceKm != null) return p.distanceKm! <= 2.0;
          final d = p.distance.toLowerCase();
          if (d.contains('m') && !d.contains('km')) return true;
          final km = double.tryParse(d.replaceAll(RegExp(r'[^0-9.]'), ''));
          return km != null && km <= 2.0;
        }).toList();
        break;
      case 'Harga Hemat':
        result = result
            .where(
              (p) =>
                  p.priceLevel == PlacePriceLevel.free ||
                  p.priceLevel == PlacePriceLevel.inexpensive ||
                  p.priceLabel.toLowerCase().contains('hemat'),
            )
            .toList();
        break;
      case 'Wi-Fi Cepat':
        result = result
            .where(
              (p) =>
                  (p.wifiScore != null && p.wifiScore! >= 4.0) ||
                  p.facilities.contains(PlaceFacility.wifi) ||
                  p.tags.any((t) => t.toLowerCase().contains('wifi')),
            )
            .toList();
        break;
      case 'Banyak Colokan':
        result = result
            .where(
              (p) =>
                  (p.outletScore != null && p.outletScore! >= 4.0) ||
                  p.facilities.contains(PlaceFacility.powerOutlet) ||
                  p.tags.any((t) => t.toLowerCase().contains('colokan')),
            )
            .toList();
        break;
      case 'Suasana Tenang':
        result = result
            .where(
              (p) =>
                  (p.noiseScore != null && p.noiseScore! >= 4.0) ||
                  p.atmosphere.contains(PlaceAtmosphere.calm) ||
                  p.atmosphere.contains(PlaceAtmosphere.silent) ||
                  p.tags.any((t) => t.toLowerCase().contains('tenang')),
            )
            .toList();
        break;
      case 'Buka Sekarang':
        result = result.where((p) => p.isOpenNow == true).toList();
        break;
      case 'Semua':
      default:
        break;
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.category.toLowerCase().contains(query) ||
            (p.address != null && p.address!.toLowerCase().contains(query));
      }).toList();
    }

    return result;
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

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      final targetZoom = (currentZoom + 1).clamp(3.0, 18.0);
      _mapController.move(_mapController.camera.center, targetZoom);
      setState(() {
        _currentZoom = targetZoom;
      });
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      final targetZoom = (currentZoom - 1).clamp(3.0, 18.0);
      _mapController.move(_mapController.camera.center, targetZoom);
      setState(() {
        _currentZoom = targetZoom;
      });
    } catch (_) {}
  }

  Future<void> _recenter() async {
    try {
      await ref
          .read(currentLocationProvider.notifier)
          .detectDeviceLocation(force: true);
    } catch (_) {}

    if (!mounted) return;
    final location = ref.read(currentLocationProvider);
    if (!location.hasSelectedLocation ||
        location.source != LocationSource.deviceGps ||
        location.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lokasi perangkat belum tersedia. Pilih kota di Beranda atau coba lagi.',
          ),
        ),
      );
      return;
    }
    await _loadPlaces();
    if (!mounted) return;

    final coords = _getUserCoordinates();
    try {
      _mapController.move(LatLng(coords.latitude, coords.longitude), 14.5);
      setState(() {
        _currentZoom = 14.5;
      });
    } catch (_) {}

    if (!mounted) return;
    final label = ref.read(currentLocationLabelProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lokasi dipusatkan ke $label'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryTealDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleLayer() {
    setState(() {
      _showStudyHotspotsOnly = !_showStudyHotspotsOnly;
      final filtered = _filteredPlaces;
      if (filtered.isNotEmpty &&
          !filtered.any((p) => p.id == _selectedPlace?.id)) {
        _selectedPlace = filtered.first;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _showStudyHotspotsOnly
              ? 'Menampilkan hotspot area ramah nugas'
              : 'Mode peta standar',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryTealDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  GeoCoordinates _getUserCoordinates() {
    return ref.read(currentLocationProvider).coordinates;
  }

  Future<void> _launchDirections(
    double lat,
    double lng,
    String placeName,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Membuka rute ke $placeName'),
            backgroundColor: AppColors.primaryTealDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Membuka rute ke $placeName'),
            backgroundColor: AppColors.primaryTealDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocationState>(currentLocationProvider, (prev, next) {
      if (prev?.coordinates != next.coordinates ||
          prev?.hasSelectedLocation != next.hasSelectedLocation) {
        _loadPlaces();
        if (next.hasSelectedLocation) {
          try {
            _mapController.move(
              LatLng(next.coordinates.latitude, next.coordinates.longitude),
              14.0,
            );
          } catch (_) {}
        }
      }
    });
    final location = ref.watch(currentLocationProvider);

    final userCoords = _getUserCoordinates();
    final userLatLng = LatLng(userCoords.latitude, userCoords.longitude);

    return Scaffold(
      backgroundColor: AppColors.lightCreamBackground,
      body: SafeArea(
        top: true,
        bottom: true,
        child: !location.hasSelectedLocation
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_off_outlined, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Pilih lokasi di Beranda atau gunakan GPS untuk menjelajah tempat nugas.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: location.isLoading ? null : _recenter,
                        icon: const Icon(Icons.my_location_rounded),
                        label: Text(
                          location.isLoading
                              ? 'Mendeteksi lokasi...'
                              : 'Gunakan GPS',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _isMapView
            ? Stack(
                children: [
                  // 1. Realistic & Interactive Map Canvas using flutter_map
                  Positioned.fill(child: _buildMapCanvas(userLatLng)),

                  // 2. Top Controls Overlay: Search Bar, Toggle & Category Filter Chips
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopControls(),
                  ),

                  // 3. Floating Map Controls (Re-center, Zoom In/Out, Layer)
                  Positioned(
                    right: 16,
                    bottom: 172,
                    child: _buildMapControls(),
                  ),

                  // 4. Place Preview Card / Bottom Sheet (above bottom navigation)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _buildBottomSelectedCard(),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildTopControls(),
                  Expanded(child: _buildListView()),
                ],
              ),
      ),
    );
  }

  // Top Controls: Search Bar, Map/List Toggle, Horizontal Filter Chips
  Widget _buildTopControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Bar & Map/List Toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: CustomSearchBar(
                  controller: _searchController,
                  hintText: 'Cari spot nugas di peta...',
                  readOnly: false,
                ),
              ),
              const SizedBox(width: 8),
              // Toggle Button Map / List
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isMapView = !_isMapView;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isMapView
                            ? Icons.format_list_bulleted_rounded
                            : Icons.map_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isMapView ? 'List' : 'Peta',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Filter Chips Horizontal List
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = _selectedFilter == filter;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter;
                    final filtered = _filteredPlaces;
                    if (filtered.isNotEmpty &&
                        !filtered.any((p) => p.id == _selectedPlace?.id)) {
                      _selectedPlace = filtered.first;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textDark
                        : Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textDark
                          : AppColors.cardBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryTeal,
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 6),
      ],
    );
  }

  // Floating Map Controls
  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Re-center button
        _buildMapControlButton(
          icon: Icons.my_location_rounded,
          tooltip: 'Lokasi Saya',
          onTap: _recenter,
        ),
        const SizedBox(height: 8),
        // Zoom in button
        _buildMapControlButton(
          icon: Icons.add_rounded,
          tooltip: 'Perbesar',
          onTap: _zoomIn,
        ),
        const SizedBox(height: 4),
        // Zoom out button
        _buildMapControlButton(
          icon: Icons.remove_rounded,
          tooltip: 'Perkecil',
          onTap: _zoomOut,
        ),
        const SizedBox(height: 8),
        // Layer toggle button
        _buildMapControlButton(
          icon: Icons.layers_rounded,
          tooltip: 'Lapisan Peta',
          color: _showStudyHotspotsOnly ? AppColors.terracottaBrown : null,
          iconColor: _showStudyHotspotsOnly ? Colors.white : AppColors.textDark,
          onTap: _toggleLayer,
        ),
      ],
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color ?? Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: iconColor ?? AppColors.textDark),
          ),
        ),
      ),
    );
  }

  // Interactive Map Canvas using flutter_map with real venue markers, clustering, and GPS
  Widget _buildMapCanvas(LatLng userLatLng) {
    final filtered = _filteredPlaces;
    final clusters = _computeClusters(
      places: filtered,
      zoom: _currentZoom,
      selectedPlace: _selectedPlace,
    );

    final markers = <Marker>[
      // User location marker
      Marker(
        point: userLatLng,
        width: 120,
        height: 75,
        alignment: Alignment.center,
        child: OverflowBox(
          maxWidth: 200,
          maxHeight: 100,
          child: _buildUserLocationIndicator(),
        ),
      ),
      // Clustered or individual place markers
      for (final cluster in clusters)
        if (cluster.isSingle)
          Marker(
            key: Key('marker_${cluster.place.id}'),
            point: cluster.center,
            width: 120,
            height: 65,
            alignment: Alignment.topCenter,
            child: OverflowBox(
              maxWidth: 200,
              maxHeight: 100,
              child: _buildMapMarker(
                place: cluster.place,
                isSelected: _selectedPlace?.id == cluster.place.id,
              ),
            ),
          )
        else
          Marker(
            key: Key('marker_${cluster.id}'),
            point: cluster.center,
            width: 70,
            height: 70,
            alignment: Alignment.center,
            child: OverflowBox(
              maxWidth: 120,
              maxHeight: 120,
              child: _buildClusterMarker(cluster),
            ),
          ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: userLatLng,
        initialZoom: _currentZoom,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onPositionChanged: (camera, hasGesture) {
          final zoom = camera.zoom;
          if ((zoom - _currentZoom).abs() >= 0.3) {
            setState(() {
              _currentZoom = zoom;
            });
          }
        },
      ),
      children: [
        // Map Tiles (Geoapify raster tiles or OpenStreetMap fallback)
        TileLayer(
          urlTemplate: GeoapifyConfig.tileUrlTemplate,
          tileProvider: NetworkTileProvider(silenceExceptions: true),
          userAgentPackageName: 'com.spotnugas.app',
          maxZoom: 19,
        ),

        // User location pulsing halo
        CircleLayer(
          circles: [
            CircleMarker(
              point: userLatLng,
              radius: 45,
              useRadiusInMeter: true,
              color: AppColors.primaryTeal.withOpacity(0.18),
              borderColor: AppColors.primaryTeal.withOpacity(0.35),
              borderStrokeWidth: 1.5,
            ),
          ],
        ),

        // Place and User Markers
        MarkerLayer(markers: markers),

        // Map Attribution Overlay
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                GeoapifyConfig.attributionText,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper to group nearby markers at low zoom into clusters
  List<_MapCluster> _computeClusters({
    required List<Place> places,
    required double zoom,
    required Place? selectedPlace,
  }) {
    if (places.isEmpty) return const [];

    // At high zoom (>= 13.5), reveal all individual venues
    if (zoom >= 13.5) {
      return places
          .map(
            (p) => _MapCluster(
              id: p.id,
              center: LatLng(p.latitude, p.longitude),
              places: [p],
            ),
          )
          .toList();
    }

    // At low zoom (< 13.5), cluster nearby venues within a zoom-dependent threshold
    final double threshold =
        0.015 * math.pow(2.0, (13.0 - zoom).clamp(0.0, 10.0));

    final List<_MapCluster> clusters = [];
    final Set<String> processedIds = {};

    final List<Place> sortedPlaces = List<Place>.from(places);
    if (selectedPlace != null) {
      final selIdx = sortedPlaces.indexWhere((p) => p.id == selectedPlace.id);
      if (selIdx > 0) {
        final sel = sortedPlaces.removeAt(selIdx);
        sortedPlaces.insert(0, sel);
      }
    }

    for (final place in sortedPlaces) {
      if (processedIds.contains(place.id)) continue;

      // Selected place remains individually identifiable at all zoom levels!
      if (selectedPlace != null && place.id == selectedPlace.id) {
        processedIds.add(place.id);
        clusters.add(
          _MapCluster(
            id: place.id,
            center: LatLng(place.latitude, place.longitude),
            places: [place],
          ),
        );
        continue;
      }

      final group = <Place>[place];
      processedIds.add(place.id);

      for (final other in sortedPlaces) {
        if (processedIds.contains(other.id)) continue;
        if (selectedPlace != null && other.id == selectedPlace.id) continue;

        final dLat = (place.latitude - other.latitude).abs();
        final dLng = (place.longitude - other.longitude).abs();
        if (dLat <= threshold && dLng <= threshold) {
          group.add(other);
          processedIds.add(other.id);
        }
      }

      if (group.length == 1) {
        clusters.add(
          _MapCluster(
            id: place.id,
            center: LatLng(place.latitude, place.longitude),
            places: group,
          ),
        );
      } else {
        double sumLat = 0;
        double sumLng = 0;
        for (final p in group) {
          sumLat += p.latitude;
          sumLng += p.longitude;
        }
        final center = LatLng(sumLat / group.length, sumLng / group.length);
        final clusterId = 'cluster_${group.first.id}_${group.length}';
        clusters.add(_MapCluster(id: clusterId, center: center, places: group));
      }
    }

    return clusters;
  }

  // Realistic User Location Indicator
  Widget _buildUserLocationIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryTeal,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTealDark.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.navigation_rounded,
                size: 10,
                color: AppColors.primaryTeal,
              ),
              SizedBox(width: 3),
              Text(
                'Kamu di sini',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryTealDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Clustered Venue Marker with Count and Tap-to-Zoom Interaction
  Widget _buildClusterMarker(_MapCluster cluster) {
    final hasSelected = cluster.places.any((p) => p.id == _selectedPlace?.id);
    final count = cluster.places.length;

    return GestureDetector(
      onTap: () {
        try {
          final targetZoom = (_currentZoom + 2.5).clamp(3.0, 18.0);
          _mapController.move(cluster.center, targetZoom);
          setState(() {
            _currentZoom = targetZoom;
            _selectedPlace = cluster.places.first;
          });
        } catch (_) {}
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasSelected
                  ? AppColors.terracottaBrown
                  : AppColors.primaryTeal,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color:
                      (hasSelected
                              ? AppColors.terracottaDark
                              : AppColors.primaryTealDark)
                          .withOpacity(0.40),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_cafe_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 2),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasSelected
                    ? AppColors.terracottaBrown
                    : AppColors.cardBorder,
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '$count Spot',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: hasSelected
                    ? AppColors.terracottaBrown
                    : AppColors.primaryTealDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Interactive Place Map Marker with Category Icon and Skor Nugas or 'Belum Dinilai'
  Widget _buildMapMarker({required Place place, required bool isSelected}) {
    final catLower = place.category.toLowerCase();
    final IconData categoryIcon =
        (catLower.contains('library') || catLower.contains('perpustakaan'))
        ? Icons.local_library_rounded
        : (catLower.contains('coworking') || catLower.contains('office'))
        ? Icons.work_outline_rounded
        : Icons.coffee_rounded;

    final markerColor = isSelected
        ? AppColors.terracottaBrown
        : AppColors.primaryTeal;
    final shadowColor = isSelected
        ? AppColors.terracottaDark
        : AppColors.primaryTealDark;

    final bool hasValidScore = place.skorNugas > 0;
    final String scoreLabel = hasValidScore
        ? place.skorNugas.toStringAsFixed(1)
        : 'Belum Dinilai';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlace = place;
        });
      },
      child: AnimatedScale(
        scale: isSelected ? 1.10 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: markerColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor.withOpacity(0.35),
                    blurRadius: isSelected ? 10 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(categoryIcon, color: Colors.white, size: 12),
                  const SizedBox(width: 3.5),
                  Text(
                    scoreLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            // Pointer triangle
            CustomPaint(
              size: const Size(10, 6),
              painter: _TrianglePainter(color: markerColor),
            ),
            const SizedBox(height: 2),
            // Place name pill
            Container(
              constraints: const BoxConstraints(maxWidth: 105),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected
                      ? AppColors.terracottaBrown
                      : AppColors.cardBorder,
                  width: isSelected ? 1.0 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                place.name,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.terracottaBrown
                      : AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Selected Place Bottom Card in Map View (Rich Venue Preview Card)
  Widget _buildBottomSelectedCard() {
    final place = _selectedPlace;
    if (place == null || _filteredPlaces.isEmpty) {
      if (_filteredPlaces.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _buildDiscoveryState(compact: true),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildPlaceThumbnail(place),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: place.skorNugas > 0
                                  ? AppColors.primaryTealSurface
                                  : AppColors.warmBeigeLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: place.skorNugas > 0
                                    ? AppColors.primaryTeal.withOpacity(0.25)
                                    : AppColors.cardBorder,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              place.skorNugas > 0
                                  ? 'Skor Nugas ${place.skorNugas.toStringAsFixed(1)}'
                                  : 'Belum Dinilai',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: place.skorNugas > 0
                                    ? AppColors.primaryTealDark
                                    : AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          place.distance,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${place.category} • ${place.priceLabel}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openPlaceDetail(place),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryTealDark,
                    side: const BorderSide(color: AppColors.primaryTeal),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Lihat Detail',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: const Key('route_button'),
                onPressed: () => _launchDirections(
                  place.latitude,
                  place.longitude,
                  place.name,
                ),
                icon: const Icon(Icons.directions_rounded, size: 16),
                label: const Text(
                  'Rute',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceThumbnail(Place place) {
    final imgUrl = place.image;
    final isNetwork =
        imgUrl.startsWith('http://') || imgUrl.startsWith('https://');

    if (imgUrl.isEmpty) {
      return Container(
        width: 70,
        height: 70,
        color: AppColors.warmBeigeLight,
        child: const Icon(
          Icons.coffee_rounded,
          color: AppColors.primaryTeal,
          size: 28,
        ),
      );
    }

    if (isNetwork) {
      return Image.network(
        imgUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 70,
          height: 70,
          color: AppColors.warmBeigeLight,
          child: const Icon(
            Icons.coffee_rounded,
            color: AppColors.primaryTeal,
            size: 28,
          ),
        ),
      );
    }

    return Image.asset(
      imgUrl,
      width: 70,
      height: 70,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 70,
        height: 70,
        color: AppColors.warmBeigeLight,
        child: const Icon(
          Icons.coffee_rounded,
          color: AppColors.primaryTeal,
          size: 28,
        ),
      ),
    );
  }

  // Alternative List View
  Widget _buildListView() {
    final filtered = _filteredPlaces;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildDiscoveryState(),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPlaces,
      color: AppColors.primaryTeal,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        itemCount: filtered.length + 1,
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  GeoapifyConfig.attributionText,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            );
          }
          final place = filtered[index];
          return PlaceCard(
            place: place,
            cardType: PlaceCardType.vertical,
            onTap: () => _openPlaceDetail(place),
            onBookmarkToggle: () async {
              final nextSaved = !place.isSaved;
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
                        ? '${place.name} disimpan ke Favorit'
                        : '${place.name} dihapus dari Tersimpan',
                  ),
                  duration: const Duration(seconds: 1),
                  backgroundColor: AppColors.primaryTealDark,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDiscoveryState({bool compact = false}) {
    final message = _isLoading
        ? 'Mencari tempat nugas di sekitar lokasi...'
        : _errorMessage ??
              (compact
                  ? (_places.isEmpty
                        ? 'Belum ada tempat nugas ditemukan di sekitar lokasi ini.'
                        : 'Tidak ada spot nugas dengan filter ini.')
                  : 'Tidak ada tempat nugas ditemukan.');
    final canRetry = _errorMessage != null || _places.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoading)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            _errorMessage != null
                ? Icons.cloud_off_rounded
                : Icons.search_off_rounded,
            size: compact ? 24 : 48,
            color: AppColors.textMuted,
          ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        if (!_isLoading)
          TextButton(
            onPressed: canRetry
                ? _loadPlaces
                : () {
                    setState(() {
                      _selectedFilter = 'Semua';
                      _searchController.clear();
                      _searchQuery = '';
                      _selectedPlace = _places.isNotEmpty
                          ? _places.first
                          : null;
                    });
                  },
            child: Text(
              canRetry ? 'Coba Lagi' : 'Reset Filter & Pencarian',
              style: const TextStyle(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// Custom Painter for Map Marker Triangle
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Map Cluster data model for low-zoom grouping
class _MapCluster {
  final String id;
  final LatLng center;
  final List<Place> places;

  const _MapCluster({
    required this.id,
    required this.center,
    required this.places,
  });

  bool get isSingle => places.length == 1;
  Place get place => places.first;
}
