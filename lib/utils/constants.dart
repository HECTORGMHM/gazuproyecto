/// Firestore collection names.
class AppCollections {
  static const String users = 'users';
  /// Legacy/general businesses collection (retained for compatibility).
  static const String businesses = 'businesses';
  /// Collection used exclusively for the Alta de Negocio flow (issue #2).
  /// The product spec names this collection 'negocios'.
  static const String negocios = 'negocios';
  static const String staff = 'staff';
  static const String appointments = 'appointments';
  static const String reviews = 'reviews';
  static const String reputationStats = 'reputationStats';
  /// Subcollection under each negocio document for its offered services.
  static const String servicios = 'servicios';
}

/// Brand colours shared across the Alta de Negocio flow.
class AppColors {
  static const primaryOrange = 0xFFFF6600;
  static const scaffoldCharcoal = 0xFF212121;
}

/// Maximum consecutive failed login attempts before lockout check.
const int kMaxFailedLoginAttempts = 5;

/// Duration of account lockout in minutes.
const int kLockoutDurationMinutes = 15;
