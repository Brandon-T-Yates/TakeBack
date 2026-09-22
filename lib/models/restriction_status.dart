enum AuthorizationStatus { unavailable, notDetermined, denied, authorized }

enum AppSelectionResult { unavailable, cancelled, selected }

/// A simulated lock must never be mistaken for a native restriction.
enum RestrictionMode { prototype, native }

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
  });

  final bool available;
  final AuthorizationStatus authorization;
  final bool hasSavedSelection;
  final int applicationCount;
  final bool selectionUsable;
  final RestrictionMode mode;
  final LockdownState lockdownState;
  final String? restrictionMessage;

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
    final mode = data['restrictionMode'] == 'prototype' && !available
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
    if (mode == RestrictionMode.native &&
        (data['restrictionMode'] != 'native' ||
            (lockdown == LockdownState.locked &&
                (!saved ||
                    count < 1 ||
                    count > 50 ||
                    data['selectionUsable'] != true)))) {
      lockdown = LockdownState.error;
    }
    return RestrictionSetupState(
      available: available,
      authorization: available
          ? authorization
          : AuthorizationStatus.unavailable,
      hasSavedSelection: saved,
      applicationCount: saved ? count : 0,
      selectionUsable: saved && data['selectionUsable'] == true,
      mode: mode,
      lockdownState: lockdown,
      restrictionMessage:
          data['restrictionMessage'] as String? ??
          (lockdown == LockdownState.error
              ? 'Could not confirm TakeBack’s restrictions. Tap UNLOCK to retry clearing them.'
              : null),
    );
  }
}
