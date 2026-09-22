# Unbound

Take back your time. Flutter for iOS and Android.

**Phase 4B: interactive iOS Home Screen widget and padlock polish.**
Phase 3 and Phase 4A were reported physically validated on an iPhone by the user.
The new widget is implemented but not yet physically validated.
On supported physical iPhones, LOCK IN applies Apple's ManagedSettings app shields
except for the 1–50 individual apps saved as allowed. UNLOCK clears Unbound's
restrictions. Android and iOS simulators retain the explicit prototype behavior.

## Run

The current implementation builds with Flutter 3.47.5 and Xcode 27. iOS deployment
remains 16.0+; the interactive widget requires iOS 17.0+. Flutter's SwiftPM integration supplies native plugins; the remaining
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
`takeback.ios.allowedApplications.v1` in an atomic App Group state file. Runner
migrates the existing private selection and intent before reconciliation; open the
app once after upgrading before using the widget. Tokens never cross the MethodChannel.
The named ManagedSettings store `takeback.lockdown` owns Unbound's restriction
policy. The separate boolean `takeback.ios.lockdownRequested.v1` records native
intent; it cannot establish LOCKED IN without a matching active policy and approval.
`takeback.prototype.lockdownEnabled` is exclusively a simulation preference.

The new `UnboundWidgetExtension` shares the native restriction implementation and
uses App Group `group.com.tyleryates.takeback`. No new Flutter package is required. UIScene, authorization, the native
picker, and selection persistence from Phase 2 are preserved.

## Behavior

- LOCK IN requires current authorization and a valid saved selection of 1–50 apps.
  An empty selection never means block everything. Selections above 50 are rejected
  at activation without truncation.
- LOCK IN remains immediate. A confirmed native UNLOCK asks “Ready to unlock?”;
  Stay Locked In changes nothing, and Unlock clears the existing policy. Checking
  or error recovery and prototype unlocking remain immediate. Widget UNLOCK is
  also direct and does not launch Flutter.
- Unlock before editing the allowlist. Category and website selections remain
  unsupported. Saving an empty selection while unlocked is valid, but cannot enable locking.
- Normal relaunch reads the existing policy without automatically applying one.
  Unresolved authorization preserves a valid existing policy and keeps UNLOCK
  available while checking. Denial clears Unbound's policy and invalidates saved tokens.
- Failed verification never claims success. UNLOCK can be retried independently
  of authorization. Clearing Unbound does not clear another app's Screen Time settings.
- Prototype fallback requires explicit unsupported-environment metadata. Native
  errors or denied authorization never silently fall back to simulated locking.

ManagedSettings readback verifies the app's configuration, not the visible shield
on every app. Apple determines effective restrictions and system-app exemptions.
See the [Phase 4B handoff, signing setup, and iPhone checklist](docs/phase-4b-handoff.md).

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
Phase 3 physical validation was reported complete by the user on September 22, 2026.
See the [Phase 4A handoff](docs/phase-4a-handoff.md) for branding and reflection behavior.

## Scope

Only the widget’s background App Intent is included. No NFC, user-created Shortcuts,
schedules, timers, custom shield extensions,
analytics, Android blocking, accounts, backend, subscriptions, category allowlisting,
or web-domain allowlisting. Distribution approval remains separate from development signing.
