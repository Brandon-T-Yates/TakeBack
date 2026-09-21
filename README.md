# TakeBack

Take back your attention. A Flutter prototype for iOS and Android.

**Phase 1 only: no apps are blocked.** Permissions and app selection are honest
placeholders. LOCK IN / UNLOCK changes a locally saved simulation.

## Run

Use Flutter 3.35.7 / Dart 3.9.2 or a compatible newer stable SDK. iOS requires
Xcode and CocoaPods; Android requires the Android SDK and a configured emulator.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

Open an iOS simulator or launch an Android emulator before running. Physical iOS
devices also require a signing team in `ios/Runner.xcworkspace`.

## Structure

```text
lib/
  main.dart, app.dart, theme.dart
  screens/    # Welcome, disclaimer, permissions, allowed apps, main, settings
  widgets/    # Branding, page layout, shared notices
  models/     # Restriction mode and operation results
  services/   # Restriction interface, local simulation, preferences
  state/      # ChangeNotifier controller
test/         # Basic unit/widget checks
integration_test/  # One device smoke test
ios/, android/     # Native Flutter runners
```

`shared_preferences` is the only extra runtime dependency. `SharedPreferencesAsync`
saves disclaimer acceptance, onboarding completion, and
`takeback.prototype.lockdownEnabled`. That last key is **never** a native
restriction state and must not be migrated into one. Native app tokens will stay
behind `AppRestrictionService`; there is no fake app list. State and navigation
use Flutter's built-in APIs. `integration_test` is an SDK-only development dependency.

## Check

```sh
flutter analyze
flutter test
flutter build ios --simulator
flutter build apk --debug
flutter test integration_test/phase_one_test.dart -d <device-id>
```

The device smoke test resets only TakeBack's three setup/prototype preferences.
Manually check fresh onboarding, LOCK IN, force-quit/reopen while locked, UNLOCK,
Edit Allowed Apps → Done, Settings → Back, and larger system text. The prototype
notice must remain visible on Main. To repeat first launch, clear app data or
uninstall/reinstall on a test device.

## Limits and next phase

Development identifiers are `com.example.takeback`; signing and release branding
are not configured. There is no OS blocking, authorization, native picker, NFC,
backend, authentication, or cloud sync. The saved simulation survives restarts;
incomplete setup resumes after the disclaimer when acceptance has been saved.

Phase 2 (not implemented): configure Family Controls capability/entitlements,
add individual Screen Time authorization and a native allowed-app picker,
persist opaque tokens natively, and bridge through `AppRestrictionService`.
Validate on a physical iPhone, including denied/revoked authorization and picker
cancellation. Verify the allowlist restriction approach before adding real
blocking. Never activate real restrictions from a saved prototype lock.
