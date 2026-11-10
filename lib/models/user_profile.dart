import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String name;
  final String? email;
  final String? photoUrl;
  final String role;
  final bool isGuest;
  final bool onboardingCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.name,
    this.email,
    this.photoUrl,
    this.role = 'user',
    this.isGuest = false,
    this.onboardingCompleted = true,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    final isAnonymous = (map['isGuest'] as bool?) ?? false;
    final rawName = map['name'] as String?;
    final defaultName = isAnonymous ? 'Tamu SpotNugas' : 'Pengguna SpotNugas';

    return UserProfile(
      uid: uid,
      name: (rawName != null && rawName.trim().isNotEmpty)
          ? rawName
          : defaultName,
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      role: (map['role'] as String?) ?? 'user',
      isGuest: isAnonymous,
      onboardingCompleted: (map['onboardingCompleted'] as bool?) ?? true,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return UserProfile.fromMap(doc.data() ?? {}, doc.id);
  }

  /// Client-safe serialization to Firestore map.
  /// Strictly prevents client from escalating role to admin or partner.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': 'user', // Never allow client to assign admin or partner role
      'isGuest': isGuest,
      'onboardingCompleted': onboardingCompleted,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': 'user',
      'isGuest': isGuest,
      'onboardingCompleted': onboardingCompleted,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? role,
    bool? isGuest,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isGuest: isGuest ?? this.isGuest,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
