import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../models/restriction_status.dart';
import '../services/app_restriction_service.dart';
import '../services/preferences_store.dart';

enum SetupStep { welcome, disclaimer, permission, allowedApps, complete }

class TakeBackController extends ChangeNotifier {
  TakeBackController({
    required PreferencesStore preferences,
    required AppRestrictionService restrictions,
  }) : _preferences = preferences,
       _restrictions = restrictions {
    _subscription = restrictions.setupChanges.listen((state) {
      _applySetup(state);
      if (!_disposed) notifyListeners();
    });
  }

  final PreferencesStore _preferences;
  final AppRestrictionService _restrictions;
  SetupStep step = SetupStep.welcome;
  bool ready = false;
  bool busy = false;
  bool locked = false;
  String? error;
  RestrictionSetupState setup = const RestrictionSetupState();
  AuthorizationStatus get authorization => setup.authorization;
  AppSelectionResult selection = AppSelectionResult.unavailable;
  bool _accepted = false;
  bool _disposed = false;
  bool _refreshPending = false;
  late final StreamSubscription<RestrictionSetupState> _subscription;

  RestrictionMode get mode => _restrictions.mode;
  LockdownState get lockdownState => mode == RestrictionMode.prototype
      ? (locked ? LockdownState.locked : LockdownState.unlocked)
      : setup.lockdownState;
  bool get needsUnlock => lockdownState != LockdownState.unlocked;
  bool get canEditAllowedApps =>
      mode == RestrictionMode.prototype || !needsUnlock;

  Future<void> initialize() => _perform(() async {
    _accepted = await _preferences.disclaimerAccepted;
    final complete = await _preferences.onboardingComplete;
    step = !_accepted
        ? SetupStep.welcome
        : complete
        ? SetupStep.complete
        : SetupStep.permission;
    try {
      await _readSetup();
    } finally {
      // Native state failures must not hide the main screen's UNLOCK recovery.
      ready = true;
    }
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
    step = SetupStep.allowedApps;
  });

  Future<void> authorize() => _perform(() async {
    try {
      await _restrictions.requestAuthorization();
    } finally {
      await _readSetup();
    }
  });

  Future<void> chooseAllowedApps() => _perform(() async {
    if (!canEditAllowedApps) {
      throw PlatformException(
        code: 'unlock_required',
        message: 'Unlock TakeBack before changing your allowed apps.',
      );
    }
    try {
      selection = await _restrictions.selectAllowedApps();
    } finally {
      await _readSetup();
    }
  });

  Future<void> _readSetup() async {
    try {
      _applySetup(await _restrictions.getSetupState());
      if (mode == RestrictionMode.prototype) {
        locked = await _restrictions.isLockdownEnabled();
      }
    } catch (_) {
      if (mode == RestrictionMode.native) {
        _applySetup(
          const RestrictionSetupState(
            mode: RestrictionMode.native,
            lockdownState: LockdownState.error,
            restrictionMessage:
                'Could not confirm TakeBack’s restrictions. Tap UNLOCK to retry clearing them.',
          ),
        );
      }
      rethrow;
    }
  }

  void _applySetup(RestrictionSetupState state) {
    setup = state;
    if (mode == RestrictionMode.native) {
      locked = state.lockdownState == LockdownState.locked;
    }
  }

  Future<void> refreshSetup() async {
    if (busy) {
      _refreshPending = true;
      return;
    }
    await _perform(_readSetup);
  }

  Future<void> finishOnboarding() => _perform(() async {
    if (!_accepted) {
      step = SetupStep.disclaimer;
      return;
    }
    await _preferences.completeOnboarding();
    step = SetupStep.complete;
  });

  Future<void> toggleLockdown() => _perform(() async {
    try {
      if (mode == RestrictionMode.native && needsUnlock) {
        // A displayed UNLOCK must never re-enable a policy that was just cleared.
        await _restrictions.disableLockdown();
      } else {
        await _restrictions.toggleLockdown();
      }
    } finally {
      await _readSetup();
    }
  });

  Future<void> _perform(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      if (_refreshPending) {
        _refreshPending = false;
        await _readSetup();
      }
    } on PlatformException catch (exception) {
      error =
          exception.message ??
          'Screen Time setup could not be completed. Please try again.';
    } catch (_) {
      error = 'Couldn’t save or load your preferences. Please try again.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    _restrictions.dispose();
    super.dispose();
  }
}
