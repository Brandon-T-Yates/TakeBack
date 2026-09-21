import '../models/restriction_status.dart';
import 'app_restriction_service.dart';
import 'preferences_store.dart';

/// Phase 1 only: persists a simulation and never changes device restrictions.
class LocalAppRestrictionService implements AppRestrictionService {
  LocalAppRestrictionService(this._preferences);

  final PreferencesStore _preferences;

  @override
  RestrictionMode get mode => RestrictionMode.prototype;
  @override
  Future<AuthorizationStatus> requestAuthorization() async =>
      AuthorizationStatus.unavailable;
  @override
  Future<AppSelectionResult> selectAllowedApps() async =>
      AppSelectionResult.unavailable;
  @override
  Future<void> enableLockdown() => _preferences.setPrototypeLock(true);
  @override
  Future<void> disableLockdown() => _preferences.setPrototypeLock(false);
  @override
  Future<void> toggleLockdown() async {
    await _preferences.setPrototypeLock(!await isLockdownEnabled());
  }

  @override
  Future<bool> isLockdownEnabled() => _preferences.prototypeLockEnabled;
}
