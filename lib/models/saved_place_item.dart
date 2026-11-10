import 'package:cloud_firestore/cloud_firestore.dart';
import 'place.dart';

/// Represents a bookmarked place document inside:
/// `/users/{userId}/saved_places/{placeId}`
class SavedPlaceItem {
  final String placeId;
  final String name;
  final String category;
  final String image;
  final double rating;
  final String priceLabel;
  final String? address;
  final DateTime savedAt;
  final String? source;

  const SavedPlaceItem({
    required this.placeId,
    required this.name,
    required this.category,
    required this.image,
    required this.rating,
    required this.priceLabel,
    this.address,
    required this.savedAt,
    this.source,
  });

  /// Factory helper from unified [Place] domain model.
  factory SavedPlaceItem.fromPlace(Place place, {DateTime? savedAt}) {
    return SavedPlaceItem(
      placeId: place.id,
      name: place.name,
      category: place.category,
      image: place.image,
      rating: place.rating,
      priceLabel: place.priceLabel,
      address: place.address,
      savedAt: savedAt ?? DateTime.now(),
      source: place.source.value,
    );
  }

  factory SavedPlaceItem.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return SavedPlaceItem(
      placeId: (map['placeId'] as String?) ?? id,
      name: (map['name'] as String?) ?? 'Tempat Tanpa Nama',
      category: (map['category'] as String?) ?? 'Tempat Nugas',
      image: (map['image'] as String?) ?? '',
      rating: ((map['rating'] as num?) ?? 0.0).toDouble(),
      priceLabel: (map['priceLabel'] as String?) ?? '-',
      address: map['address'] as String?,
      savedAt: parseDate(map['savedAt']),
      source: map['source'] as String?,
    );
  }

  factory SavedPlaceItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SavedPlaceItem.fromMap(doc.data() ?? {}, doc.id);
  }

  /// Client-safe serialization to Firestore map.
  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'name': name,
      'category': category,
      'image': image,
      'rating': rating,
      'priceLabel': priceLabel,
      if (address != null && address!.isNotEmpty) 'address': address,
      'savedAt': Timestamp.fromDate(savedAt),
      if (source != null && source!.isNotEmpty) 'source': source,
    };
  }

  SavedPlaceItem copyWith({
    String? placeId,
    String? name,
    String? category,
    String? image,
    double? rating,
    String? priceLabel,
    String? address,
    DateTime? savedAt,
    String? source,
  }) {
    return SavedPlaceItem(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      category: category ?? this.category,
      image: image ?? this.image,
      rating: rating ?? this.rating,
      priceLabel: priceLabel ?? this.priceLabel,
      address: address ?? this.address,
      savedAt: savedAt ?? this.savedAt,
      source: source ?? this.source,
    );
  }

  /// Reconstructs a domain [Place] when the venue is not in the local mock seed
  /// (e.g., a bookmarked Geoapify place loaded from Firestore or cache).
  Place toPlace() {
    final parsedSource =
        PlaceSource.tryParse(source) ??
        (placeId.startsWith('geoapify:')
            ? PlaceSource.geoapify
            : PlaceSource.manual);
    final rawGeoId = placeId.startsWith('geoapify:')
        ? placeId.substring('geoapify:'.length)
        : placeId;
    return Place(
      id: placeId,
      source: parsedSource,
      geoapifyPlaceId: parsedSource == PlaceSource.geoapify ? rawGeoId : null,
      googlePlaceId: parsedSource == PlaceSource.google ? placeId : null,
      name: name,
      category: category,
      address: address,
      latitude: -6.2297,
      longitude: 106.8295,
      photoUrls: image.isNotEmpty ? [image] : const [],
      communityRating: rating > 0 ? rating : null,
      isSaved: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedPlaceItem &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId;

  @override
  int get hashCode => placeId.hashCode;
}
