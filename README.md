# TakeBack

Take back your attention. Flutter for iOS and Android.

**Phase 3: iOS allowlist shielding is implemented; physical shielding validation is pending.**
On supported physical iPhones, LOCK IN applies Apple's ManagedSettings app shields
except for the 1–50 individual apps saved as allowed. UNLOCK clears TakeBack's
restrictions. Android and iOS simulators retain the explicit prototype behavior.

## Run

The current implementation builds with Flutter 3.47.5 and Xcode 27. iOS deployment
remains 16.0+. Flutter's SwiftPM integration supplies native plugins; the remaining
CocoaPods scaffolding is retained. Android requires the Android SDK.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

Use `ios/Runner.xcworkspace` in Xcode. Keep the existing signing team, bundle ID,
and Family Controls entitlement. Real restrictions require a provisioned physical
iPhone. Do not remove the entitlement to bypass provisioning errors.

## Architecture

Flutter → `AppRestrictionService` → `IosAppRestrictionService` →
`takeback/family_controls` → `FamilyControlsBridge` → `TakeBackRestrictionStore`.

`AllowedAppsStore` remains the only token store, using
`takeback.ios.allowedApplications.v1`. Tokens never cross the MethodChannel.
The named ManagedSettings store `takeback.lockdown` owns TakeBack's restriction
policy. The separate boolean `takeback.ios.lockdownRequested.v1` records native
intent; it cannot establish LOCKED IN without a matching active policy and approval.
`takeback.prototype.lockdownEnabled` is exclusively a simulation preference.

No new packages or extensions are required. UIScene, authorization, the native
picker, and selection persistence from Phase 2 are preserved.

## Behavior

- LOCK IN requires current authorization and a valid saved selection of 1–50 apps.
  An empty selection never means block everything. Selections above 50 are rejected
  at activation without truncation.
- Unlock before editing the allowlist. Category and website selections remain
  unsupported. Saving an empty selection while unlocked is valid, but cannot enable locking.
- Normal relaunch reads the existing policy without automatically applying one.
  Unresolved authorization preserves a valid existing policy and shows CHECKING
  with UNLOCK available. Denial clears TakeBack's policy and invalidates saved tokens.
- Failed verification never claims success. UNLOCK can be retried independently
  of authorization. Clearing TakeBack does not clear another app's Screen Time settings.
- Prototype fallback requires explicit unsupported-environment metadata. Native
  errors or denied authorization never silently fall back to simulated locking.

ManagedSettings readback verifies the app's configuration, not the visible shield
on every app. Apple determines effective restrictions and system-app exemptions.
See the [Phase 3 handoff and iPhone checklist](docs/phase-3-handoff.md).

## Check

```sh
flutter analyze
flutter test
flutter build ios --simulator
flutter build ios --no-codesign
flutter test integration_test/phase_one_test.dart -d <simulator-id>
```

Run `RunnerTests` from the Runner scheme on an iOS simulator. Policy tests use
inert identifiers and fake backends; they do not apply real device restrictions.
The integration smoke test exercises the simulator's prototype fallback.

The user reported Phase 2 authorization, picker, app-only saving, and populated
selection persistence across force-close/relaunch validated on an iPhone.
**Phase 3 shielding is not yet physically validated.**

## Scope

No NFC, Shortcuts, App Intents, schedules, timers, custom shield extensions,
analytics, Android blocking, accounts, backend, subscriptions, category allowlisting,
or web-domain allowlisting. Distribution approval remains separate from development signing.
