import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';

class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthRepository {
  final FirebaseAuth? _injectedAuth;
  final FirebaseFirestore? _injectedFirestore;
  final GoogleSignIn? _injectedGoogleSignIn;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _injectedAuth = auth,
       _injectedFirestore = firestore,
       _injectedGoogleSignIn = googleSignIn;

  bool get _isFirebaseReady =>
      _injectedAuth != null || Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth {
    if (_injectedAuth != null) return _injectedAuth;
    if (!_isFirebaseReady) {
      throw const AuthException('Firebase belum diinisialisasi.');
    }
    return FirebaseAuth.instance;
  }

  FirebaseFirestore get _firestore {
    if (_injectedFirestore != null) return _injectedFirestore;
    if (!_isFirebaseReady) {
      throw const AuthException('Firestore belum diinisialisasi.');
    }
    return FirebaseFirestore.instance;
  }

  GoogleSignIn get _googleSignIn =>
      _injectedGoogleSignIn ??
      GoogleSignIn(
        serverClientId:
            '518234485931-4tmgvm905bs3tt3dgj82qqucqg0b8qoc.apps.googleusercontent.com',
      );

  Stream<User?> get authStateChanges {
    if (!_isFirebaseReady) {
      return Stream.value(null);
    }
    return _auth.authStateChanges();
  }

  User? get currentUser {
    if (!_isFirebaseReady) return null;
    return _auth.currentUser;
  }

  Stream<UserProfile?> userProfileStream(String uid) {
    if (!_isFirebaseReady) {
      return Stream.value(null);
    }
    return _firestore.collection('users').doc(uid).snapshots().map((
      docSnapshot,
    ) {
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        return null;
      }
      return UserProfile.fromFirestore(docSnapshot);
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    if (!_isFirebaseReady) return null;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromFirestore(doc);
    } on FirebaseException catch (e) {
      debugPrint('Firestore getUserProfile error: $e');
      throw const AuthException(
        'Gagal mengambil data profil pengguna dari server.',
        code: 'firestore_read_error',
      );
    } catch (e) {
      debugPrint('getUserProfile error: $e');
      throw AuthException('Gagal mengambil data profil: $e');
    }
  }

  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw const AuthException(
        'Email tidak boleh kosong.',
        code: 'invalid-email',
      );
    }
    if (password.isEmpty) {
      throw const AuthException(
        'Kata sandi tidak boleh kosong.',
        code: 'wrong-password',
      );
    }

    if (!_isFirebaseReady) {
      return UserProfile(
        uid: 'test_uid',
        name: cleanEmail.split('@').first,
        email: cleanEmail,
        isGuest: false,
        onboardingCompleted: true,
      );
    }

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw const AuthException('Pengguna tidak ditemukan setelah login.');
      }

      UserProfile? profile = await getUserProfile(user.uid);
      if (profile == null) {
        profile = UserProfile(
          uid: user.uid,
          name: user.displayName ?? cleanEmail.split('@').first,
          email: user.email ?? cleanEmail,
          photoUrl: user.photoURL,
          role: 'user',
          isGuest: false,
          onboardingCompleted: true,
        );
        await _saveUserProfile(profile);
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Gagal masuk: $e');
    }
  }

  Future<UserProfile> registerWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();

    if (cleanName.isEmpty) {
      throw const AuthException(
        'Nama lengkap tidak boleh kosong.',
        code: 'invalid-name',
      );
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const AuthException(
        'Format email tidak valid.',
        code: 'invalid-email',
      );
    }
    if (password.length < 6) {
      throw const AuthException(
        'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.',
        code: 'weak-password',
      );
    }

    if (!_isFirebaseReady) {
      return UserProfile(
        uid: 'test_uid',
        name: cleanName,
        email: cleanEmail,
        isGuest: false,
        onboardingCompleted: true,
      );
    }

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw const AuthException('Pendaftaran akun gagal.');
      }

      try {
        await user.updateDisplayName(cleanName);
      } catch (_) {}

      final newProfile = UserProfile(
        uid: user.uid,
        name: cleanName,
        email: cleanEmail,
        photoUrl: null,
        role: 'user', // strictly enforced
        isGuest: false,
        onboardingCompleted: true,
      );

      await _saveUserProfile(newProfile);
      return newProfile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Gagal mendaftar: $e');
    }
  }

  Future<UserProfile> signInWithGoogle() async {
    if (!_isFirebaseReady) {
      return const UserProfile(
        uid: 'test_google_uid',
        name: 'Pengguna Google Test',
        email: 'test@google.com',
        isGuest: false,
        onboardingCompleted: true,
      );
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException(
          'Masuk dengan Google dibatalkan.',
          code: 'google-sign-in-cancelled',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;
      if (user == null) {
        throw const AuthException('Autentikasi Google gagal.');
      }

      final docRef = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        final newProfile = UserProfile(
          uid: user.uid,
          name:
              user.displayName ??
              googleUser.displayName ??
              'Pengguna SpotNugas',
          email: user.email ?? googleUser.email,
          photoUrl: user.photoURL ?? googleUser.photoUrl,
          role: 'user',
          isGuest: false,
          onboardingCompleted: true,
        );
        await docRef.set(newProfile.toFirestoreCreate());
        return newProfile;
      } else {
        // Do not overwrite existing profile data unnecessarily (e.g. role, createdAt)
        final existingData = docSnapshot.data() ?? {};
        final Map<String, dynamic> updates = {
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (existingData['photoUrl'] == null &&
            (user.photoURL != null || googleUser.photoUrl != null)) {
          updates['photoUrl'] = user.photoURL ?? googleUser.photoUrl;
        }
        await docRef.update(updates);
        return UserProfile.fromFirestore(docSnapshot);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } on AuthException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('GoogleSignIn')) {
        throw const AuthException(
          'Masuk dengan Google dibatalkan.',
          code: 'google-sign-in-cancelled',
        );
      }
      throw AuthException('Gagal masuk dengan Google: $e');
    }
  }

  Future<UserProfile> signInAnonymously() async {
    if (!_isFirebaseReady) {
      return const UserProfile(
        uid: 'test_guest_uid',
        name: 'Tamu SpotNugas',
        isGuest: true,
        onboardingCompleted: true,
      );
    }

    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      if (user == null) {
        throw const AuthException('Gagal masuk sebagai tamu.');
      }

      final guestProfile = UserProfile(
        uid: user.uid,
        name: 'Tamu SpotNugas',
        email: null,
        photoUrl: null,
        role: 'user',
        isGuest: true,
        onboardingCompleted: true,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(guestProfile.toFirestoreCreate(), SetOptions(merge: true));

      return guestProfile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Gagal masuk sebagai tamu: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const AuthException(
        'Format email tidak valid.',
        code: 'invalid-email',
      );
    }

    if (!_isFirebaseReady) return;

    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e), code: e.code);
    } catch (e) {
      throw AuthException('Gagal mengirim email reset kata sandi: $e');
    }
  }

  Future<void> signOut() async {
    if (!_isFirebaseReady) return;
    try {
      await _auth.signOut();
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    } catch (e) {
      throw AuthException('Gagal keluar dari akun: $e');
    }
  }

  Future<UserProfile> updateUserProfileName({
    required UserProfile currentProfile,
    required String newName,
  }) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty || cleanName.length > 100) {
      throw const AuthException(
        'Nama harus diisi (1–100 karakter).',
        code: 'invalid-name',
      );
    }
    if (currentProfile.isGuest) {
      throw const AuthException(
        'Akun tamu tidak dapat mengubah profil. Silakan daftar akun terlebih dahulu.',
        code: 'guest-restricted',
      );
    }

    final updated = currentProfile.copyWith(
      name: cleanName,
      updatedAt: DateTime.now(),
    );

    if (!_isFirebaseReady) {
      return updated;
    }

    try {
      try {
        await _auth.currentUser?.updateDisplayName(cleanName);
      } catch (_) {}

      await _firestore.collection('users').doc(currentProfile.uid).set({
        'uid': currentProfile.uid,
        'name': cleanName,
        'email': currentProfile.email,
        'photoUrl': currentProfile.photoUrl,
        'role': currentProfile.role,
        'isGuest': false,
        'onboardingCompleted': currentProfile.onboardingCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return updated;
    } on FirebaseException catch (e) {
      debugPrint('updateUserProfileName Firestore error: $e');
      throw const AuthException(
        'Gagal memperbarui nama profil di server.',
        code: 'firestore-write-failure',
      );
    } catch (e) {
      throw AuthException('Gagal memperbarui profil: $e');
    }
  }

  Future<void> _saveUserProfile(UserProfile profile) async {
    try {
      await _firestore
          .collection('users')
          .doc(profile.uid)
          .set(profile.toFirestoreCreate(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint('Firestore write error: $e');
      throw const AuthException(
        'Gagal menyimpan profil pengguna ke server.',
        code: 'firestore-write-failure',
      );
    } catch (e) {
      throw AuthException('Gagal menyimpan data profil: $e');
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan. Silakan hubungi dukungan.';
      case 'user-not-found':
        return 'Akun dengan email ini tidak ditemukan.';
      case 'wrong-password':
        return 'Kata sandi yang Anda masukkan salah.';
      case 'invalid-credential':
        return 'Email atau kata sandi tidak cocok. Silakan coba lagi.';
      case 'email-already-in-use':
        return 'Email ini sudah terdaftar. Silakan masuk atau gunakan email lain.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
      case 'operation-not-allowed':
        return 'Metode autentikasi ini belum diaktifkan di server.';
      case 'network-request-failed':
        return 'Gagal terhubung ke server. Periksa koneksi internet Anda.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan masuk yang gagal. Silakan coba lagi nanti.';
      default:
        return e.message ??
            'Terjadi kesalahan saat autentikasi (${e.code}). Silakan coba lagi.';
    }
  }
}
