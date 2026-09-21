enum AuthorizationStatus { unavailable, notDetermined, denied, authorized }

enum AppSelectionResult { unavailable, cancelled, selected }

/// A simulated lock must never be mistaken for a native restriction.
enum RestrictionMode { prototype, native }
