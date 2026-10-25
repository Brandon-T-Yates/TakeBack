enum AuthorizationStatus { unavailable, notDetermined, denied, authorized }

enum AppSelectionResult { unavailable, cancelled, selected }

/// A simulated lock must never be mistaken for a native restriction.
/// `native` is the iOS Screen Time implementation. `android` is the Android
/// implementation, which enforces LOCK IN through Unbound's Accessibility service.
enum RestrictionMode { prototype, native, android }

enum LockdownState { unlocked, locked, checking, error }

/// Metadata only. Application tokens never cross the native boundary.
class RestrictionSetupState {
  const RestrictionSetupState({
    this.available = false,
    this.authorization = AuthorizationStatus.unavailable,
    this.hasSavedSelection = false,
    this.applicationCount = 0,
    this.selectionUsable = false,
    this.mode = RestrictionMode.prototype,
    this.lockdownState = LockdownState.unlocked,
    this.restrictionMessage,
    this.revision,
    this.accessibilityEnabled = false,
    this.accessibilityRunning = false,
    this.enforcing = false,
    this.accessInterrupted = false,
  });

  final bool available;
  final AuthorizationStatus authorization;
  final bool hasSavedSelection;
  final int applicationCount;
  final bool selectionUsable;
  final RestrictionMode mode;
  final LockdownState lockdownState;
  final String? restrictionMessage;
  final int? revision;

  /// Android only: Unbound's Accessibility service is switched on in Settings.
  final bool accessibilityEnabled;

  /// Android only: Android has the service bound, so it can act on app launches.
  final bool accessibilityRunning;

  /// Android only: LOCK IN is requested and actually being enforced.
  final bool enforcing;

  /// Android only: LOCK IN was turned off because Accessibility access was
  /// turned off. Cleared the next time LOCK IN succeeds.
  final bool accessInterrupted;

  factory RestrictionSetupState.fromNative(Map<Object?, Object?> data) {
    final authorization = switch (data['authorization']) {
      'authorized' => AuthorizationStatus.authorized,
      'denied' => AuthorizationStatus.denied,
      'notDetermined' => AuthorizationStatus.notDetermined,
      _ => AuthorizationStatus.unavailable,
    };
    final available = data['available'] == true;
    final authorized =
        available && authorization == AuthorizationStatus.authorized;
    final saved = authorized && data['hasSavedSelection'] == true;
    // Only explicit native capability metadata permits simulator fallback.
    final mode = data['restrictionMode'] == 'android'
        ? RestrictionMode.android
        : data['restrictionMode'] == 'prototype' && !available
        ? RestrictionMode.prototype
        : RestrictionMode.native;
    var lockdown = switch (data['lockdownState']) {
      'locked' => LockdownState.locked,
      'unlocked' => LockdownState.unlocked,
      'checking' => LockdownState.checking,
      _ => LockdownState.error,
    };
    final count = data['applicationCount'] is int
        ? data['applicationCount'] as int
        : 0;
    final selectionReady =
        saved && count >= 1 && count <= 50 && data['selectionUsable'] == true;
    if (mode == RestrictionMode.native &&
        (data['restrictionMode'] != 'native' ||
            (lockdown == LockdownState.locked && !selectionReady))) {
      lockdown = LockdownState.error;
    }
    final enforcing = mode == RestrictionMode.android &&
        data['enforcing'] == true &&
        selectionReady;
    if (mode == RestrictionMode.android &&
        lockdown == LockdownState.locked &&
        !enforcing) {
      lockdown = LockdownState.error;
    }
    return RestrictionSetupState(
      available: available,
      authorization: available
          ? authorization
          : AuthorizationStatus.unavailable,
      hasSavedSelection: saved,
      applicationCount: saved ? count : 0,
      selectionUsable: selectionReady,
      mode: mode,
      lockdownState: lockdown,
      restrictionMessage:
          data['restrictionMessage'] as String? ??
          (lockdown == LockdownState.error
              ? 'Could not confirm Unbound’s restrictions. Tap UNLOCK to retry clearing them.'
              : null),
      revision: data['revision'] is int ? data['revision'] as int : null,
      accessibilityEnabled: data['accessibilityEnabled'] == true,
      accessibilityRunning: data['accessibilityRunning'] == true,
      enforcing: enforcing,
      accessInterrupted:
          mode == RestrictionMode.android && data['accessInterrupted'] == true,
    );
  }
}
