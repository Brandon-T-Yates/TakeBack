# Phase 2 handoff

Phase 2 is complete. The user reported physical-iPhone validation of authorization,
the native picker, app-only saving, and populated selection persistence across
force-close/relaunch. Other edge-case checks below remain regression guidance.
This document describes the Phase 2 baseline; the current restriction behavior
and pending physical shielding checks are in the [Phase 3 handoff](phase-3-handoff.md).

## Architecture

Flutter → `AppRestrictionService` → `IosAppRestrictionService` → MethodChannel
`takeback/family_controls` → `FamilyControlsBridge`.

The channel supports `getSetupState`, `requestAuthorization`, and
`selectAllowedApps`; native code sends `setupChanged` notifications. Setup state
contains availability, authorization, saved-selection status, application count,
and usability. Opaque tokens, app names and bundle identifiers never cross it.
Swift hosts Apple's picker and stores a validated, encoded app-only selection in
`UserDefaults` under `takeback.ios.allowedApplications.v1`. Flutter owns onboarding
and product state. Lock/unlock/toggle still delegate to the Phase 1 prototype.

Authorization is checked on startup, foregrounding, picker presentation and Save.
Explicit denial invalidates stored selections; corrupt or unsupported stored data
is also removed. Startup `notDetermined` and unavailable states retain valid saved
tokens but report no usable selection until approval returns. An open picker is
dismissed when approval is lost. Flutter receives updates while routes are open.
Reauthorization after denial requires a fresh selection. Cancellation preserves a valid
previous selection; a deliberately saved empty selection is distinguishable from
no saved selection. The prototype key is never read by the native bridge.

## Manual Xcode steps — required before device validation

1. Open `ios/Runner.xcworkspace` (not the project alone).
2. Add your Apple Developer Program account in Xcode → Settings → Accounts.
3. Select Runner → Signing & Capabilities. Enable automatic signing, select your
   team, and replace `com.example.takeback` with your unique registered bundle ID.
4. Confirm **Family Controls (Development)**. The project already includes
   `Runner/Runner.entitlements` with `com.apple.developer.family-controls = true`
   and references it for Debug, Profile and Release. If the capability is absent
   in Xcode, add it with + Capability; do not remove the entitlement to bypass errors.
5. Let Xcode obtain a development profile containing the entitlement. If signing
   manually, enable Family Controls for that App ID in Developer Portal →
   Certificates, Identifiers & Profiles, regenerate the development profile for
   your device/certificate, and download/install it.
6. Connect and trust an iPhone running iOS 16+, enable Developer Mode, choose it as
   the run destination, and resolve Xcode signing/provisioning errors before running.

Development signing and physical-iPhone setup have since been used successfully.
Preserve the current project's team and bundle ID. A simulator or unsigned build
alone does not establish provisioning. TestFlight/App Store Family Controls
approval is separate from development provisioning.
See [Apple's configuration guide](https://developer.apple.com/documentation/xcode/configuring-family-controls).

## Validation completed

- `flutter analyze`: clean.
- `flutter test`: 8 tests passed, including mocked authorization/cancellation,
  saved metadata, picker save/cancel responses, revocation notifications, iOS UI,
  prototype persistence and existing navigation.
- `flutter build ios --simulator`: passed.
- `flutter build ios --no-codesign`: physical-device release compilation passed.
- RunnerTests on iPhone 18 Pro / iOS 27 simulator: 8 tests passed. Coverage includes
  bridge/store recreation, transient startup states, scene-activation updates,
  explicit denial, corrupt/wrong-type/unsupported stored data, app-only validation,
  and rejected Save preserving prior data. Persistence tests use a valid empty
  selection and compare stored bytes; populated Apple tokens still require the
  physical-device force-close/relaunch check. No fabricated app tokens were used.
- Updated integration smoke test on iPhone 17 Pro simulator: passed. It uses the
  real native channel, verifies unavailable setup and complete prototype flow,
  and reloads real local preferences. It does not test real Family Controls UI.

## Phase 2 physical-device regression checklist

- First authorization request and approval; deny and cancel separately; confirm
  **Continue in Prototype** remains available with no false authorization state.
- Open the picker, select individual apps, Save, and reopen to inspect them.
- Select a category or website; Save must explain rejection and leave the old
  allowlist unchanged. Deselect unsupported choices and save individual apps.
- Cancel and swipe-dismiss edits; confirm neither changes the saved selection.
- Force-quit/relaunch, edit selections, and explicitly save an empty selection.
- Revoke TakeBack's Screen Time access in iOS Settings, then return to the app:
  the selection must be unusable/cleared. Reauthorize and select apps afresh.
- Verify LOCK IN remains simulated, its notice stays visible, and its saved state
  remains independent of all authorization and picker operations.

## Picker limitation

Apple controls the native picker and exposes apps, categories and web domains.
TakeBack cannot hide those choices using the picker API in the installed SDK.
It uses `FamilyActivitySelection()` and rejects any nonempty category/web token
sets or category-expansion mode. It never converts categories into apps.

Apple's behavior when selecting all children in a category or ambiguous category
choices must be confirmed on hardware. If the picker marks such choices as a
category, Save will reject them rather than infer an app-specific allowlist.
If hardware testing exposes choices that cannot be reliably distinguished,
leave those choices unsupported and report the limitation before Phase 3.

## Phase 3 follow-up

Phase 3 was approved and implemented after the user reported the Phase 2 physical
checks above. See the [Phase 3 handoff](phase-3-handoff.md) for native allowlist
shielding, recovery semantics, and the required physical enforcement checklist.

## Files changed

- `README.md`
- `docs/phase-2-handoff.md`
- `integration_test/phase_one_test.dart`
- `ios/Flutter/AppFrameworkInfo.plist`
- `ios/Podfile`
- `ios/Podfile.lock`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner/AllowedAppsPicker.swift`
- `ios/Runner/AllowedAppsStore.swift`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/FamilyControlsBridge.swift`
- `ios/Runner/Runner.entitlements`
- `ios/RunnerTests/RunnerTests.swift`
- `lib/app.dart`
- `lib/main.dart`
- `lib/models/restriction_status.dart`
- `lib/screens/allowed_apps_screen.dart`
- `lib/screens/main_screen.dart`
- `lib/screens/permission_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/services/app_restriction_service.dart`
- `lib/services/ios_app_restriction_service.dart`
- `lib/services/local_app_restriction_service.dart`
- `lib/state/takeback_controller.dart`
- `lib/widgets/notices.dart`
- `test/ios_setup_test.dart`
