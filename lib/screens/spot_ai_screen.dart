import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/geoapify_config.dart';
import '../constants/app_colors.dart';
import '../data/dummy_data.dart';
import '../models/place.dart';
import '../models/chat_message.dart';
import '../providers/location_provider.dart';
import '../providers/place_provider.dart';
import '../widgets/place_card.dart';
import 'place_detail_screen.dart';

class SpotAIScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SpotAIScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SpotAIScreen> createState() => _SpotAIScreenState();
}

class _SpotAIScreenState extends ConsumerState<SpotAIScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  List<Place> _activePlaces = [];
  bool _isThinking = false;
  int _locationLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _messages = GeoapifyConfig.hasApiKey
        ? []
        : List.from(DummyData.initialChatMessages);
    _activePlaces = GeoapifyConfig.hasApiKey
        ? []
        : List.from(DummyData.allPlaces);
    _loadActivePlaces();

    if (widget.initialQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendMessage(widget.initialQuery!);
      });
    }
  }

  Future<void> _loadActivePlaces() async {
    final generation = ++_locationLoadGeneration;
    try {
      final location = ref.read(currentLocationProvider);
      if (!location.hasSelectedLocation) {
        _activePlaces = [];
        return;
      }
      final repo = ref.read(placeRepositoryProvider);
      final origin = location.coordinates;
      final fetched = await repo.getNearbyPlaces(origin: origin);
      if (mounted && generation == _locationLoadGeneration) {
        setState(() {
          _activePlaces = fetched;
        });
      }
    } catch (_) {
      if (mounted && generation == _locationLoadGeneration) {
        setState(() => _activePlaces = []);
      }
    }
  }

  String _activeLocationLabel() {
    try {
      return ref.read(currentLocationProvider).label;
    } catch (_) {
      return 'sekitarmu';
    }
  }

  Place _withAiAnnotation(
    Place p, {
    required String compatibility,
    required String reason,
  }) {
    if (p.compatibilityScore.isNotEmpty && p.whyRecommended.isNotEmpty) {
      return p;
    }
    return Place(
      id: p.id,
      source: p.source,
      geoapifyPlaceId: p.geoapifyPlaceId,
      googlePlaceId: p.googlePlaceId,
      aliases: p.aliases,
      name: p.name,
      category: p.category,
      description: p.description,
      address: p.address,
      latitude: p.latitude,
      longitude: p.longitude,
      priceLevel: p.priceLevel,
      priceRange: p.priceRange,
      googleRating: p.googleRating,
      googleRatingCount: p.googleRatingCount,
      openingHours: p.openingHours,
      isOpenNow: p.isOpenNow,
      photoUrls: p.photoUrls,
      studyScore: p.studyScore,
      wifiScore: p.wifiScore,
      outletScore: p.outletScore,
      comfortScore: p.comfortScore,
      noiseScore: p.noiseScore,
      priceValueScore: p.priceValueScore,
      facilities: p.facilities,
      atmosphere: p.atmosphere,
      suitableFor: p.suitableFor,
      tags: p.tags,
      communityRating: p.communityRating,
      communityRatingCount: p.communityRatingCount,
      verificationStatus: p.verificationStatus,
      isVerifiedPartner: p.isVerifiedPartner,
      verifiedPartnerUid: p.verifiedPartnerUid,
      isActive: p.isActive,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      distanceKm: p.distanceKm,
      reviews: p.reviews,
      compatibilityScore: p.compatibilityScore.isNotEmpty
          ? p.compatibilityScore
          : compatibility,
      whyRecommended: p.whyRecommended.isNotEmpty ? p.whyRecommended : reason,
      isSaved: p.isSaved,
    );
  }

  ChatMessage _buildDeterministicReply(String rawQuery) {
    final q = rawQuery.toLowerCase();
    final pool = _activePlaces.isNotEmpty || GeoapifyConfig.hasApiKey
        ? _activePlaces
        : DummyData.allPlaces;
    final locLabel = _activeLocationLabel();
    final msgId = 'ai-${DateTime.now().millisecondsSinceEpoch}';
    if (pool.isEmpty) {
      return ChatMessage(
        id: msgId,
        text:
            'Belum ada spot yang dapat direkomendasikan di $locLabel. '
            'Periksa lokasi dan koneksi, lalu coba lagi.',
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    // 1. Specific place inquiry (e.g. from PlaceDetailScreen "Tanya SpotAI")
    for (final place in [
      ...pool,
      if (!GeoapifyConfig.hasApiKey)
        ...DummyData.allPlaces.where((d) => !pool.any((p) => p.id == d.id)),
    ]) {
      if (q.contains(place.name.toLowerCase())) {
        final scoreStr = place.skorNugas > 0
            ? 'Skor Nugas ${place.skorNugas.toStringAsFixed(1)}/10 (${place.skorDescription})'
            : 'Kategori ${place.category}';
        final facStr = place.facilityLabels.isNotEmpty
            ? place.facilityLabels.take(4).join(', ')
            : 'area duduk nyaman untuk laptopan';
        final annotated = _withAiAnnotation(
          place,
          compatibility: '96% cocok',
          reason:
              '$scoreStr • Jam operasional: ${place.openStatus} • Estimasi: ${place.priceLabel}.',
        );
        return ChatMessage(
          id: msgId,
          text:
              'Analisis untuk ${place.name}: memiliki $scoreStr dengan fasilitas $facStr. Status buka: ${place.openStatus}, harga ${place.priceLabel}. Cocok untuk fokus maupun kerja laptop:',
          isUser: false,
          timestamp: DateTime.now(),
          places: [annotated],
        );
      }
    }

    // 2. Compare two places
    if (q.contains('bandingkan') || q.contains('vs')) {
      final sorted = List<Place>.from(pool)
        ..sort((a, b) => b.skorNugas.compareTo(a.skorNugas));
      final first = sorted.first;
      if (sorted.length < 2) {
        return ChatMessage(
          id: msgId,
          text:
              'Baru ada satu spot di $locLabel. Belum cukup untuk perbandingan.',
          isUser: false,
          timestamp: DateTime.now(),
          places: [first],
        );
      }
      final second = sorted[1];
      return ChatMessage(
        id: msgId,
        text:
            'Perbandingan 2 spot terbaik di $locLabel:\n'
            '1. ${first.name} (${first.category}, jarak ${first.distance}, harga ${first.priceLabel})\n'
            '2. ${second.name} (${second.category}, jarak ${second.distance}, harga ${second.priceLabel})',
        isUser: false,
        timestamp: DateTime.now(),
        places: [
          _withAiAnnotation(
            first,
            compatibility: '95% cocok',
            reason:
                'Unggul di ${first.category} (${first.distance}) • ${first.openStatus}.',
          ),
          _withAiAnnotation(
            second,
            compatibility: '91% cocok',
            reason:
                'Alternatif terbaik (${second.distance}) • ${second.openStatus}.',
          ),
        ],
      );
    }

    // 3. Quiet / Focus / Thesis
    if (q.contains('tenang') ||
        q.contains('hening') ||
        q.contains('skripsi') ||
        q.contains('fokus')) {
      final matches = List<Place>.from(pool)
        ..sort((a, b) {
          final aQuiet =
              (a.noiseScore ?? 0) +
              (a.category.toLowerCase().contains('perpustakaan') ? 2.0 : 0.0) +
              (a.tags.contains('Hening') ? 2.0 : 0.0);
          final bQuiet =
              (b.noiseScore ?? 0) +
              (b.category.toLowerCase().contains('perpustakaan') ? 2.0 : 0.0) +
              (b.tags.contains('Hening') ? 2.0 : 0.0);
          return bQuiet.compareTo(aQuiet);
        });
      final top = matches.take(2).toList();
      return ChatMessage(
        id: msgId,
        text:
            'Untuk kebutuhan fokus tinggi dan suasana tenang di $locLabel, ini ${top.length} tempat terbaik yang direkomendasikan:',
        isUser: false,
        timestamp: DateTime.now(),
        places: [
          for (var i = 0; i < top.length; i++)
            _withAiAnnotation(
              top[i],
              compatibility: '${96 - i * 4}% cocok',
              reason:
                  'Suasana kondusif untuk fokus belajar & skripsi (${top[i].distance}).',
            ),
        ],
      );
    }

    // 4. Budget / Cheap
    if (q.contains('50') ||
        q.contains('hemat') ||
        q.contains('murah') ||
        q.contains('budget')) {
      final matches = List<Place>.from(pool)
        ..sort((a, b) {
          final aScore =
              (a.priceValueScore ?? 0) +
              (a.priceLevel == PlacePriceLevel.free ||
                      a.priceLevel == PlacePriceLevel.inexpensive
                  ? 3.0
                  : 0.0);
          final bScore =
              (b.priceValueScore ?? 0) +
              (b.priceLevel == PlacePriceLevel.free ||
                      b.priceLevel == PlacePriceLevel.inexpensive
                  ? 3.0
                  : 0.0);
          return bScore.compareTo(aScore);
        });
      final top = matches.take(2).toList();
      return ChatMessage(
        id: msgId,
        text:
            'Ini rekomendasi spot nugas ramah kantong mahasiswa di sekitar $locLabel:',
        isUser: false,
        timestamp: DateTime.now(),
        places: [
          for (var i = 0; i < top.length; i++)
            _withAiAnnotation(
              top[i],
              compatibility: '${95 - i * 4}% cocok',
              reason:
                  'Ramah kantong mahasiswa (${top[i].priceLabel}) • Jarak ${top[i].distance}.',
            ),
        ],
      );
    }

    // 5. Fast Wi-Fi / Outlets
    if (q.contains('wi-fi') ||
        q.contains('wifi') ||
        q.contains('kencang') ||
        q.contains('cepat') ||
        q.contains('colokan')) {
      final matches = List<Place>.from(pool)
        ..sort((a, b) {
          final aTech = (a.wifiScore ?? 0) + (a.outletScore ?? 0);
          final bTech = (b.wifiScore ?? 0) + (b.outletScore ?? 0);
          return bTech.compareTo(aTech);
        });
      final top = matches.take(2).toList();
      return ChatMessage(
        id: msgId,
        text:
            'Ini tempat dengan dukungan Wi-Fi & colokan terbaik untuk laptopan:',
        isUser: false,
        timestamp: DateTime.now(),
        places: [
          for (var i = 0; i < top.length; i++)
            _withAiAnnotation(
              top[i],
              compatibility: '${96 - i * 3}% cocok',
              reason:
                  'Ideal untuk laptopan lama • ${top[i].category} (${top[i].distance}).',
            ),
        ],
      );
    }

    // 6. Group work / Coworking
    if (q.contains('kelompok') ||
        q.contains('diskusi') ||
        q.contains('tim') ||
        q.contains('coworking')) {
      final matches = List<Place>.from(pool)
        ..sort((a, b) {
          final aGroup =
              (a.tags.contains('Nugas Kelompok') ? 3.0 : 0.0) +
              (a.category.toLowerCase().contains('coworking') ? 2.0 : 0.0) +
              a.skorNugas;
          final bGroup =
              (b.tags.contains('Nugas Kelompok') ? 3.0 : 0.0) +
              (b.category.toLowerCase().contains('coworking') ? 2.0 : 0.0) +
              b.skorNugas;
          return bGroup.compareTo(aGroup);
        });
      final top = matches.take(2).toList();
      return ChatMessage(
        id: msgId,
        text:
            'Untuk diskusi dan kerja kelompok di sekitar $locLabel, ini ${top.length} spot yang paling pas:',
        isUser: false,
        timestamp: DateTime.now(),
        places: [
          for (var i = 0; i < top.length; i++)
            _withAiAnnotation(
              top[i],
              compatibility: '${94 - i * 4}% cocok',
              reason:
                  'Meja kondusif untuk diskusi kelompok • ${top[i].openStatus}.',
            ),
        ],
      );
    }

    // 7. Default: Nearby / Best Study Score around active location
    final nearbySorted = List<Place>.from(pool)
      ..sort((a, b) {
        final distCmp = (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999);
        if (distCmp != 0) return distCmp;
        return b.skorNugas.compareTo(a.skorNugas);
      });
    final top = nearbySorted.take(2).toList();
    return ChatMessage(
      id: msgId,
      text:
          'Berdasarkan pencocokan kriteria di sekitar $locLabel, tempat ini paling pas buat kamu:',
      isUser: false,
      timestamp: DateTime.now(),
      places: [
        for (var i = 0; i < top.length; i++)
          _withAiAnnotation(
            top[i],
            compatibility: '${93 - i * 3}% cocok',
            reason:
                '${top[i].category} berjarak ${top[i].distance} • ${top[i].openStatus}.',
          ),
      ],
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _inputController.clear();
      _isThinking = true;
    });

    _scrollToBottom();

    // Deterministic local smart recommendation engine
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final aiReply = _buildDeterministicReply(text);

      setState(() {
        _isThinking = false;
        _messages.add(aiReply);
      });

      _scrollToBottom();
    });
  }

  void _openPlaceDetail(Place place) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlaceDetailScreen(place: place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      ref.listen<LocationState>(currentLocationProvider, (previous, next) {
        if (previous?.coordinates != next.coordinates ||
            previous?.hasSelectedLocation != next.hasSelectedLocation) {
          _activePlaces = [];
          _loadActivePlaces();
        }
      });
    } catch (_) {
      // Isolated offline previews may omit ProviderScope.
    }
    return Scaffold(
      backgroundColor: AppColors.lightCreamBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SpotAI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Asisten Pintar Nugasmu',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.primaryTealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat Messages List
            Expanded(
              child: ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  // Friendly Brand Welcome Banner
                  _buildWelcomeCard(),
                  const SizedBox(height: 16),

                  // Messages list
                  for (final msg in _messages) ...[
                    _buildChatBubble(msg),
                    const SizedBox(height: 14),
                  ],

                  // Thinking Indicator
                  if (_isThinking) ...[
                    _buildThinkingIndicator(),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),

            // Horizontal Suggested Questions Chips
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: DummyData.spotAiSuggestedQuestions.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final suggestion = DummyData.spotAiSuggestedQuestions[index];
                  return GestureDetector(
                    onTap: () => _handleSendMessage(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: AppColors.primaryTeal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            suggestion,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Input Field Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppColors.cardBorder.withOpacity(0.5)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.lightCreamBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: TextField(
                        controller: _inputController,
                        onSubmitted: _handleSendMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ketik kebutuhan nugasmu...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handleSendMessage(_inputController.text),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
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

  // Greeting Banner
  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryTealLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryTeal.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const Expanded(
                child: Text(
                  'Hai 👋 Lagi cari tempat buat nugas?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Beri tahu SpotAI preferensimu (jarak, colokan, Wi-Fi, budget, atau suasana). Aku carikan tempat yang paling akurat!',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textBody,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Chat Bubble
  Widget _buildChatBubble(ChatMessage message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 290),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.terracottaBrown,
            borderRadius: BorderRadius.circular(
              18,
            ).copyWith(bottomRight: const Radius.circular(4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    // SpotAI Bubble
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primaryTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    18,
                  ).copyWith(topLeft: const Radius.circular(4)),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Recommendation Cards (if any)
        if (message.places != null && message.places!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Column(
              children: message.places!.map((p) {
                return PlaceCard(
                  place: p,
                  cardType: PlaceCardType.compactAi,
                  onTap: () => _openPlaceDetail(p),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  // Thinking Animation Indicator
  Widget _buildThinkingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: AppColors.primaryTeal,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'SpotAI sedang menganalisis...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
