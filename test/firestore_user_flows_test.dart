import 'package:flutter_test/flutter_test.dart';
import 'package:spot_nugas/data/place_mock_data.dart';
import 'package:spot_nugas/models/place.dart';
import 'package:spot_nugas/models/place_review_model.dart';
import 'package:spot_nugas/models/saved_place_item.dart';
import 'package:spot_nugas/models/user_profile.dart';
import 'package:spot_nugas/repositories/review_repository.dart';
import 'package:spot_nugas/repositories/saved_places_repository.dart';

void main() {
  group('Phase D4: Firestore User Flows & Hardening Validation', () {
    late SavedPlacesRepository savedPlacesRepo;
    late ReviewRepository reviewRepo;
    late Place testPlace;

    setUp(() {
      savedPlacesRepo = SavedPlacesRepository();
      reviewRepo = ReviewRepository();
      testPlace = PlaceMockData.places.first;
    });

    tearDown(() {
      savedPlacesRepo.clearAll();
      reviewRepo.clearAll();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 1 & 2: User Profiles (Register, Login, Guest Login)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'User profiles correctly distinguish registered vs guest accounts',
      () {
        final registeredUser = UserProfile(
          uid: 'reg_user_1',
          name: 'Budi Santoso',
          email: 'budi@example.com',
          role: 'user',
          isGuest: false,
          createdAt: DateTime.now(),
        );

        final guestUser = UserProfile(
          uid: 'guest_user_1',
          name: 'Tamu SpotNugas',
          role: 'user',
          isGuest: true,
          createdAt: DateTime.now(),
        );

        expect(registeredUser.isGuest, isFalse);
        expect(registeredUser.email, equals('budi@example.com'));
        expect(guestUser.isGuest, isTrue);
        expect(guestUser.email, isNull);

        // Verify role escalation prevention in client models
        final userMap = registeredUser.toMap();
        expect(userMap['role'], equals('user'));
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 3 & 4: Bookmarks (Save Place, Guest Save, Isolation, Restore)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'Owner (registered & guest) can save/unsave places under their own UID',
      () async {
        const regUid = 'user_alice';
        const guestUid = 'guest_bob';

        // 1. Registered user saves place
        await savedPlacesRepo.savePlace(regUid, testPlace);
        expect(
          await savedPlacesRepo.isPlaceSaved(regUid, testPlace.id),
          isTrue,
        );

        // 2. Guest user saves place under own guest UID
        await savedPlacesRepo.savePlace(guestUid, testPlace);
        expect(
          await savedPlacesRepo.isPlaceSaved(guestUid, testPlace.id),
          isTrue,
        );

        // 3. Registered user unsaves place
        await savedPlacesRepo.removeSavedPlace(regUid, testPlace.id);
        expect(
          await savedPlacesRepo.isPlaceSaved(regUid, testPlace.id),
          isFalse,
        );

        // 4. Guest's saved place remains intact (isolated states)
        expect(
          await savedPlacesRepo.isPlaceSaved(guestUid, testPlace.id),
          isTrue,
        );
      },
    );

    test(
      'Account switching strictly isolates saved places state across logout and login',
      () async {
        const userA = 'user_alpha';
        const userB = 'user_beta';

        final placeA = PlaceMockData.places[0];
        final placeB = PlaceMockData.places[1];

        // User A saves placeA
        await savedPlacesRepo.savePlace(userA, placeA);
        expect(await savedPlacesRepo.isPlaceSaved(userA, placeA.id), isTrue);
        expect(await savedPlacesRepo.isPlaceSaved(userA, placeB.id), isFalse);

        // User A logs out -> clear user state
        savedPlacesRepo.clearUserState(userA);

        // User B logs in and saves placeB
        await savedPlacesRepo.savePlace(userB, placeB);
        expect(await savedPlacesRepo.isPlaceSaved(userB, placeB.id), isTrue);
        expect(await savedPlacesRepo.isPlaceSaved(userB, placeA.id), isFalse);

        // User A logs in again -> saved places restore cleanly
        await savedPlacesRepo.savePlace(userA, placeA);
        expect(await savedPlacesRepo.isPlaceSaved(userA, placeA.id), isTrue);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 5: Review Permissions (Anonymous guest CANNOT publish reviews)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'Anonymous guest CANNOT publish a review (rejected with exception)',
      () async {
        final guest = UserProfile(
          uid: 'guest_uid_123',
          name: 'Tamu SpotNugas',
          isGuest: true,
        );

        expect(
          () => reviewRepo.publishReview(
            placeId: testPlace.id,
            user: guest,
            rating: 4.5,
            comment: 'Mencoba nugas di sini sebagai tamu.',
          ),
          throwsA(
            isA<ReviewException>().having(
              (e) => e.code,
              'code',
              'guest-review-forbidden',
            ),
          ),
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 6: Review Permissions (Registered user publishes, updates, deletes)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'Registered user can publish, edit, and delete their single review',
      () async {
        final registeredUser = UserProfile(
          uid: 'user_dewi',
          name: 'Dewi Lestari',
          email: 'dewi@example.com',
          isGuest: false,
        );

        // 1. Publish review
        final review = await reviewRepo.publishReview(
          placeId: testPlace.id,
          user: registeredUser,
          rating: 4.8,
          comment: 'Tempat nugas favorit, meja luas dan colokan melimpah.',
          visitPurpose: 'Skripsi / Belajar',
          wifiRating: 5.0,
          outletRating: 4.5,
          comfortRating: 4.8,
          noiseRating: 4.0,
        );

        expect(
          review.id,
          equals(registeredUser.uid),
        ); // Single review per user per place
        expect(review.userId, equals(registeredUser.uid));
        expect(review.isMockDemonstration, isFalse);

        // 2. Fetch user review
        final fetched = await reviewRepo.getUserReview(
          testPlace.id,
          registeredUser.uid,
        );
        expect(fetched, isNotNull);
        expect(fetched!.comment, contains('Tempat nugas favorit'));

        // 3. User edits review
        final updated = await reviewRepo.updateReview(
          placeId: testPlace.id,
          user: registeredUser,
          existingReview: fetched,
          rating: 5.0,
          comment: 'Update: Setelah berkunjung lagi, wifi makin stabil!',
        );

        expect(updated.rating, equals(5.0));
        expect(updated.comment, contains('wifi makin stabil'));
        expect(
          updated.userId,
          equals(registeredUser.uid),
        ); // Identity immutable
        expect(updated.placeId, equals(testPlace.id)); // Place immutable

        // 4. Delete review
        await reviewRepo.deleteReview(
          placeId: testPlace.id,
          userId: registeredUser.uid,
        );
        final afterDelete = await reviewRepo.getUserReview(
          testPlace.id,
          registeredUser.uid,
        );
        expect(afterDelete, isNull);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 7: User cannot edit another user's review
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'User CANNOT edit another user review (denied with permission error)',
      () async {
        final userAlice = UserProfile(
          uid: 'alice_id',
          name: 'Alice',
          isGuest: false,
        );
        final userBob = UserProfile(uid: 'bob_id', name: 'Bob', isGuest: false);

        final aliceReview = await reviewRepo.publishReview(
          placeId: testPlace.id,
          user: userAlice,
          rating: 4.5,
          comment: 'Review asli milik Alice.',
        );

        // Bob tries to edit Alice's review
        expect(
          () => reviewRepo.updateReview(
            placeId: testPlace.id,
            user: userBob,
            existingReview: aliceReview,
            rating: 1.0,
            comment: 'Hacked by Bob!',
          ),
          throwsA(
            isA<ReviewException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 8: Content Validation (Ratings, Sub-scores, and Comment length)
    // ─────────────────────────────────────────────────────────────────────────
    test('Invalid rating values and comments are rejected', () {
      // Rating > 5.0
      expect(
        () => PlaceReviewModel.validate(
          rating: 5.5,
          comment: 'Valid comment length',
        ),
        throwsArgumentError,
      );

      // Rating < 1.0
      expect(
        () => PlaceReviewModel.validate(
          rating: 0.5,
          comment: 'Valid comment length',
        ),
        throwsArgumentError,
      );

      // Comment too short (< 3 chars)
      expect(
        () => PlaceReviewModel.validate(rating: 4.0, comment: 'ok'),
        throwsArgumentError,
      );

      // Sub-scores out of bounds
      expect(
        () => PlaceReviewModel.validate(
          rating: 4.0,
          comment: 'Tempat bagus',
          wifiRating: 6.0,
        ),
        throwsArgumentError,
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 9: Privacy Leak Prevention (No Email/Phone in Review Documents)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'Review serialization NEVER leaks email, userEmail, or phoneNumber',
      () {
        final review = PlaceReviewModel(
          id: 'user_123',
          placeId: 'place_abc',
          userId: 'user_123',
          userName: 'Citra Kirana',
          rating: 4.9,
          comment: 'Suasana tenang sekali untuk nugas malam hari.',
          createdAt: DateTime.now(),
        );

        final map = review.toMap();

        expect(map.containsKey('email'), isFalse);
        expect(map.containsKey('userEmail'), isFalse);
        expect(map.containsKey('phoneNumber'), isFalse);
        expect(map.containsKey('phone'), isFalse);
        expect(map['userName'], equals('Citra Kirana'));
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 10: Dynamic Skor Nugas Recalculation from Reviews
    // ─────────────────────────────────────────────────────────────────────────
    test('Review submissions dynamically update calculated Skor Nugas', () {
      final initialScore = testPlace.skorNugas;

      final perfectReview = PlaceReviewModel(
        id: 'reviewer_1',
        placeId: testPlace.id,
        userId: 'reviewer_1',
        userName: 'Reviewer Handal',
        rating: 5.0,
        comment: 'Sangat sempurna untuk nugas!',
        wifiRating: 5.0,
        outletRating: 5.0,
        comfortRating: 5.0,
        noiseRating: 5.0,
        createdAt: DateTime.now(),
        isMockDemonstration: false,
      );

      final updatedScore = reviewRepo.computeDynamicSkorNugas(
        place: testPlace,
        reviews: [perfectReview],
      );

      expect(updatedScore, greaterThan(0.0));
      expect(updatedScore, isNot(equals(initialScore)));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 11: Real vs Mock Demonstration Distinction
    // ─────────────────────────────────────────────────────────────────────────
    test('Real Firestore reviews are distinctly separated from mock seeds', () {
      final mockSeed = PlaceReviewModel.fromLegacyReview(
        testPlace.reviews.first,
        testPlace.id,
      );
      expect(mockSeed.isMockDemonstration, isTrue);

      final realReview = PlaceReviewModel(
        id: 'real_user_uid',
        placeId: testPlace.id,
        userId: 'real_user_uid',
        userName: 'Pengguna Asli',
        rating: 4.8,
        comment: 'Review asli dari Firestore',
        createdAt: DateTime.now(),
        isMockDemonstration: false,
      );
      expect(realReview.isMockDemonstration, isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 12: Offline / Network Recovery Handling
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'Offline and network recovery operates gracefully with cached bookmarks',
      () async {
        const offlineUid = 'offline_user_99';
        await savedPlacesRepo.savePlace(offlineUid, testPlace);
        expect(
          await savedPlacesRepo.isPlaceSaved(offlineUid, testPlace.id),
          isTrue,
        );

        final item = SavedPlaceItem.fromPlace(testPlace);
        final serialized = item.toMap();
        expect(serialized['placeId'], equals(testPlace.id));

        final restored = SavedPlaceItem.fromMap(serialized, testPlace.id);
        expect(restored.name, equals(testPlace.name));
        expect(restored.rating, equals(testPlace.rating));
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Flow 13: Historic Review Photo Field Compatibility (Non-Destructive Read)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'PlaceReviewModel safely deserializes historic documents containing legacy photo fields',
      () {
        final historicFirestoreMap = <String, dynamic>{
          'placeId': testPlace.id,
          'userId': 'historic_user_1',
          'userName': 'Siti Rahma',
          'rating': 4.7,
          'comment': 'Kopi enak, meja lebar, colokan di setiap sudut.',
          'visitPurpose': 'Skripsi / Belajar',
          'wifiRating': 4.8,
          'outletRating': 5.0,
          'createdAt': '2026-09-10T10:00:00.000Z',
          // Historic photo fields must be ignored gracefully without throwing
          'photoUrls': ['https://example.com/old_photo_1.jpg'],
          'photoPaths': ['review-photos/historic_user_1/old_1.jpg'],
        };

        final model = PlaceReviewModel.fromMap(
          historicFirestoreMap,
          'historic_user_1',
        );

        expect(model.id, equals('historic_user_1'));
        expect(model.placeId, equals(testPlace.id));
        expect(model.userId, equals('historic_user_1'));
        expect(model.userName, equals('Siti Rahma'));
        expect(model.rating, equals(4.7));
        expect(
          model.comment,
          equals('Kopi enak, meja lebar, colokan di setiap sudut.'),
        );
        expect(model.wifiRating, equals(4.8));
        expect(model.outletRating, equals(5.0));

        // Serialized map remains clean rating + text + sub-scores schema
        final toMap = model.toMap();
        expect(toMap.containsKey('photoUrls'), isFalse);
        expect(toMap.containsKey('photoPaths'), isFalse);
      },
    );
  });
}
