import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return Stream.value(null);
  }
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.userProfileStream(user.uid);
});

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(const AsyncValue.data(null));

  Future<UserProfile?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AsyncValue.data(profile);
      return profile;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<UserProfile?> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authRepository.registerWithEmailAndPassword(
        name: name,
        email: email,
        password: password,
      );
      state = AsyncValue.data(profile);
      return profile;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<UserProfile?> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authRepository.signInWithGoogle();
      state = AsyncValue.data(profile);
      return profile;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<UserProfile?> signInAnonymously() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authRepository.signInAnonymously();
      state = AsyncValue.data(profile);
      return profile;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.sendPasswordResetEmail(email);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<UserProfile?> updateProfileName({
    required UserProfile currentProfile,
    required String newName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _authRepository.updateUserProfileName(
        currentProfile: currentProfile,
        newName: newName,
      );
      state = AsyncValue.data(updated);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
      final authRepo = ref.watch(authRepositoryProvider);
      return AuthController(authRepo);
    });
