# TakeBack

Take back your attention. Flutter for iOS and Android.

**Phase 2: no apps are blocked.** Supported physical iPhones can authorize Screen
Time and save an app-specific allowlist. LOCK IN / UNLOCK still changes only the
saved prototype state. Android and iOS simulators retain prototype navigation.

## Run

Use Flutter 3.35.7 / Dart 3.9.2 or a compatible newer stable SDK. iOS requires
Xcode, CocoaPods, and iOS 16+. Android requires the Android SDK.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

Real iOS setup requires Apple Developer Program signing and a physical iPhone.
Open `ios/Runner.xcworkspace`, select Runner → Signing & Capabilities, choose your
team and a unique bundle identifier, enable automatic signing, and confirm
**Family Controls (Development)**. Connect/trust an iPhone and enable Developer
Mode. See [Phase 2 handoff](docs/phase-2-handoff.md) for provisioning and checks.

## Structure

```text
lib/
  main.dart, app.dart, theme.dart
  screens/    # Existing onboarding, allowed apps, main, settings
  widgets/    # Branding, layout and notices
  models/     # Authorization and selection metadata
  services/   # Shared interface, iOS channel, prototype service, preferences
  state/      # ChangeNotifier controller
ios/Runner/   # FamilyControlsBridge, AllowedAppsPicker, AllowedAppsStore
              # AppDelegate registration and Runner.entitlements
test/        # Flutter unit/widget checks
integration_test/  # Prototype navigation/device-storage smoke test
```

`shared_preferences` remains the only additional runtime dependency; Phase 2
adds no packages. The iOS service uses `takeback/family_controls` for native setup
and delegates locking to the local simulation. Opaque app tokens stay in native
storage; Flutter receives authorization, counts and selection usability only.

`takeback.prototype.lockdownEnabled` is never a native restriction state.
The separate native key `takeback.ios.allowedApplications.v1` stores an encoded,
app-only selection. Detected loss of authorization clears it and requires
reselection. Existing users can authorize through **Edit Allowed Apps**.

## Picker limitation

Apple's picker exposes categories and websites; TakeBack does not support them.
Expand categories and select individual apps. Save rejects category/web tokens
with an explanation and preserves the previous allowlist. Category expansion is
never used to manufacture application selections. Real picker behavior—including
any automatic category selection—still needs physical-iPhone verification.

## Check

```sh
flutter analyze
flutter test
flutter build ios --simulator
flutter build ios --no-codesign
flutter test integration_test/phase_one_test.dart -d <simulator-id>
```

The smoke test resets only the three Flutter setup/prototype preferences and
exercises simulator fallback, not real authorization. Native tests are in
`ios/RunnerTests`; run Runner's test scheme on a simulator from Xcode.

On a signed iPhone, manually check authorization approval/denial/cancellation,
app-only selection, unsupported category/website rejection, Cancel, relaunch
restoration, editing, and revocation. Also check lock/reopen/unlock and the
persistent prototype notice. Details and validation results are in the handoff.

## Limits

Signing is not configured; the development identifier is `com.example.takeback`.
There is no ManagedSettings shielding, Android setup, NFC, Shortcuts, App Intents,
backend or cloud sync. Distribution approval is separate from development signing.
Phase 3 must validate allowlist shielding and safe unlocking before introducing
real restrictions. Never activate them from the saved prototype lock.
