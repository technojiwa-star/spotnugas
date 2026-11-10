import '../constants/app_location.dart';
import '../models/google_place_data.dart';
import '../models/place.dart';
import '../models/spotnugas_place_data.dart';

/// Mock place data for C1, migrated from the former `DummyData.allPlaces`.
///
/// Each seed is split the same way real data will be:
/// - [GooglePlaceData]     → what Google Places would return (public info),
/// - [SpotNugasPlaceData]  → what `places/{placeId}` in Firestore would hold,
/// plus contextual mock values (distance, reviews, SpotAI annotations).
///
/// `selasar-belajar` is modelled as a **manual** place (not on Google) to
/// exercise that path; all others are Google-sourced with a SpotNugas
/// overlay. Rendered values are identical to the pre-C1 dummy data.
///
/// Only repositories (and SpotAI mock content) may import this file.
/// Screens must go through `placeRepositoryProvider`.
class PlaceMockData {
  PlaceMockData._();

  /// Explicit mock origin (Jl. Kaliurang km 5, Sleman) matching the offline seed dataset.
  static const GeoCoordinates defaultOrigin = AppLocation.mockYogyakartaOrigin;
  static const GeoCoordinates jakartaOrigin = AppLocation.defaultJakarta;

  /// Built once and shared for the app session (same instances everywhere).
  static final List<Place> places = List.unmodifiable(
    _seeds.map((seed) => seed.toPlace()),
  );

  static Place? byId(String id) {
    for (final place in places) {
      if (place.id == id ||
          place.geoapifyPlaceId == id ||
          place.googlePlaceId == id ||
          place.aliases.contains(id)) {
        return place;
      }
    }
    return null;
  }

  static final List<_MockPlaceSeed> _seeds = [
    // 1. Kopi Ruang — Google place, verified SpotNugas partner.
    _MockPlaceSeed(
      google: const GooglePlaceData(
        googlePlaceId: 'mock-gplace-kopi-ruang',
        name: 'Kopi Ruang',
        primaryType: 'Coffee shop',
        formattedAddress: 'Jl. Kaliurang km 5, Sleman, D.I. Yogyakarta',
        location: GeoCoordinates(-7.7610, 110.3845),
        rating: 4.7,
        userRatingCount: 142,
        priceLevel: PlacePriceLevel.moderate,
        openingHours: PlaceOpeningHours(statusLabel: 'Buka sampai 23.00'),
        isOpenNow: true,
        photoUrls: ['assets/images/kopi-ruang.jpg'],
      ),
      spotNugas: SpotNugasPlaceData.google(
        placeId: 'kopi-ruang',
        googlePlaceId: 'mock-gplace-kopi-ruang',
        category: 'Coffee Shop & Study Space',
        priceRange: const PlacePriceRange(minPrice: 25000, maxPrice: 50000),
        studyScore: 9.2,
        wifiScore: 4.8,
        outletScore: 4.6,
        comfortScore: 4.7,
        noiseScore: 4.3,
        priceValueScore: 4.2,
        facilities: const [
          PlaceFacility.wifi,
          PlaceFacility.powerOutlet,
          PlaceFacility.airConditioning,
          PlaceFacility.prayerRoom,
          PlaceFacility.parking,
          PlaceFacility.groupSeating,
        ],
        atmosphere: const [PlaceAtmosphere.calm],
        suitableFor: const [
          PlaceSuitability.soloFocus,
          PlaceSuitability.groupWork,
        ],
        tags: const ['Wi-Fi Cepat', 'Banyak Colokan', 'Tenang'],
        isVerifiedPartner: true,
        verifiedPartnerUid: 'mock-partner-uid-kopi-ruang',
      ),
      distanceKm: 0.85,
      initiallySaved: true,
      compatibilityScore: '90% cocok',
      whyRecommended:
          'Area semi-private lantai 2 sangat ramah kelompok, budget mulai Rp25 ribuan, colokan di tiap sudut meja.',
      reviews: const [
        PlaceReview(
          id: 'rev-1',
          userName: 'Nadia Salsabila',
          userAvatar: 'assets/images/kopi-ruang.jpg',
          rating: 5.0,
          date: '2 hari lalu',
          comment:
              'Wi-Fi cepat dan banyak colokan. Cocok banget buat nugas, tapi mulai ramai sekitar jam 5 sore. Es kopi susunya enak!',
          visitPurpose: 'Nugas Skripsi',
        ),
        PlaceReview(
          id: 'rev-2',
          userName: 'Bima Satria',
          userAvatar: 'assets/images/kopi-ruang.jpg',
          rating: 4.5,
          date: '1 minggu lalu',
          comment:
              'Mejanya cukup tinggi dan nyaman buat laptopan 4 jam nonstop. Playlist lagunya juga santai gak ganggu konsentrasi.',
          visitPurpose: 'Coding & Remote Work',
        ),
        PlaceReview(
          id: 'rev-3',
          userName: 'Fitri Wardani',
          userAvatar: 'assets/images/kopi-ruang.jpg',
          rating: 4.8,
          date: '2 minggu lalu',
          comment:
              'Musala bersih dan ber-AC di lantai 2. Ini nilai plus banget buat yang mau nugas dari siang sampai malam.',
          visitPurpose: 'Diskusi Kelompok',
        ),
      ],
    ),

    // 2. Ruang Temu Library & Cafe — Google place.
    _MockPlaceSeed(
      google: const GooglePlaceData(
        googlePlaceId: 'mock-gplace-ruang-temu',
        name: 'Ruang Temu Library & Cafe',
        primaryType: 'Library',
        formattedAddress: 'Jl. Sagan No. 12, Gondokusuman, Kota Yogyakarta',
        location: GeoCoordinates(-7.7780, 110.3790),
        rating: 4.9,
        userRatingCount: 215,
        priceLevel: PlacePriceLevel.inexpensive,
        openingHours: PlaceOpeningHours(statusLabel: 'Buka sampai 22.00'),
        isOpenNow: true,
        photoUrls: ['assets/images/ruang-temu-library.jpg'],
      ),
      spotNugas: SpotNugasPlaceData.google(
        placeId: 'ruang-temu',
        googlePlaceId: 'mock-gplace-ruang-temu',
        category: 'Perpustakaan & Cafe',
        priceRange: const PlacePriceRange(minPrice: 20000, maxPrice: 45000),
        studyScore: 9.5,
        wifiScore: 4.9,
        outletScore: 4.8,
        comfortScore: 4.9,
        noiseScore: 4.9,
        priceValueScore: 4.5,
        facilities: const [
          PlaceFacility.wifi,
          PlaceFacility.powerOutlet,
          PlaceFacility.airConditioning,
          PlaceFacility.prayerRoom,
          PlaceFacility.parking,
          PlaceFacility.quietZone,
        ],
        atmosphere: const [PlaceAtmosphere.silent],
        suitableFor: const [
          PlaceSuitability.soloFocus,
          PlaceSuitability.thesisResearch,
        ],
        tags: const ['Fokus Sendiri', 'Hening', 'Wi-Fi Cepat', 'Musala'],
      ),
      distanceKm: 1.2,
      initiallySaved: true,
      compatibilityScore: '84% cocok',
      whyRecommended:
          'Suasana paling hening untuk konsentrasi tinggi, banyak referensi buku dan meja privat bersekat.',
      reviews: const [
        PlaceReview(
          id: 'rev-4',
          userName: 'Dimas Anggara',
          userAvatar: 'assets/images/ruang-temu-library.jpg',
          rating: 5.0,
          date: 'Kemarin',
          comment:
              'Perpustakaan merangkap cafe impian mahasiswa! Super tenang, AC stabil dingin, kursi ergonomis buat marathon skripsi.',
          visitPurpose: 'Fokus Belajar Ujian',
        ),
        PlaceReview(
          id: 'rev-5',
          userName: 'Clara Devina',
          userAvatar: 'assets/images/ruang-temu-library.jpg',
          rating: 4.9,
          date: '5 hari lalu',
          comment:
              'Ada zona hening total di bagian dalam. Setiap meja dilengkapi colokan dan lampu baca tersendiri.',
          visitPurpose: 'Tesis & Riset',
        ),
      ],
    ),

    // 3. Taman Kolektif Coworking — Google place.
    _MockPlaceSeed(
      google: const GooglePlaceData(
        googlePlaceId: 'mock-gplace-taman-kolektif',
        name: 'Taman Kolektif Coworking',
        primaryType: 'Coworking space',
        formattedAddress: 'Jl. Affandi No. 8, Gejayan, Sleman',
        location: GeoCoordinates(-7.7725, 110.3888),
        rating: 4.8,
        userRatingCount: 180,
        priceLevel: PlacePriceLevel.moderate,
        openingHours: PlaceOpeningHours(statusLabel: 'Buka 24 Jam'),
        isOpenNow: true,
        photoUrls: ['assets/images/taman-kolektif.jpg'],
      ),
      spotNugas: SpotNugasPlaceData.google(
        placeId: 'taman-kolektif',
        googlePlaceId: 'mock-gplace-taman-kolektif',
        category: 'Coworking Space & Cafe',
        priceRange: const PlacePriceRange(minPrice: 35000, maxPrice: 70000),
        studyScore: 9.4,
        wifiScore: 5.0,
        outletScore: 4.9,
        comfortScore: 4.8,
        noiseScore: 4.2,
        priceValueScore: 4.0,
        facilities: const [
          PlaceFacility.wifi,
          PlaceFacility.powerOutlet,
          PlaceFacility.airConditioning,
          PlaceFacility.prayerRoom,
          PlaceFacility.parking,
          PlaceFacility.groupSeating,
          PlaceFacility.meetingRoom,
        ],
        atmosphere: const [PlaceAtmosphere.moderate],
        suitableFor: const [
          PlaceSuitability.groupWork,
          PlaceSuitability.lateNight,
          PlaceSuitability.remoteWork,
        ],
        tags: const [
          'Nugas Kelompok',
          'Banyak Colokan',
          'Buka Malam',
          'Wi-Fi Cepat',
        ],
      ),
      distanceKm: 1.8,
      initiallySaved: false,
      compatibilityScore: '94% cocok',
      whyRecommended:
          'Punya meja kelompok besar, colokan melimpah di setiap meja, dan Wi-Fi 100Mbps kencang untuk diskusi tim.',
      reviews: const [
        PlaceReview(
          id: 'rev-6',
          userName: 'Farhan Rizky',
          userAvatar: 'assets/images/taman-kolektif.jpg',
          rating: 5.0,
          date: '3 hari lalu',
          comment:
              'Internet 100 Mbps simetris, ada meeting room kecil buat nugas bareng tim. Free flow kopi lokal!',
          visitPurpose: 'Hackathon Project',
        ),
        PlaceReview(
          id: 'rev-7',
          userName: 'Alika Zahra',
          userAvatar: 'assets/images/taman-kolektif.jpg',
          rating: 4.7,
          date: '1 minggu lalu',
          comment:
              'Buka 24 jam jadi andalan pas deadline tugas besar mendekat. Tempatnya bersih dan stafnya ramah banget.',
          visitPurpose: 'Nugas Malam',
        ),
      ],
    ),

    // 4. Titik Tenang Coffee Roaster — Google place.
    _MockPlaceSeed(
      google: const GooglePlaceData(
        googlePlaceId: 'mock-gplace-titik-tenang',
        name: 'Titik Tenang Coffee Roaster',
        primaryType: 'Coffee roastery',
        formattedAddress: 'Jl. Palagan No. 15, Ngaglik, Sleman',
        location: GeoCoordinates(-7.7420, 110.3770),
        rating: 4.6,
        userRatingCount: 98,
        priceLevel: PlacePriceLevel.inexpensive,
        openingHours: PlaceOpeningHours(statusLabel: 'Buka sampai 00.00'),
        isOpenNow: true,
        photoUrls: ['assets/images/kopi-ruang.jpg'],
      ),
      spotNugas: SpotNugasPlaceData.google(
        placeId: 'titik-tenang',
        googlePlaceId: 'mock-gplace-titik-tenang',
        category: 'Specialty Coffee',
        priceRange: const PlacePriceRange(minPrice: 22000, maxPrice: 42000),
        studyScore: 9.0,
        wifiScore: 4.7,
        outletScore: 4.5,
        comfortScore: 4.6,
        noiseScore: 4.4,
        priceValueScore: 4.3,
        facilities: const [
          PlaceFacility.wifi,
          PlaceFacility.powerOutlet,
          PlaceFacility.airConditioning,
          PlaceFacility.prayerRoom,
          PlaceFacility.parking,
          PlaceFacility.outdoorSeating,
        ],
        atmosphere: const [PlaceAtmosphere.calm, PlaceAtmosphere.outdoor],
        suitableFor: const [
          PlaceSuitability.soloFocus,
          PlaceSuitability.budgetFriendly,
          PlaceSuitability.lateNight,
        ],
        tags: const ['Fokus Sendiri', 'Hemat', 'Buka Malam'],
      ),
      distanceKm: 2.1,
      initiallySaved: false,
      compatibilityScore: '82% cocok',
      whyRecommended:
          'Suasana outdoor asri berangin adem, cocok buat yang bosan nugas di ruangan ber-AC.',
      reviews: const [
        PlaceReview(
          id: 'rev-8',
          userName: 'Reza Pratama',
          userAvatar: 'assets/images/kopi-ruang.jpg',
          rating: 4.6,
          date: '4 hari lalu',
          comment:
              'Outdoor-nya rindang banyak pohon, ada colokan di tiang gazebo. Kopi V60-nya juara.',
          visitPurpose: 'Membaca & Ringkas Materi',
        ),
      ],
    ),

    // 5. Selasar Belajar Community Hub — MANUAL place (not on Google).
    //    Rating comes from the SpotNugas community aggregate.
    _MockPlaceSeed(
      spotNugas: SpotNugasPlaceData.manual(
        placeId: 'selasar-belajar',
        name: 'Selasar Belajar Community Hub',
        address: 'Jl. C. Simanjuntak No. 34, Terban, Kota Yogyakarta',
        location: const GeoCoordinates(-7.7810, 110.3730),
        photoUrls: const ['assets/images/ruang-temu-library.jpg'],
        priceLevel: PlacePriceLevel.inexpensive,
        openingHours: const PlaceOpeningHours(statusLabel: 'Buka sampai 23.30'),
        verificationStatus: PlaceVerificationStatus.verified,
        category: 'Student Hub & Workspace',
        priceRange: const PlacePriceRange(minPrice: 18000, maxPrice: 38000),
        studyScore: 9.3,
        wifiScore: 4.8,
        outletScore: 4.7,
        comfortScore: 4.6,
        noiseScore: 4.1,
        priceValueScore: 4.8,
        facilities: const [
          PlaceFacility.wifi,
          PlaceFacility.powerOutlet,
          PlaceFacility.airConditioning,
          PlaceFacility.prayerRoom,
          PlaceFacility.parking,
          PlaceFacility.groupSeating,
        ],
        atmosphere: const [PlaceAtmosphere.moderate],
        suitableFor: const [
          PlaceSuitability.budgetFriendly,
          PlaceSuitability.soloFocus,
          PlaceSuitability.groupWork,
        ],
        tags: const ['Hemat', 'Banyak Colokan', 'Fokus Sendiri', 'Wi-Fi Cepat'],
        communityRating: 4.8,
        communityRatingCount: 164,
      ),
      distanceKm: 1.4,
      initiallySaved: true,
      compatibilityScore: '89% cocok',
      whyRecommended:
          'Paket nugas hemat mulai Rp18.000 sudah dapat es teh jumbo & snack, meja luas.',
      reviews: const [
        PlaceReview(
          id: 'rev-9',
          userName: 'Arif Wibowo',
          userAvatar: 'assets/images/ruang-temu-library.jpg',
          rating: 4.9,
          date: '3 hari lalu',
          comment:
              'Tempat favorit anak-anak kampus sekitar. Makanan terjangkau porsi mengenyangkan.',
          visitPurpose: 'Tugas Kelompok',
        ),
      ],
    ),

    // 6. Kalandra Roastery & Deck — Google place.
    _MockPlaceSeed(
      google: const GooglePlaceData(
        googlePlaceId: 'mock-gplace-kalandra-roastery',
        name: 'Kalandra Roastery & Deck',
        primaryType: 'Cafe',
        formattedAddress: 'Jl. Seturan Raya No. 10, Caturtunggal, Sleman',
        location: GeoCoordinates(-7.7710, 110.4075),
        rating: 4.7,
        userRatingCount: 130,
        priceLevel: PlacePriceLevel.moderate,
        openingHours: PlaceOpeningHours(statusLabel: 'Buka sampai 01.00'),
        isOpenNow: true,
        photoUrls: ['assets/images/taman-kolektif.jpg'],
      ),
      spotNugas: SpotNugasPlaceData.google(
        placeId: 'kalandra-roastery',
        googlePlaceId: 'mock-gplace-kalandra-roastery',
        category: 'Roastery & Cafe',
        priceRange: const PlacePriceRange(minPrice: 28000, maxPrice: 55000),
        studyScore: 8.9,
        wifiScore: 4.6,
        outletScore: 4.4,
        comfortScore: 4.5,
        noiseScore: 4.0,
        priceValueScore: 4.1,
        facilities: const [
          PlaceFacility.wifi,
          PlaceFacility.powerOutlet,
          PlaceFacility.airConditioning,
          PlaceFacility.prayerRoom,
          PlaceFacility.parking,
          PlaceFacility.groupSeating,
        ],
        atmosphere: const [PlaceAtmosphere.lively],
        suitableFor: const [
          PlaceSuitability.groupWork,
          PlaceSuitability.lateNight,
        ],
        tags: const ['Buka Malam', 'Nugas Kelompok', 'Parkir Luas'],
      ),
      distanceKm: 2.5,
      initiallySaved: false,
      compatibilityScore: '87% cocok',
      whyRecommended:
          'Meja komunal panjang, parkir mobil & motor luas untuk rombongan, buka sampai jam 1 pagi.',
      reviews: const [
        PlaceReview(
          id: 'rev-10',
          userName: 'Jessica Melinda',
          userAvatar: 'assets/images/taman-kolektif.jpg',
          rating: 4.7,
          date: '6 hari lalu',
          comment:
              'Kalau butuh nugas bareng temen sekelas sampe larut malam, Kalandra selalu jadi pilihan pertama.',
          visitPurpose: 'Diskusi Project Akhir',
        ),
      ],
    ),
  ];
}

/// One mock place = source data + contextual mock values.
class _MockPlaceSeed {
  final GooglePlaceData? google;
  final SpotNugasPlaceData spotNugas;
  final double distanceKm;
  final bool initiallySaved;
  final String compatibilityScore;
  final String whyRecommended;
  final List<PlaceReview> reviews;

  const _MockPlaceSeed({
    this.google,
    required this.spotNugas,
    required this.distanceKm,
    this.initiallySaved = false,
    this.compatibilityScore = '',
    this.whyRecommended = '',
    this.reviews = const [],
  });

  Place toPlace() => Place.fromSources(
    google: google,
    spotNugas: spotNugas,
    distanceKm: distanceKm,
    reviews: reviews,
    compatibilityScore: compatibilityScore,
    whyRecommended: whyRecommended,
    isSaved: initiallySaved,
  );
}
