import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/place.dart';
import '../models/place_review_model.dart';
import '../models/user_profile.dart';
import '../utils/study_score_calculator.dart';

class ReviewException implements Exception {
  final String message;
  final String? code;

  const ReviewException(this.message, {this.code});

  @override
  String toString() => message;
}

class ReviewRepository {
  final FirebaseFirestore? _injectedFirestore;

  /// In-memory cache for places reviews: placeId -> map of (reviewId -> PlaceReviewModel)
  final Map<String, Map<String, PlaceReviewModel>> _reviewCache = {};
  final Map<String, StreamController<List<PlaceReviewModel>>> _controllers = {};

  ReviewRepository({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  bool get _isFirebaseReady =>
      _injectedFirestore != null || Firebase.apps.isNotEmpty;

  FirebaseFirestore get _firestore {
    if (_injectedFirestore != null) return _injectedFirestore;
    if (!_isFirebaseReady) {
      throw const ReviewException('Firestore belum diinisialisasi.');
    }
    return FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> _reviewsCol(String placeId) {
    return _firestore.collection('places').doc(placeId).collection('reviews');
  }

  /// Streams reviews for a place.
  ///
  /// Paginates using [limit] (default 20) to prevent unbounded document reads.
  /// If Firestore has no reviews for this place and [mockFallback] is provided,
  /// yields the mock reviews with [isMockDemonstration = true] for demo display,
  /// clearly distinguishing them from real verified community reviews.
  Stream<List<PlaceReviewModel>> streamReviews(
    String placeId, {
    int limit = 20,
    List<PlaceReview>? mockFallback,
  }) {
    if (placeId.isEmpty) {
      return Stream.value(const []);
    }

    if (!_isFirebaseReady) {
      _ensureController(placeId, mockFallback: mockFallback);
      return _controllers[placeId]!.stream;
    }

    return _reviewsCol(placeId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final realReviews = snapshot.docs
              .map((doc) => PlaceReviewModel.fromFirestore(doc))
              .toList();

          final placeMap = _reviewCache.putIfAbsent(placeId, () => {});
          placeMap.clear();
          for (final r in realReviews) {
            placeMap[r.id] = r;
          }

          if (realReviews.isNotEmpty) {
            return realReviews;
          }

          // Fallback to mock demonstration reviews if no real reviews exist yet
          if (mockFallback != null && mockFallback.isNotEmpty) {
            return mockFallback
                .map((m) => PlaceReviewModel.fromLegacyReview(m, placeId))
                .toList();
          }

          return <PlaceReviewModel>[];
        })
        .handleError((error) {
          debugPrint('Firestore streamReviews error: $error');
          final cached = _reviewCache[placeId]?.values.toList() ?? [];
          if (cached.isNotEmpty) return cached;

          if (mockFallback != null && mockFallback.isNotEmpty) {
            return mockFallback
                .map((m) => PlaceReviewModel.fromLegacyReview(m, placeId))
                .toList();
          }
          return <PlaceReviewModel>[];
        });
  }

  /// Fetches current user's review for a place, if it exists.
  Future<PlaceReviewModel?> getUserReview(String placeId, String userId) async {
    if (placeId.isEmpty || userId.isEmpty) return null;

    if (_reviewCache[placeId]?.containsKey(userId) == true) {
      return _reviewCache[placeId]![userId];
    }

    if (!_isFirebaseReady) {
      return _reviewCache[placeId]?[userId];
    }

    try {
      final doc = await _reviewsCol(placeId).doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      final review = PlaceReviewModel.fromFirestore(doc);
      _reviewCache.putIfAbsent(placeId, () => {})[userId] = review;
      return review;
    } catch (e) {
      debugPrint('getUserReview error: $e');
      return _reviewCache[placeId]?[userId];
    }
  }

  /// Publishes a new review for a place.
  ///
  /// Enforces:
  /// 1. Anonymous guests CANNOT publish reviews (throws [ReviewException]).
  /// 2. Rating must be between 1.0 and 5.0.
  /// 3. One review per user per place (document ID = user.uid).
  /// 4. Sensitive PII (email, phone) is NEVER included.
  Future<PlaceReviewModel> publishReview({
    required String placeId,
    required UserProfile user,
    required double rating,
    required String comment,
    String? visitPurpose,
    double? wifiRating,
    double? outletRating,
    double? comfortRating,
    double? noiseRating,
    double? priceValueRating,
  }) async {
    // 1. Block anonymous guests
    if (user.isGuest) {
      throw const ReviewException(
        'Tamu tidak dapat mempublikasikan review. Silakan daftar atau masuk dengan akun terdaftar.',
        code: 'guest-review-forbidden',
      );
    }

    // 2. Validate ratings and comments
    try {
      PlaceReviewModel.validate(
        rating: rating,
        comment: comment,
        wifiRating: wifiRating,
        outletRating: outletRating,
        comfortRating: comfortRating,
        noiseRating: noiseRating,
        priceValueRating: priceValueRating,
      );
    } on ArgumentError catch (e) {
      throw ReviewException(e.message, code: 'invalid-input');
    }

    final now = DateTime.now();
    final review = PlaceReviewModel(
      id: user.uid, // reviewId == request.auth.uid (enforces single review)
      placeId: placeId,
      userId: user.uid,
      userName: user.name,
      userAvatar: user.photoUrl,
      rating: rating,
      comment: comment.trim(),
      visitPurpose: visitPurpose,
      wifiRating: wifiRating,
      outletRating: outletRating,
      comfortRating: comfortRating,
      noiseRating: noiseRating,
      priceValueRating: priceValueRating,
      createdAt: now,
      isMockDemonstration: false,
    );

    // Update local cache & notify
    final placeMap = _reviewCache.putIfAbsent(placeId, () => {});
    placeMap[user.uid] = review;
    _notifyController(placeId);

    if (_isFirebaseReady) {
      try {
        await _reviewsCol(placeId).doc(user.uid).set(review.toMap());
      } on FirebaseException catch (e) {
        debugPrint('Firestore publishReview error: $e');
        if (e.code == 'permission-denied') {
          throw const ReviewException(
            'Akses ditolak: Operasi penulisan review tidak diizinkan oleh aturan keamanan.',
            code: 'permission-denied',
          );
        }
        throw ReviewException(
          'Gagal mengirim review: ${e.message}',
          code: e.code,
        );
      } catch (e) {
        throw ReviewException('Gagal mengirim review: $e');
      }
    }

    return review;
  }

  /// Updates an existing review.
  ///
  /// Enforces:
  /// 1. Anonymous guests CANNOT edit reviews.
  /// 2. User cannot edit another user's review.
  /// 3. Identity fields (userId, placeId, createdAt) remain immutable.
  Future<PlaceReviewModel> updateReview({
    required String placeId,
    required UserProfile user,
    required PlaceReviewModel existingReview,
    required double rating,
    required String comment,
    String? visitPurpose,
    double? wifiRating,
    double? outletRating,
    double? comfortRating,
    double? noiseRating,
    double? priceValueRating,
  }) async {
    if (user.isGuest) {
      throw const ReviewException(
        'Tamu tidak memiliki izin untuk mengedit review.',
        code: 'guest-forbidden',
      );
    }
    if (existingReview.userId != user.uid) {
      throw const ReviewException(
        'Anda tidak memiliki izin untuk mengedit review milik pengguna lain.',
        code: 'permission-denied',
      );
    }

    try {
      PlaceReviewModel.validate(
        rating: rating,
        comment: comment,
        wifiRating: wifiRating,
        outletRating: outletRating,
        comfortRating: comfortRating,
        noiseRating: noiseRating,
        priceValueRating: priceValueRating,
      );
    } on ArgumentError catch (e) {
      throw ReviewException(e.message, code: 'invalid-input');
    }

    final updated = existingReview.copyWith(
      rating: rating,
      comment: comment.trim(),
      visitPurpose: visitPurpose ?? existingReview.visitPurpose,
      wifiRating: wifiRating ?? existingReview.wifiRating,
      outletRating: outletRating ?? existingReview.outletRating,
      comfortRating: comfortRating ?? existingReview.comfortRating,
      noiseRating: noiseRating ?? existingReview.noiseRating,
      priceValueRating: priceValueRating ?? existingReview.priceValueRating,
      updatedAt: DateTime.now(),
      isMockDemonstration: false,
    );

    final placeMap = _reviewCache.putIfAbsent(placeId, () => {});
    placeMap[user.uid] = updated;
    _notifyController(placeId);

    if (_isFirebaseReady) {
      try {
        await _reviewsCol(placeId).doc(user.uid).update({
          'rating': updated.rating,
          'comment': updated.comment,
          if (updated.visitPurpose != null)
            'visitPurpose': updated.visitPurpose,
          if (updated.wifiRating != null) 'wifiRating': updated.wifiRating,
          if (updated.outletRating != null)
            'outletRating': updated.outletRating,
          if (updated.comfortRating != null)
            'comfortRating': updated.comfortRating,
          if (updated.noiseRating != null) 'noiseRating': updated.noiseRating,
          if (updated.priceValueRating != null)
            'priceValueRating': updated.priceValueRating,
          'updatedAt': Timestamp.fromDate(updated.updatedAt!),
        });
      } on FirebaseException catch (e) {
        debugPrint('Firestore updateReview error: $e');
        throw ReviewException(
          'Gagal memperbarui review: ${e.message}',
          code: e.code,
        );
      } catch (e) {
        throw ReviewException('Gagal memperbarui review: $e');
      }
    }

    return updated;
  }

  /// Deletes a review for [placeId] written by [userId].
  Future<void> deleteReview({
    required String placeId,
    required String userId,
  }) async {
    final placeMap = _reviewCache[placeId];
    placeMap?.remove(userId);
    _notifyController(placeId);

    if (_isFirebaseReady) {
      try {
        await _reviewsCol(placeId).doc(userId).delete();
      } on FirebaseException catch (e) {
        debugPrint('Firestore deleteReview error: $e');
        throw ReviewException(
          'Gagal menghapus review: ${e.message}',
          code: e.code,
        );
      } catch (e) {
        throw ReviewException('Gagal menghapus review: $e');
      }
    }
  }

  /// Computes updated Skor Nugas taking into account newly published or updated reviews.
  ///
  /// Demonstrates responsive Skor Nugas updating dynamically when community
  /// feedback is submitted.
  double computeDynamicSkorNugas({
    required Place place,
    required List<PlaceReviewModel> reviews,
  }) {
    if (reviews.isEmpty) {
      return place.skorNugas;
    }

    // Filter to real community reviews if any, otherwise all reviews
    final realReviews = reviews.where((r) => !r.isMockDemonstration).toList();
    final activeReviews = realReviews.isNotEmpty ? realReviews : reviews;

    // Calculate community rating average
    final double avgRating =
        activeReviews.map((r) => r.rating).reduce((a, b) => a + b) /
        activeReviews.length;

    // Calculate sub-scores from reviews if available
    double? avgWifi;
    final wifiRatings = activeReviews
        .where((r) => r.wifiRating != null)
        .map((r) => r.wifiRating!)
        .toList();
    if (wifiRatings.isNotEmpty) {
      avgWifi = wifiRatings.reduce((a, b) => a + b) / wifiRatings.length;
    }

    double? avgOutlet;
    final outletRatings = activeReviews
        .where((r) => r.outletRating != null)
        .map((r) => r.outletRating!)
        .toList();
    if (outletRatings.isNotEmpty) {
      avgOutlet = outletRatings.reduce((a, b) => a + b) / outletRatings.length;
    }

    double? avgComfort;
    final comfortRatings = activeReviews
        .where((r) => r.comfortRating != null)
        .map((r) => r.comfortRating!)
        .toList();
    if (comfortRatings.isNotEmpty) {
      avgComfort =
          comfortRatings.reduce((a, b) => a + b) / comfortRatings.length;
    }

    double? avgNoise;
    final noiseRatings = activeReviews
        .where((r) => r.noiseRating != null)
        .map((r) => r.noiseRating!)
        .toList();
    if (noiseRatings.isNotEmpty) {
      avgNoise = noiseRatings.reduce((a, b) => a + b) / noiseRatings.length;
    }

    const calc = StudyScoreCalculator();
    final score = calc.compute(
      wifiScore: avgWifi ?? place.wifiScore,
      outletScore: avgOutlet ?? place.outletScore,
      comfortScore: avgComfort ?? place.comfortScore,
      noiseScore: avgNoise ?? place.noiseScore,
      priceValueScore: place.priceValueScore,
      rating: avgRating,
    );

    return score ?? place.skorNugas;
  }

  void _ensureController(String placeId, {List<PlaceReview>? mockFallback}) {
    if (!_controllers.containsKey(placeId) || _controllers[placeId]!.isClosed) {
      _controllers[placeId] =
          StreamController<List<PlaceReviewModel>>.broadcast(
            onListen: () {
              final cached = _reviewCache[placeId]?.values.toList() ?? [];
              if (cached.isNotEmpty) {
                _controllers[placeId]?.add(cached);
              } else if (mockFallback != null && mockFallback.isNotEmpty) {
                _controllers[placeId]?.add(
                  mockFallback
                      .map((m) => PlaceReviewModel.fromLegacyReview(m, placeId))
                      .toList(),
                );
              } else {
                _controllers[placeId]?.add(const []);
              }
            },
          );
    }
  }

  void _notifyController(String placeId) {
    if (_controllers.containsKey(placeId) && !_controllers[placeId]!.isClosed) {
      final cached = _reviewCache[placeId]?.values.toList() ?? [];
      _controllers[placeId]?.add(cached);
    }
  }

  void clearAll() {
    _reviewCache.clear();
    for (final ctrl in _controllers.values) {
      ctrl.close();
    }
    _controllers.clear();
  }
}
