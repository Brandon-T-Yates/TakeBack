import 'package:flutter/foundation.dart';

import '../models/restriction_status.dart';
import '../services/app_restriction_service.dart';
import '../services/preferences_store.dart';

enum SetupStep { welcome, disclaimer, permission, allowedApps, complete }

class TakeBackController extends ChangeNotifier {
  TakeBackController({
    required PreferencesStore preferences,
    required AppRestrictionService restrictions,
  }) : _preferences = preferences,
       _restrictions = restrictions;

  final PreferencesStore _preferences;
  final AppRestrictionService _restrictions;
  SetupStep step = SetupStep.welcome;
  bool ready = false;
  bool busy = false;
  bool locked = false;
  String? error;
  AuthorizationStatus authorization = AuthorizationStatus.unavailable;
  AppSelectionResult selection = AppSelectionResult.unavailable;
  bool _accepted = false;

  RestrictionMode get mode => _restrictions.mode;

  Future<void> initialize() => _perform(() async {
    _accepted = await _preferences.disclaimerAccepted;
    final complete = await _preferences.onboardingComplete;
    locked = await _restrictions.isLockdownEnabled();
    step = !_accepted
        ? SetupStep.welcome
        : complete
        ? SetupStep.complete
        : SetupStep.permission;
    ready = true;
  });

  void getStarted() {
    step = SetupStep.disclaimer;
    notifyListeners();
  }

  Future<void> acceptDisclaimer() => _perform(() async {
    await _preferences.acceptDisclaimer();
    _accepted = true;
    step = SetupStep.permission;
  });

  Future<void> continueSetup() => _perform(() async {
    authorization = await _restrictions.requestAuthorization();
    selection = await _restrictions.selectAllowedApps();
    step = SetupStep.allowedApps;
  });

  Future<void> finishOnboarding() => _perform(() async {
    if (!_accepted) {
      step = SetupStep.disclaimer;
      return;
    }
    await _preferences.completeOnboarding();
    step = SetupStep.complete;
  });

  Future<void> toggleLockdown() => _perform(() async {
    await _restrictions.toggleLockdown();
    locked = await _restrictions.isLockdownEnabled();
  });

  Future<void> _perform(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (_) {
      error = 'Couldn’t save or load your preferences. Please try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
