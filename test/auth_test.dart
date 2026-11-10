import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot_nugas/models/user_profile.dart';
import 'package:spot_nugas/repositories/auth_repository.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('Default values and role protection', () {
      const profile = UserProfile(
        uid: 'user_123',
        name: 'Budi Santoso',
        email: 'budi@example.com',
      );

      expect(profile.uid, 'user_123');
      expect(profile.name, 'Budi Santoso');
      expect(profile.role, 'user');
      expect(profile.isGuest, false);
      expect(profile.onboardingCompleted, true);

      final firestoreMap = profile.toFirestoreCreate();
      // Role must strictly be 'user', client cannot set admin or partner
      expect(firestoreMap['role'], 'user');
      expect(firestoreMap['isGuest'], false);
      expect(firestoreMap['uid'], 'user_123');
    });

    test('Anonymous guest user profile', () {
      const guest = UserProfile(
        uid: 'guest_456',
        name: 'Tamu SpotNugas',
        isGuest: true,
      );

      expect(guest.isGuest, true);
      expect(guest.email, isNull);
      expect(guest.role, 'user');

      final map = guest.toFirestoreCreate();
      expect(map['isGuest'], true);
      expect(map['role'], 'user');
    });

    test('fromMap parses DateTime from Timestamp and millisecond ints', () {
      final now = DateTime(2026, 10, 14, 12, 0);
      final timestamp = Timestamp.fromDate(now);

      final profileFromTimestamp = UserProfile.fromMap({
        'name': 'Siti Rahma',
        'email': 'siti@example.com',
        'role': 'user',
        'isGuest': false,
        'createdAt': timestamp,
      }, 'uid_siti');

      expect(profileFromTimestamp.createdAt, now);
      expect(profileFromTimestamp.name, 'Siti Rahma');
    });

    test('copyWith updates fields while preserving unedited values', () {
      const profile = UserProfile(
        uid: 'user_1',
        name: 'Initial Name',
        email: 'initial@email.com',
      );

      final updated = profile.copyWith(name: 'Updated Name');
      expect(updated.name, 'Updated Name');
      expect(updated.email, 'initial@email.com');
      expect(updated.uid, 'user_1');
    });
  });

  group('AuthRepository Fallback & Validation Tests', () {
    test('Validation rejects empty email or short password', () async {
      final repo = AuthRepository();

      expect(
        () => repo.signInWithEmailAndPassword(email: '', password: 'secret'),
        throwsA(isA<AuthException>()),
      );

      expect(
        () => repo.registerWithEmailAndPassword(
          name: '',
          email: 'valid@email.com',
          password: 'secret',
        ),
        throwsA(isA<AuthException>()),
      );

      expect(
        () => repo.registerWithEmailAndPassword(
          name: 'Valid Name',
          email: 'invalid-email',
          password: '123',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
