import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/place.dart';
import '../models/place_review_model.dart';
import '../repositories/review_repository.dart';
import 'auth_provider.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final repo = ReviewRepository();
  ref.onDispose(() {
    repo.clearAll();
  });
  return repo;
});

/// Streams reviews for a place, with Firestore listener auto-disposal when the
/// user leaves the screen.
final placeReviewsStreamProvider = StreamProvider.autoDispose
    .family<
      List<PlaceReviewModel>,
      ({String placeId, List<PlaceReview>? mockFallback})
    >((ref, args) {
      final repo = ref.watch(reviewRepositoryProvider);
      return repo.streamReviews(
        args.placeId,
        limit: 20,
        mockFallback: args.mockFallback,
      );
    });

/// Gets current user's review for a given place if it exists.
final currentUserReviewProvider = FutureProvider.autoDispose
    .family<PlaceReviewModel?, String>((ref, placeId) async {
      final user = ref.watch(currentUserProfileProvider).valueOrNull;
      if (user == null) return null;
      final repo = ref.watch(reviewRepositoryProvider);
      return repo.getUserReview(placeId, user.uid);
    });

class ReviewActionState {
  final bool isLoading;
  final String? errorMessage;
  final PlaceReviewModel? lastPublishedReview;

  const ReviewActionState({
    this.isLoading = false,
    this.errorMessage,
    this.lastPublishedReview,
  });
}

class ReviewController extends StateNotifier<ReviewActionState> {
  final ReviewRepository _repository;
  final Ref _ref;

  ReviewController(this._repository, this._ref)
    : super(const ReviewActionState());

  Future<PlaceReviewModel?> submitReview({
    required String placeId,
    required double rating,
    required String comment,
    String? visitPurpose,
    double? wifiRating,
    double? outletRating,
    double? comfortRating,
    double? noiseRating,
  }) async {
    state = const ReviewActionState(isLoading: true);
    try {
      final user = _ref.read(currentUserProfileProvider).valueOrNull;
      if (user == null) {
        throw const ReviewException('Silakan masuk terlebih dahulu.');
      }
      if (user.isGuest) {
        throw const ReviewException(
          'Tamu tidak dapat mempublikasikan review. Silakan daftar atau masuk dengan akun terdaftar.',
          code: 'guest-forbidden',
        );
      }

      final review = await _repository.publishReview(
        placeId: placeId,
        user: user,
        rating: rating,
        comment: comment,
        visitPurpose: visitPurpose,
        wifiRating: wifiRating,
        outletRating: outletRating,
        comfortRating: comfortRating,
        noiseRating: noiseRating,
      );

      state = ReviewActionState(lastPublishedReview: review);
      _ref.invalidate(currentUserReviewProvider(placeId));
      return review;
    } on ReviewException catch (e) {
      state = ReviewActionState(errorMessage: e.message);
      rethrow;
    } catch (e) {
      state = ReviewActionState(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<PlaceReviewModel?> editReview({
    required String placeId,
    required PlaceReviewModel existingReview,
    required double rating,
    required String comment,
    String? visitPurpose,
    double? wifiRating,
    double? outletRating,
    double? comfortRating,
    double? noiseRating,
  }) async {
    state = const ReviewActionState(isLoading: true);
    try {
      final user = _ref.read(currentUserProfileProvider).valueOrNull;
      if (user == null) {
        throw const ReviewException('Silakan masuk terlebih dahulu.');
      }
      if (user.isGuest) {
        throw const ReviewException(
          'Tamu tidak dapat mengedit review.',
          code: 'guest-forbidden',
        );
      }

      final updated = await _repository.updateReview(
        placeId: placeId,
        user: user,
        existingReview: existingReview,
        rating: rating,
        comment: comment,
        visitPurpose: visitPurpose,
        wifiRating: wifiRating,
        outletRating: outletRating,
        comfortRating: comfortRating,
        noiseRating: noiseRating,
      );

      state = ReviewActionState(lastPublishedReview: updated);
      _ref.invalidate(currentUserReviewProvider(placeId));
      return updated;
    } on ReviewException catch (e) {
      state = ReviewActionState(errorMessage: e.message);
      rethrow;
    } catch (e) {
      state = ReviewActionState(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> deleteReview({required String placeId}) async {
    state = const ReviewActionState(isLoading: true);
    try {
      final user = _ref.read(currentUserProfileProvider).valueOrNull;
      if (user == null) {
        throw const ReviewException('Silakan masuk terlebih dahulu.');
      }
      await _repository.deleteReview(placeId: placeId, userId: user.uid);
      state = const ReviewActionState();
      _ref.invalidate(currentUserReviewProvider(placeId));
    } catch (e) {
      state = ReviewActionState(errorMessage: e.toString());
      rethrow;
    }
  }
}

final reviewControllerProvider =
    StateNotifierProvider<ReviewController, ReviewActionState>((ref) {
      final repo = ref.watch(reviewRepositoryProvider);
      return ReviewController(repo, ref);
    });
