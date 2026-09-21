import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStore {
  PreferencesStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const disclaimerKey = 'takeback.disclaimerAccepted';
  static const onboardingKey = 'takeback.onboardingComplete';

  // Exclusively a UI simulation. Never migrate this into native restrictions.
  static const prototypeLockKey = 'takeback.prototype.lockdownEnabled';

  Future<bool> get disclaimerAccepted async =>
      await _preferences.getBool(disclaimerKey) ?? false;
  Future<bool> get onboardingComplete async =>
      await _preferences.getBool(onboardingKey) ?? false;
  Future<bool> get prototypeLockEnabled async =>
      await _preferences.getBool(prototypeLockKey) ?? false;

  Future<void> acceptDisclaimer() => _preferences.setBool(disclaimerKey, true);
  Future<void> completeOnboarding() =>
      _preferences.setBool(onboardingKey, true);
  Future<void> setPrototypeLock(bool enabled) =>
      _preferences.setBool(prototypeLockKey, enabled);
}
