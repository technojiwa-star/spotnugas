import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/place_mock_data.dart';
import '../models/place.dart';
import '../models/saved_place_item.dart';
import '../repositories/saved_places_repository.dart';
import 'auth_provider.dart';

const String _kLocalSessionUserId = 'local_session_user';

final savedPlacesRepositoryProvider = Provider<SavedPlacesRepository>((ref) {
  final repo = SavedPlacesRepository();
  ref.onDispose(() {
    repo.clearAll();
  });
  return repo;
});

/// Streams all bookmarked places for the currently authenticated user
/// (works for registered accounts, anonymous guest accounts, and local offline sessions).
///
/// Automatically disposes when unused, releasing Firestore listeners.
final savedPlacesStreamProvider =
    StreamProvider.autoDispose<List<SavedPlaceItem>>((ref) {
      final userProfile = ref.watch(currentUserProfileProvider).valueOrNull;
      final uid = userProfile?.uid ?? _kLocalSessionUserId;
      final repo = ref.watch(savedPlacesRepositoryProvider);
      return repo.streamSavedPlaces(uid);
    });

/// Checks whether a given [placeId] is bookmarked by the current user.
final isPlaceSavedProvider = FutureProvider.family.autoDispose<bool, String>((
  ref,
  placeId,
) async {
  final userProfile = ref.watch(currentUserProfileProvider).valueOrNull;
  final uid = userProfile?.uid ?? _kLocalSessionUserId;
  final repo = ref.watch(savedPlacesRepositoryProvider);
  final savedInRepo = await repo.isPlaceSaved(uid, placeId);
  if (savedInRepo) return true;
  if (userProfile == null) {
    final mockPlace = PlaceMockData.byId(placeId);
    if (mockPlace != null) return mockPlace.isSaved;
  }
  return false;
});

/// Notifier to toggle bookmark state easily from UI widgets.
class SavedPlacesController extends StateNotifier<AsyncValue<void>> {
  final SavedPlacesRepository _repository;
  final Ref _ref;

  SavedPlacesController(this._repository, this._ref)
    : super(const AsyncValue.data(null));

  Future<bool> toggleSave(Place place) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProfileProvider).valueOrNull;
      final uid = user?.uid ?? _kLocalSessionUserId;
      final newStatus = await _repository.toggleSavedPlace(uid, place);
      place.isSaved = newStatus;
      state = const AsyncValue.data(null);
      // Invalidate stream & check providers
      _ref.invalidate(isPlaceSavedProvider(place.id));
      return newStatus;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<bool> setSaved(Place place, bool shouldSave) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProfileProvider).valueOrNull;
      final uid = user?.uid ?? _kLocalSessionUserId;
      if (shouldSave) {
        await _repository.savePlace(uid, place);
      } else {
        await _repository.removeSavedPlace(uid, place.id);
      }
      place.isSaved = shouldSave;
      state = const AsyncValue.data(null);
      _ref.invalidate(isPlaceSavedProvider(place.id));
      return shouldSave;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final savedPlacesControllerProvider =
    StateNotifierProvider<SavedPlacesController, AsyncValue<void>>((ref) {
      final repo = ref.watch(savedPlacesRepositoryProvider);
      return SavedPlacesController(repo, ref);
    });
