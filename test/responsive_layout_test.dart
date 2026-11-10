import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot_nugas/screens/onboarding_screen.dart';
import 'package:spot_nugas/screens/main_navigation_screen.dart';

void main() {
  group('Issue 2: Onboarding Screen Responsiveness & Overflow Tests', () {
    const screenSizes = [
      (
        'iPhone 17 (402x874)',
        Size(402, 874),
        EdgeInsets.only(top: 59, bottom: 34),
      ),
      (
        'iPhone 15/16 Pro Max (430x932)',
        Size(430, 932),
        EdgeInsets.only(top: 59, bottom: 34),
      ),
      (
        'Standard iPhone (390x844)',
        Size(390, 844),
        EdgeInsets.only(top: 47, bottom: 34),
      ),
      (
        'iPhone SE 3rd gen (375x667)',
        Size(375, 667),
        EdgeInsets.only(top: 20, bottom: 0),
      ),
      (
        'Small Android Phone (360x640)',
        Size(360, 640),
        EdgeInsets.only(top: 24, bottom: 0),
      ),
    ];

    for (final (device, size, padding) in screenSizes) {
      testWidgets('Onboarding Screen Page 2 has 0 overflow on $device', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = FakeViewPadding(
          top: padding.top,
          bottom: padding.bottom,
          left: padding.left,
          right: padding.right,
        );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);

        await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
        await tester.pumpAndSettle();

        // 1. Verify Page 1
        expect(find.text('Temukan spot nugas\ndi sekitarmu'), findsOneWidget);

        // Advance to Page 2
        await tester.tap(find.text('Lanjut'));
        await tester.pumpAndSettle();

        // Verify all 5 feature rows are visible and intact
        expect(find.text('Wi-Fi Cepat & Stabil'), findsOneWidget);
        expect(find.text('Colokan Melimpah'), findsOneWidget);
        expect(find.text('Harga Mahasiswa (Hemat)'), findsOneWidget);
        expect(find.text('Suasana Tenang / Ramai'), findsOneWidget);
        expect(find.text('Jarak Terdekat dari Kamu'), findsOneWidget);

        // Verify title, description, and action button are visible
        expect(find.text('Cari sesuai kebutuhanmu'), findsOneWidget);
        expect(
          find.text(
            'Filter tempat berdasarkan kecepatan Wi-Fi, ketersediaan colokan, budget per kunjungan, suasana hening, hingga jarak terdekat.',
          ),
          findsOneWidget,
        );
        expect(find.text('Lanjut'), findsOneWidget);

        // Advance to Page 3
        await tester.tap(find.text('Lanjut'));
        await tester.pumpAndSettle();

        expect(
          find.text('Bingung pilih tempat?\nTanya SpotAI'),
          findsOneWidget,
        );
        expect(find.text('Mulai Sekarang'), findsOneWidget);

        // Verify no RenderFlex errors were thrown on this screen size
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Issue 1: Explore Map Screen Safe Area & Layout Tests', () {
    testWidgets('Explore Map starts below iOS status bar / Dynamic Island', (
      WidgetTester tester,
    ) async {
      // iPhone with Dynamic Island (top safe area padding = 59)
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationScreen(initialIndex: 1), // Jelajah tab
        ),
      );
      await tester.pumpAndSettle();

      // Verify search bar is below status bar (top >= 59)
      final searchBarTopLeft = tester.getTopLeft(
        find.text('Cari spot nugas di peta...'),
      );
      expect(searchBarTopLeft.dy, greaterThanOrEqualTo(59.0));

      // Verify bottom preview card is visible and above bottom nav
      expect(find.text('Lihat Detail'), findsOneWidget);
      expect(find.text('Rute'), findsOneWidget);
      expect(find.text('Kopi Ruang'), findsWidgets);

      final cardBottom = tester.getBottomLeft(find.text('Lihat Detail')).dy;
      final bottomNavTop = tester.getTopLeft(find.text('Jelajah')).dy;
      // Card should be above bottom nav
      expect(cardBottom, lessThan(bottomNavTop));

      // Verify map controls are present
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.layers_rounded), findsOneWidget);

      // Verify user location indicator
      expect(find.text('Kamu di sini'), findsOneWidget);

      // Test map controls tap
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.my_location_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Explore Map works on Android with 32px status bar and 360px screen',
      (WidgetTester tester) async {
        // Android device with 32px status bar and 360px width
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(top: 32, bottom: 0);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);

        await tester.pumpWidget(
          const MaterialApp(home: MainNavigationScreen(initialIndex: 1)),
        );
        await tester.pumpAndSettle();

        // Top search bar starts below 32px
        final searchBarTopLeft = tester.getTopLeft(
          find.text('Cari spot nugas di peta...'),
        );
        expect(searchBarTopLeft.dy, greaterThanOrEqualTo(32.0));

        // Bottom card is rendered cleanly without overflow
        expect(find.text('Lihat Detail'), findsOneWidget);
        expect(find.text('Rute'), findsOneWidget);

        // Toggle to List view
        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();

        expect(find.text('Peta'), findsOneWidget);
        // No RenderFlex overflow
        expect(tester.takeException(), isNull);
      },
    );
  });
}
