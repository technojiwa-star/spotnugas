import 'package:cloud_firestore/cloud_firestore.dart';
import 'place.dart';

/// Represents a review document inside:
/// `/places/{placeId}/reviews/{reviewId}`
///
/// In Firestore security rules:
/// - `reviewId` MUST equal `request.auth.uid` (one review per user per place).
/// - `userId` MUST equal `request.auth.uid`.
/// - Anonymous guests cannot publish.
/// - Ratings must be between 1.0 and 5.0.
/// - Personal sensitive information (email, phone) is strictly forbidden.
class PlaceReviewModel {
  final String id;
  final String placeId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final double rating;
  final String comment;
  final String? visitPurpose;
  final double? wifiRating;
  final double? outletRating;
  final double? comfortRating;
  final double? noiseRating;
  final double? priceValueRating;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Explicit flag to differentiate real verified Firestore reviews
  /// from mock demonstration seeds.
  final bool isMockDemonstration;

  const PlaceReviewModel({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.comment,
    this.visitPurpose,
    this.wifiRating,
    this.outletRating,
    this.comfortRating,
    this.noiseRating,
    this.priceValueRating,
    required this.createdAt,
    this.updatedAt,
    this.isMockDemonstration = false,
  });

  /// Validates review parameters before writing to Firestore.
  /// Throws [ArgumentError] if constraints are violated.
  static void validate({
    required double rating,
    required String comment,
    double? wifiRating,
    double? outletRating,
    double? comfortRating,
    double? noiseRating,
    double? priceValueRating,
  }) {
    if (rating < 1.0 || rating > 5.0) {
      throw ArgumentError.value(
        rating,
        'rating',
        'Rating harus bernilai antara 1.0 dan 5.0',
      );
    }
    final cleanComment = comment.trim();
    if (cleanComment.length < 3) {
      throw ArgumentError('Komentar review minimal berisi 3 karakter.');
    }
    if (cleanComment.length > 2000) {
      throw ArgumentError('Komentar review maksimal berisi 2000 karakter.');
    }

    void checkSubScore(double? val, String name) {
      if (val != null && (val < 1.0 || val > 5.0)) {
        throw ArgumentError.value(
          val,
          name,
          'Sub-skor $name harus bernilai antara 1.0 dan 5.0',
        );
      }
    }

    checkSubScore(wifiRating, 'Wi-Fi');
    checkSubScore(outletRating, 'Colokan');
    checkSubScore(comfortRating, 'Kenyamanan');
    checkSubScore(noiseRating, 'Ketenangan');
    checkSubScore(priceValueRating, 'Kesesuaian Harga');
  }

  factory PlaceReviewModel.fromMap(
    Map<String, dynamic> map,
    String id, {
    bool isMock = false,
  }) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return PlaceReviewModel(
      id: id,
      placeId: (map['placeId'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      userName: (map['userName'] as String?) ?? 'Pengguna SpotNugas',
      userAvatar: map['userAvatar'] as String?,
      rating: ((map['rating'] as num?) ?? 5.0).toDouble().clamp(1.0, 5.0),
      comment: (map['comment'] as String?) ?? '',
      visitPurpose: map['visitPurpose'] as String?,
      wifiRating: parseDouble(map['wifiRating']),
      outletRating: parseDouble(map['outletRating']),
      comfortRating: parseDouble(map['comfortRating']),
      noiseRating: parseDouble(map['noiseRating']),
      priceValueRating: parseDouble(map['priceValueRating']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      isMockDemonstration: isMock || (map['isMockDemonstration'] == true),
    );
  }

  factory PlaceReviewModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PlaceReviewModel.fromMap(doc.data() ?? {}, doc.id, isMock: false);
  }

  /// Converts legacy [PlaceReview] mock seed to [PlaceReviewModel].
  factory PlaceReviewModel.fromLegacyReview(
    PlaceReview legacy,
    String placeId,
  ) {
    return PlaceReviewModel(
      id: legacy.id,
      placeId: placeId,
      userId: 'mock_seed_user',
      userName: legacy.userName,
      userAvatar: legacy.userAvatar,
      rating: legacy.rating,
      comment: legacy.comment,
      visitPurpose: legacy.visitPurpose,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      isMockDemonstration: true,
    );
  }

  /// Converts this model to legacy [PlaceReview] for existing UI compatibility.
  PlaceReview toLegacyReview() {
    return PlaceReview(
      id: id,
      userName: userName,
      userAvatar: userAvatar ?? 'assets/images/kopi-ruang.jpg',
      rating: rating,
      date: _formatDate(createdAt),
      comment: comment,
      visitPurpose: visitPurpose ?? 'Nugas',
    );
  }

  static String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Hari ini';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  /// Client-safe serialization to Firestore map.
  /// PRIVACY HARDENING: Absolutely NEVER serialize user email or phone numbers!
  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'userId': userId,
      'userName': userName,
      if (userAvatar != null && userAvatar!.isNotEmpty)
        'userAvatar': userAvatar,
      'rating': rating,
      'comment': comment,
      if (visitPurpose != null && visitPurpose!.isNotEmpty)
        'visitPurpose': visitPurpose,
      if (wifiRating != null) 'wifiRating': wifiRating,
      if (outletRating != null) 'outletRating': outletRating,
      if (comfortRating != null) 'comfortRating': comfortRating,
      if (noiseRating != null) 'noiseRating': noiseRating,
      if (priceValueRating != null) 'priceValueRating': priceValueRating,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  PlaceReviewModel copyWith({
    String? id,
    String? placeId,
    String? userId,
    String? userName,
    String? userAvatar,
    double? rating,
    String? comment,
    String? visitPurpose,
    double? wifiRating,
    double? outletRating,
    double? comfortRating,
    double? noiseRating,
    double? priceValueRating,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isMockDemonstration,
  }) {
    return PlaceReviewModel(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      visitPurpose: visitPurpose ?? this.visitPurpose,
      wifiRating: wifiRating ?? this.wifiRating,
      outletRating: outletRating ?? this.outletRating,
      comfortRating: comfortRating ?? this.comfortRating,
      noiseRating: noiseRating ?? this.noiseRating,
      priceValueRating: priceValueRating ?? this.priceValueRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isMockDemonstration: isMockDemonstration ?? this.isMockDemonstration,
    );
  }
}
