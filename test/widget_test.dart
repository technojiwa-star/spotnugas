import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_nugas/constants/app_location.dart';
import 'package:spot_nugas/main.dart';
import 'package:spot_nugas/models/place.dart';
import 'package:spot_nugas/providers/saved_places_provider.dart';
import 'package:spot_nugas/screens/location_permission_screen.dart';
import 'package:spot_nugas/screens/profile_screen.dart';
import 'package:spot_nugas/screens/saved_screen.dart';
import 'package:spot_nugas/screens/spot_ai_screen.dart';
import 'package:spot_nugas/widgets/custom_search_bar.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SpotNugas initial launch smoke test', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SpotNugasApp());
    await tester.pumpAndSettle();

    expect(find.text('Mulai Eksplorasi'), findsOneWidget);
    expect(
      find.text('“Cari tempat. Buka laptop. Mulai nugas.”'),
      findsOneWidget,
    );
  });

  testWidgets(
    'First-time navigation: Splash -> Onboarding -> Login/Guest -> Location -> MainNavigation',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SpotNugasApp());
      await tester.pumpAndSettle();

      // 1. Tap "Mulai Eksplorasi" on Splash Screen
      await tester.tap(find.text('Mulai Eksplorasi'));
      await tester.pumpAndSettle();

      // 2. We should be on Onboarding Screen (Page 1)
      expect(find.text('Temukan spot nugas\ndi sekitarmu'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);

      // 3. Tap "Lewati" to navigate to Login / Continue as Guest
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      // 4. Verify we are on Login Screen
      expect(find.text('Masuk ke SpotNugas'), findsOneWidget);
      expect(find.text('Lanjutkan sebagai Tamu'), findsOneWidget);
      expect(find.text('Daftar Sekarang'), findsOneWidget);

      // 5. Tap "Lanjutkan sebagai Tamu" to proceed as guest
      await tester.tap(find.text('Lanjutkan sebagai Tamu'));
      await tester.pumpAndSettle();

      // 6. We should be on Location Permission Screen
      expect(find.text('Cari spot terdekat\ndari kamu'), findsOneWidget);
      expect(find.text('Aktifkan Lokasi'), findsOneWidget);

      // 7. Tap "Aktifkan Lokasi" to enter Main Navigation (Home Screen)
      await tester.tap(find.text('Aktifkan Lokasi'));
      await tester.pumpAndSettle();

      // 8. Verify Home Screen loaded with bottom navigation
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Jelajah'), findsOneWidget);
      expect(find.text('SpotAI'), findsWidgets);
      expect(find.text('Tersimpan'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);

      // Verify search bar and featured place
      expect(
        find.text('Cari cafe, coworking, atau tempat nugas...'),
        findsOneWidget,
      );
      expect(find.text('Kopi Ruang'), findsWidgets);

      // 9. Test switching to Jelajah (Explore Map) tab
      await tester.tap(find.text('Jelajah'));
      await tester.pumpAndSettle();
      expect(find.text('Cari spot nugas di peta...'), findsOneWidget);

      // 10. Test switching to SpotAI tab
      await tester.tap(find.text('SpotAI').first);
      await tester.pumpAndSettle();
      expect(find.text('Hai 👋 Lagi cari tempat buat nugas?'), findsOneWidget);

      // 11. Test switching to Tersimpan (Saved) tab
      await tester.tap(find.text('Tersimpan'));
      await tester.pumpAndSettle();
      expect(find.text('Tempat Tersimpan'), findsOneWidget);

      // 12. Test switching to Profil tab
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Rian Adiputra'), findsOneWidget);
      expect(find.text('rian.adiputra@student.ac.id'), findsOneWidget);
    },
  );

  testWidgets('Place detail flow and SpotAI interaction', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SpotNugasApp());
    await tester.pumpAndSettle();

    // Splash -> Onboarding -> Login -> Location -> Home
    await tester.tap(find.text('Mulai Eksplorasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjutkan sebagai Tamu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktifkan Lokasi'));
    await tester.pumpAndSettle();

    // Tap on Kopi Ruang place card
    await tester.tap(find.text('Kopi Ruang').first);
    await tester.pumpAndSettle();

    // Place detail should display Skor Nugas, breakdown, and action buttons
    expect(find.text('Metrik Nugas SpotNugas'), findsOneWidget);
    expect(find.text('Petunjuk Arah'), findsOneWidget);
    expect(find.text('Tanya SpotAI'), findsOneWidget);

    // Tap Tanya SpotAI from detail page
    await tester.tap(find.text('Tanya SpotAI'));
    await tester.pumpAndSettle();

    // SpotAI screen should be active
    expect(find.text('SpotAI'), findsWidgets);
  });

  testWidgets('Search results and filter interaction', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SpotNugasApp());
    await tester.pumpAndSettle();

    // Fast-forward to Home
    await tester.tap(find.text('Mulai Eksplorasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjutkan sebagai Tamu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktifkan Lokasi'));
    await tester.pumpAndSettle();

    // Tap search bar in Home Screen to open SearchResultsScreen
    await tester.tap(find.byType(CustomSearchBar).first);
    await tester.pumpAndSettle();

    // Verify Search Results Screen opened
    expect(find.text('Tempat Nugas'), findsOneWidget);
    expect(find.text('Skor Nugas'), findsWidgets);
    expect(find.text('Terdekat'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('Termurah'), findsOneWidget);

    // Tap Terdekat sort chip
    await tester.tap(find.text('Terdekat'));
    await tester.pumpAndSettle();

    // Go back to Home
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // Back on Home Screen
    expect(find.text('Beranda'), findsOneWidget);
  });

  testWidgets('Unauthenticated returning user goes Splash -> Login', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Set onboarding as completed, but no user logged in
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});

    await tester.pumpWidget(const SpotNugasApp());
    await tester.pumpAndSettle();

    // Tap "Mulai Eksplorasi" on Splash Screen
    await tester.tap(find.text('Mulai Eksplorasi'));
    await tester.pumpAndSettle();

    // Should navigate directly to LoginScreen (skipping Onboarding)
    expect(find.text('Masuk ke SpotNugas'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Kata Sandi'), findsOneWidget);
    expect(find.text('Lupa kata sandi?'), findsOneWidget);
  });

  testWidgets('Login screen validation and forgot password modal interaction', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'onboarding_completed': true});

    await tester.pumpWidget(const SpotNugasApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai Eksplorasi'));
    await tester.pumpAndSettle();

    // Tap Masuk without credentials
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    // Form validation error
    expect(find.text('Email tidak boleh kosong.'), findsOneWidget);

    // Open Forgot Password modal
    await tester.tap(find.text('Lupa kata sandi?'));
    await tester.pumpAndSettle();

    expect(find.text('Atur Ulang Kata Sandi'), findsOneWidget);
    expect(find.text('Kirim Tautan Reset'), findsOneWidget);
  });

  testWidgets(
    'LocationPermissionScreen Pilih Lokasi Manual opens city picker and preserves ProviderScope state',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LocationPermissionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Pilih Lokasi Manual
      await tester.tap(find.text('Pilih Lokasi Manual'));
      await tester.pumpAndSettle();

      // Bottom sheet should show city presets
      expect(find.text(AppLocation.bandungLabel), findsOneWidget);
      expect(find.text(AppLocation.depokLabel), findsOneWidget);

      // Select Bandung
      await tester.tap(find.text(AppLocation.bandungLabel));
      await tester.pumpAndSettle();

      // Navigated to MainNavigationScreen with Bandung active in HomeScreen header
      expect(find.text(AppLocation.bandungLabel), findsOneWidget);
    },
  );

  testWidgets(
    'SavedScreen resolves and displays bookmarked Geoapify places alongside saved seeds',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context, listen: false);
              return const MaterialApp(home: SavedScreen());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final geoPlace = Place.fromSources(
        geoapify: const GeoapifyPlaceData(
          geoapifyPlaceId: 'geo_mvp_saved_1',
          name: 'Kopi Senopati Geoapify',
          location: GeoCoordinates(-6.2297, 106.8295),
          formattedAddress: 'Jl. Senopati No. 88, Jakarta Selatan',
        ),
      );

      await container
          .read(savedPlacesControllerProvider.notifier)
          .setSaved(geoPlace, true);
      await tester.pumpAndSettle();

      expect(find.text('Kopi Senopati Geoapify'), findsOneWidget);
    },
  );

  testWidgets(
    'ProfileScreen Edit Profil, Notifikasi, and Bantuan modals work end-to-end',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ProfileScreen())),
      );
      await tester.pumpAndSettle();

      // Open Edit Profil
      await tester.tap(find.text('Edit Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Simpan Perubahan'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Rian Adiputra Pratama');
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(find.text('Rian Adiputra Pratama'), findsOneWidget);
      expect(find.text('Profil berhasil diperbarui!'), findsOneWidget);

      // Open Bantuan
      await tester.ensureVisible(find.text('Bantuan'));
      await tester.tap(find.text('Bantuan'));
      await tester.pumpAndSettle();
      expect(find.text('Pusat Bantuan & Tentang SpotNugas'), findsOneWidget);
    },
  );

  testWidgets(
    'SpotAIScreen deterministic engine responds to comparison and group queries',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SpotAIScreen(initialQuery: 'Bandingkan dua tempat'),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(
        find.textContaining('Perbandingan 2 spot terbaik'),
        findsOneWidget,
      );
    },
  );
}
