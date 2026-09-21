import '../models/restriction_status.dart';

/// Platform boundary. Widgets never handle native permissions or app tokens.
/// Native implementations must query their own state, never the prototype
/// preference. Native selection tokens stay native.
abstract interface class AppRestrictionService {
  RestrictionMode get mode;
  Future<AuthorizationStatus> requestAuthorization();
  Future<AppSelectionResult> selectAllowedApps();
  Future<void> enableLockdown();
  Future<void> disableLockdown();
  Future<void> toggleLockdown();
  Future<bool> isLockdownEnabled();
}
