import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/place.dart';
import '../models/saved_place_item.dart';

class SavedPlacesRepository {
  final FirebaseFirestore? _injectedFirestore;

  /// In-memory cache keyed by userId -> map of (placeId -> SavedPlaceItem)
  /// Used for offline fallback, test environments, and immediate UI reactivity.
  final Map<String, Map<String, SavedPlaceItem>> _userCache = {};
  final Map<String, StreamController<List<SavedPlaceItem>>> _controllers = {};

  SavedPlacesRepository({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  bool get _isFirebaseReady =>
      _injectedFirestore != null || Firebase.apps.isNotEmpty;

  FirebaseFirestore get _firestore {
    if (_injectedFirestore != null) return _injectedFirestore;
    if (!_isFirebaseReady) {
      throw StateError('Firestore belum diinisialisasi.');
    }
    return FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> _userSavedCol(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_places');
  }

  /// Streams saved places for a specific [userId].
  ///
  /// Correctly handles listener lifecycle, account switching isolation,
  /// and offline fallback.
  Stream<List<SavedPlaceItem>> streamSavedPlaces(String userId) {
    if (userId.isEmpty) {
      return Stream.value(const []);
    }

    if (!_isFirebaseReady) {
      _ensureController(userId);
      return _controllers[userId]!.stream;
    }

    return _userSavedCol(userId)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => SavedPlaceItem.fromFirestore(doc))
              .toList();

          // Sync into local user cache for instantaneous lookups
          final userMap = _userCache.putIfAbsent(userId, () => {});
          userMap.clear();
          for (final item in items) {
            userMap[item.placeId] = item;
          }

          return items;
        })
        .handleError((error) {
          debugPrint('Firestore streamSavedPlaces error: $error');
          // Gracefully fallback to cached items on network failure / offline
          final cached = _userCache[userId]?.values.toList() ?? [];
          return cached;
        });
  }

  /// Checks if [placeId] is currently saved by [userId].
  Future<bool> isPlaceSaved(String userId, String placeId) async {
    if (userId.isEmpty || placeId.isEmpty) return false;

    // Check memory cache first
    if (_userCache[userId]?.containsKey(placeId) == true) {
      return true;
    }

    if (!_isFirebaseReady) {
      return false;
    }

    try {
      final doc = await _userSavedCol(userId).doc(placeId).get();
      final exists = doc.exists;
      if (exists) {
        _userCache.putIfAbsent(userId, () => {})[placeId] =
            SavedPlaceItem.fromFirestore(doc);
      }
      return exists;
    } catch (e) {
      debugPrint('isPlaceSaved error: $e');
      return _userCache[userId]?.containsKey(placeId) ?? false;
    }
  }

  /// Saves a place to `/users/{userId}/saved_places/{placeId}`.
  /// Works identically for registered users and anonymous guest users.
  Future<void> savePlace(String userId, Place place) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId tidak boleh kosong saat menyimpan tempat.');
    }

    final item = SavedPlaceItem.fromPlace(place);

    // Update in-memory cache and notify local stream
    final userMap = _userCache.putIfAbsent(userId, () => {});
    userMap[place.id] = item;
    _notifyController(userId);

    if (_isFirebaseReady) {
      try {
        await _userSavedCol(userId).doc(place.id).set(item.toMap());
      } catch (e) {
        debugPrint('savePlace Firestore write error: $e');
        // Offline persistence handles queuing if enabled
      }
    }
  }

  /// Removes a bookmarked place from `/users/{userId}/saved_places/{placeId}`.
  Future<void> removeSavedPlace(String userId, String placeId) async {
    if (userId.isEmpty || placeId.isEmpty) return;

    // Update in-memory cache
    final userMap = _userCache[userId];
    userMap?.remove(placeId);
    _notifyController(userId);

    if (_isFirebaseReady) {
      try {
        await _userSavedCol(userId).doc(placeId).delete();
      } catch (e) {
        debugPrint('removeSavedPlace Firestore delete error: $e');
      }
    }
  }

  /// Toggles saved status: returns the new saved state (true = saved, false = removed).
  Future<bool> toggleSavedPlace(String userId, Place place) async {
    final currentlySaved = await isPlaceSaved(userId, place.id);
    if (currentlySaved) {
      await removeSavedPlace(userId, place.id);
      return false;
    } else {
      await savePlace(userId, place);
      return true;
    }
  }

  /// Account switching isolation: clears active in-memory listeners and state
  /// so next logged-in user never sees remnants of previous user's session.
  void clearUserState(String userId) {
    _userCache.remove(userId);
    _controllers[userId]?.close();
    _controllers.remove(userId);
  }

  /// Clear all cache (e.g. on full logout)
  void clearAll() {
    _userCache.clear();
    for (final ctrl in _controllers.values) {
      ctrl.close();
    }
    _controllers.clear();
  }

  void _ensureController(String userId) {
    if (!_controllers.containsKey(userId) || _controllers[userId]!.isClosed) {
      _controllers[userId] = StreamController<List<SavedPlaceItem>>.broadcast(
        onListen: () {
          final items = _userCache[userId]?.values.toList() ?? [];
          _controllers[userId]?.add(items);
        },
      );
    }
  }

  void _notifyController(String userId) {
    if (_controllers.containsKey(userId) && !_controllers[userId]!.isClosed) {
      final items = _userCache[userId]?.values.toList() ?? [];
      _controllers[userId]?.add(items);
    }
  }
}
