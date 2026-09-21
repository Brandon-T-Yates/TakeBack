enum AuthorizationStatus { unavailable, notDetermined, denied, authorized }

enum AppSelectionResult { unavailable, cancelled, selected }

/// A simulated lock must never be mistaken for a native restriction.
enum RestrictionMode { prototype, native }

/// Metadata only. Application tokens never cross the native boundary.
class RestrictionSetupState {
  const RestrictionSetupState({
    this.available = false,
    this.authorization = AuthorizationStatus.unavailable,
    this.hasSavedSelection = false,
    this.applicationCount = 0,
    this.selectionUsable = false,
  });

  final bool available;
  final AuthorizationStatus authorization;
  final bool hasSavedSelection;
  final int applicationCount;
  final bool selectionUsable;

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
    return RestrictionSetupState(
      available: available,
      authorization: available
          ? authorization
          : AuthorizationStatus.unavailable,
      hasSavedSelection: saved,
      applicationCount: saved ? (data['applicationCount'] as int? ?? 0) : 0,
      selectionUsable: saved && data['selectionUsable'] == true,
    );
  }
}
