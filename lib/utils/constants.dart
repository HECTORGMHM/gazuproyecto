/// Firestore collection names.
class AppCollections {
  static const String users = 'users';
  static const String businesses = 'businesses';
  static const String staff = 'staff';
}

/// Maximum consecutive failed login attempts before lockout check.
const int kMaxFailedLoginAttempts = 5;

/// Duration of account lockout in minutes.
const int kLockoutDurationMinutes = 15;
