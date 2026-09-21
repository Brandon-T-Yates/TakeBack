# Phase 2 handoff

Implementation is complete; physical-iPhone validation is **pending**. No
shielding or Phase 3 code has been added. No additional packages were needed.

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
Native authorization changes invalidate stored selections and dismiss an open
picker when approval is lost. Flutter receives updates while routes are open.
Reauthorization requires a fresh selection. Cancellation preserves a valid
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

There is currently **no configured team and no connected physical iPhone**.
A simulator or unsigned build does not establish that provisioning works. Signed
device validation stops here until setup is complete. TestFlight/App Store
Family Controls approval is separate; it has not been requested.
See [Apple's configuration guide](https://developer.apple.com/documentation/xcode/configuring-family-controls).

## Validation completed

- `flutter analyze`: clean.
- `flutter test`: 8 tests passed, including mocked authorization/cancellation,
  saved metadata, picker save/cancel responses, revocation notifications, iOS UI,
  prototype persistence and existing navigation.
- `flutter build ios --simulator`: passed.
- `flutter build ios --no-codesign`: physical-device release compilation passed.
- RunnerTests on iPhone 17 Pro simulator: 3 tests passed. Default selection is
  app-specific; category/website/expansion validation rejects unsupported choices;
  native empty selection restores, rejected Save preserves prior data, and clear
  removes it. No fabricated real app tokens were used.
- Updated integration smoke test on iPhone 17 Pro simulator: passed. It uses the
  real native channel, verifies unavailable setup and complete prototype flow,
  and reloads real local preferences. It does not test real Family Controls UI.

## Physical-device checks still required

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

## Phase 3 recommendation — not implemented

Validate ManagedSettings shielding across application categories with exceptions
for these explicit application tokens. Check Apple's exception limits, new apps,
system/emergency access, denied/revoked authorization, and reliable removal of
all restrictions on UNLOCK. Use native restriction state as the source of truth;
never activate restrictions from the Phase 1 prototype key. Proceed only after
physical authorization/picker validation and explicit Phase 3 approval.

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
