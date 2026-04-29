import 'package:cloud_firestore/cloud_firestore.dart';

/// Roles available in the application.
enum UserRole {
  /// Regular end-user.
  user,

  /// Staff member (e.g. employee of a business).
  staff,

  /// Business owner / admin.
  business,
}

/// Extension helpers for [UserRole].
extension UserRoleX on UserRole {
  String get name {
    switch (this) {
      case UserRole.user:
        return 'user';
      case UserRole.staff:
        return 'staff';
      case UserRole.business:
        return 'business';
    }
  }

  static UserRole fromString(String? value) {
    switch (value) {
      case 'staff':
        return UserRole.staff;
      case 'business':
        return UserRole.business;
      default:
        return UserRole.user;
    }
  }
}

/// Application user model stored in Firestore.
class GazuUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const GazuUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.role = UserRole.user,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Creates a [GazuUser] from a Firestore document snapshot.
  factory GazuUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GazuUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      role: UserRoleX.fromString(data['role'] as String?),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Converts this user to a map suitable for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'role': role.name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  GazuUser copyWith({
    String? displayName,
    String? photoUrl,
    UserRole? role,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return GazuUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
