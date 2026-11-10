import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot_nugas/data/place_mock_data.dart';
import 'package:spot_nugas/models/user_profile.dart';
import 'package:spot_nugas/providers/auth_provider.dart';
import 'package:spot_nugas/providers/review_provider.dart';
import 'package:spot_nugas/repositories/review_repository.dart';
import 'package:spot_nugas/screens/auth/login_screen.dart';
import 'package:spot_nugas/screens/place_detail_screen.dart';

void main() {
  group('GuestReviewBlockedDialog - Responsive Layout Tests', () {
    Widget buildTestHarness({
      required double width,
      required double height,
      TextScaler textScaler = TextScaler.noScaling,
      Widget? child,
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: textScaler,
          ),
          child: Scaffold(
            body: Center(child: child ?? const GuestReviewBlockedDialog()),
          ),
        ),
      );
    }

    testWidgets(
      'Renders with 0 overflow on 320dp width (Very Small / Compact)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestHarness(width: 320, height: 640));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Akses Terbatas Tamu'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
        expect(find.text('Nanti Saja'), findsOneWidget);
        expect(find.text('Daftar / Masuk'), findsOneWidget);
      },
    );

    testWidgets('Renders with 0 overflow on 360dp width (Standard Android)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestHarness(width: 360, height: 800));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Akses Terbatas Tamu'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('Renders with 0 overflow on 393dp width (Standard iPhone)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestHarness(width: 393, height: 852));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Akses Terbatas Tamu'), findsOneWidget);
    });

    testWidgets('Renders with 0 overflow on 600dp width (Tablet / Foldable)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestHarness(width: 600, height: 960));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Akses Terbatas Tamu'), findsOneWidget);
    });

    testWidgets('Renders with 0 overflow under 1.5x Large Text Scaling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestHarness(
          width: 360,
          height: 800,
          textScaler: const TextScaler.linear(1.5),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Akses Terbatas Tamu'), findsOneWidget);
      expect(find.text('Nanti Saja'), findsOneWidget);
      expect(find.text('Daftar / Masuk'), findsOneWidget);
    });

    testWidgets(
      'Renders with 0 overflow under 2.0x Extra Large Text Scaling on 320dp',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildTestHarness(
            width: 320,
            height: 640,
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Akses Terbatas Tamu'), findsOneWidget);
      },
    );

    testWidgets('Dialog action "Nanti Saja" pops the dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => const GuestReviewBlockedDialog(),
                ),
                child: const Text('Buka Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(GuestReviewBlockedDialog), findsOneWidget);

      // Tap Nanti Saja
      await tester.tap(find.text('Nanti Saja'));
      await tester.pumpAndSettle();

      expect(find.byType(GuestReviewBlockedDialog), findsNothing);
    });

    testWidgets('Dialog action "Daftar / Masuk" navigates to LoginScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => const GuestReviewBlockedDialog(),
                ),
                child: const Text('Buka Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(GuestReviewBlockedDialog), findsOneWidget);

      // Tap Daftar / Masuk
      await tester.tap(find.text('Daftar / Masuk'));
      await tester.pumpAndSettle();

      expect(find.byType(GuestReviewBlockedDialog), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('PlaceDetailScreen - Guest Review Restriction Flow', () {
    testWidgets(
      'Tapping Tulis Review as anonymous guest triggers dialog with 0 overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final guestUser = const UserProfile(
          uid: 'guest_user_test',
          name: 'Tamu SpotNugas',
          isGuest: true,
        );

        final place = PlaceMockData.places.first;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProfileProvider.overrideWith(
                (ref) => Stream.value(guestUser),
              ),
            ],
            child: MaterialApp(home: PlaceDetailScreen(place: place)),
          ),
        );
        await tester.pumpAndSettle();

        // Find review button or scroll down to reviews section
        final writeReviewBtn = find.text('Tulis Review');
        if (writeReviewBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(writeReviewBtn);
          await tester.pumpAndSettle();
          await tester.tap(writeReviewBtn);
          await tester.pumpAndSettle();

          // Guest restriction dialog must appear
          expect(find.byType(GuestReviewBlockedDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'PlaceDetailScreen renders with 0 overflow on 320dp width (including bottom actions)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final place = PlaceMockData.places.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: PlaceDetailScreen(place: place)),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Petunjuk Arah'), findsOneWidget);
        expect(find.text('Tanya SpotAI'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping Tulis Review as guest on 320dp width triggers dialog with 0 overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final guestUser = const UserProfile(
          uid: 'guest_user_test',
          name: 'Tamu SpotNugas',
          isGuest: true,
        );

        final place = PlaceMockData.places.first;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProfileProvider.overrideWith(
                (ref) => Stream.value(guestUser),
              ),
            ],
            child: MaterialApp(home: PlaceDetailScreen(place: place)),
          ),
        );
        await tester.pumpAndSettle();

        final writeReviewBtn = find.text('Tulis Review');
        expect(writeReviewBtn, findsOneWidget);
        await tester.ensureVisible(writeReviewBtn);
        await tester.pumpAndSettle();
        await tester.tap(writeReviewBtn);
        await tester.pumpAndSettle();

        expect(find.byType(GuestReviewBlockedDialog), findsOneWidget);
        expect(find.text('Akses Terbatas Tamu'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Registered user submits text-only review (rating + text, no photo picker)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final registeredUser = const UserProfile(
          uid: 'reg_user_review_test',
          name: 'Budi Santoso',
          email: 'budi@example.com',
          isGuest: false,
        );

        final place = PlaceMockData.places.first;
        final reviewRepo = ReviewRepository();
        addTearDown(reviewRepo.clearAll);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProfileProvider.overrideWith(
                (ref) => Stream.value(registeredUser),
              ),
              reviewRepositoryProvider.overrideWithValue(reviewRepo),
            ],
            child: MaterialApp(home: PlaceDetailScreen(place: place)),
          ),
        );
        await tester.pumpAndSettle();

        final writeReviewBtn = find.widgetWithText(
          ElevatedButton,
          'Tulis Review',
        );
        expect(writeReviewBtn, findsOneWidget);
        await tester.ensureVisible(writeReviewBtn);
        await tester.pumpAndSettle();
        await tester.tap(writeReviewBtn);
        await tester.pumpAndSettle();

        // Review modal opens with rating + text fields and NO photo picker UI
        expect(find.text('Tulis Review Tempat'), findsOneWidget);
        expect(find.text('Rating Keseluruhan:'), findsOneWidget);
        expect(find.text('Komentar Pengalaman Nugas:'), findsOneWidget);
        expect(find.text('Foto Tempat (Opsional):'), findsNothing);
        expect(find.byKey(const Key('add_review_photo_button')), findsNothing);

        // Enter review text and submit
        await tester.enterText(
          find.byType(TextField),
          'Tempat nugas nyaman, wifi cepat dan colokan banyak.',
        );
        await tester.pumpAndSettle();

        final submitBtn = find.text('Kirim Review');
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(find.text('Review berhasil dipublikasikan!'), findsOneWidget);
        final saved = await reviewRepo.getUserReview(
          place.id,
          registeredUser.uid,
        );
        expect(saved, isNotNull);
        expect(saved!.rating, equals(5.0));
        expect(
          saved.comment,
          equals('Tempat nugas nyaman, wifi cepat dan colokan banyak.'),
        );
      },
    );
  });
}
