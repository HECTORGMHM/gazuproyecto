/// Firestore collection names.
class AppCollections {
  static const String users = 'users';
  static const String businesses = 'businesses';
  // Collection used for the Alta de Negocio flow (issue #2).
  static const String negocios = 'negocios';
  static const String staff = 'staff';
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
