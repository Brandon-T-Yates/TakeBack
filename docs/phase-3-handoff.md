# Phase 3 handoff

Real iOS allowlist shielding is implemented. **Physical shielding validation is
pending.** Phase 2 authorization, native picker, app-only saving, and populated
selection persistence across force-close/relaunch were reported validated by the
user on a physical iPhone. This does not establish Phase 3 shield enforcement.

## Policy and ownership

`TakeBackRestrictionStore` owns `ManagedSettingsStore(named: .init("takeback.lockdown"))`.
It sets only `shield.applicationCategories = .all(except: allowedApplicationTokens)`.
These tokens are exceptions, never apps to block. Apple documents that the
controlling app is exempt from `.all` and allows at most 50 application exceptions.
See [applicationCategories](https://developer.apple.com/documentation/managedsettings/shieldsettings/applicationcategories-swift.property).

Activation requires availability, approved authorization, and a valid saved
selection of 1–50 apps. Tokens come directly from `AllowedAppsStore`; there is no
second token store. Empty selections remain saveable while unlocked, but LOCK IN
rejects them with “Choose at least one allowed app before locking in.” Oversized
allowlists are rejected without truncation. Unlock before opening the picker.

The backend reads back the exact configured policy before recording native intent
under `takeback.ios.lockdownRequested.v1`. The installed SDK declares `isActive`
available from iOS 26.5, so property writes/readback use `#available(iOS 26.5, *)`.
Earlier supported versions verify the policy without that property. No `activate()`
API is used. The deployment target remains iOS 16.0.

UNLOCK calls `clearAllSettings()` only on TakeBack's named store. It verifies the
shield settings are empty before removing intent and reporting UNLOCKED. Repeated
lock/unlock calls are safe. Failed writes trigger cleanup; unconfirmed cleanup
retains recovery state and an available UNLOCK action.

## State and recovery

Reconciliation runs on setup reads, restriction operations, scene activation, and
authorization changes. It never reapplies restrictions merely because intent is saved.

| Condition | Behavior |
| --- | --- |
| Approved, valid saved tokens, intent, matching active policy | LOCKED IN |
| No policy, or inactive store | Remove stale intent; UNLOCKED after cleanup |
| Orphan, mismatched, or invalid policy/selection | Clear TakeBack's policy; verify before UNLOCKED |
| Unresolved authorization with otherwise valid existing policy | Retain policy and saved tokens; CHECKING with UNLOCK |
| Explicit denial | Clear policy, intent, and saved selection; notify Flutter |
| Read/clear failure | STATE UNCONFIRMED with retryable UNLOCK |

ManagedSettings exposes configured state, not a per-app enforcement receipt.
Readback does not prove every shield is visibly enforced. The operating system
combines settings and determines effective behavior; see
[ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore).

## Flutter boundary

The existing `takeback/family_controls` channel adds `enableLockdown`,
`disableLockdown`, `toggleLockdown`, and `isLockdownEnabled`. Mutation replies and
`setupChanged` notifications include setup metadata plus `restrictionMode`,
`lockdownState` (`locked`, `unlocked`, `checking`, `error`), and an optional
`restrictionMessage`. Boolean queries error when state is unresolved.

The controller consumes snapshots at startup, foregrounding, after operations,
and on notifications. A displayed UNLOCK always sends an explicit clear request;
it cannot accidentally toggle a stale lock back on. Native errors do not prevent
recovery screens from rendering. Mode-aware copy no longer describes real iPhone
locking as a simulation. Android and simulators retain their prototype behavior.
The old prototype preference is never migrated into native intent or restrictions.

## Automated validation

Completed on September 21, 2026 with Flutter 3.47.5 and Xcode 27:

- `flutter analyze --no-pub`: clean.
- `flutter test --no-pub`: all 17 tests passed.
- Runner native tests on the iOS 27 simulator: all 19 tests passed.
- `flutter build ios --simulator --no-pub`: passed.
- `flutter build ios --no-codesign --no-pub`: unsigned release build passed.
- Existing `integration_test/phase_one_test.dart` on the iOS 27 simulator: passed.
- Final diff review: Xcode build configurations, signing, entitlements, UIScene,
  SwiftPM configuration, Dart dependencies, and Android files unchanged.
  Built simulator and device manifests retain `MinimumOSVersion = 16.0`.

Flutter builds/tests used `FLUTTER_SWIFT_PACKAGE_MANAGER=true`. Existing CocoaPods
scaffolding remains intentionally retained; Flutter's optional removal notice
does not prevent the builds.

Native policy tests use generic inert identifiers with fake backends. Existing
selection tests retain valid empty `FamilyActivitySelection` fixtures rather than
fabricating Apple tokens. No automated test establishes real shield enforcement.

## Physical-iPhone checklist — required

1. Authorize Screen Time and save a small app-only allowlist (at least one app).
2. Press LOCK IN; confirm LOCKED IN appears only after success, without a prototype notice.
3. Open each allowed app and confirm it remains accessible.
4. Open a non-allowed third-party app and confirm Apple's default shield appears.
5. Confirm TakeBack itself remains accessible, including the UNLOCK button.
6. Force-close/reopen TakeBack. Verify accurate LOCKED IN restoration; if briefly
   CHECKING, UNLOCK must remain available and approval should restore the state.
7. Press UNLOCK; confirm TakeBack reports UNLOCKED after clearing its policy.
8. Confirm previously shielded apps open normally, absent unrelated Screen Time restrictions.
9. Repeat Lock/Unlock; confirm repeated operations remain safe. Confirm editing
   requires unlocking; saving zero apps must prevent the next LOCK IN.
10. Revoke TakeBack's Screen Time authorization while locked, then return. Confirm
    no LOCKED IN claim, cleared restrictions where possible, unusable selection,
    and recovery via UNLOCK if verification fails. Reauthorize and select apps afresh.

Also retain Phase 2 regressions for picker cancellation, unsupported selections,
and saved populated selections. Test iOS 16–26.4 policy-only readback separately
from newer systems that expose `isActive` when suitable devices are available.

## Scope boundary

No shielding extension or additional entitlement was added. Signing, UIScene,
SwiftPM, and Android remain intact. No NFC, schedules, timers, Shortcuts, App Intents,
custom shields, backend, subscriptions, or Phase 4 work is included.

## Changed files

- Native implementation: `ios/Runner/TakeBackRestrictionStore.swift`,
  `ios/Runner/FamilyControlsBridge.swift`, `ios/Runner/AllowedAppsPicker.swift`,
  `ios/Runner.xcodeproj/project.pbxproj` (source registration only).
- Flutter state and service: `lib/models/restriction_status.dart`,
  `lib/services/ios_app_restriction_service.dart`, `lib/state/takeback_controller.dart`.
- Flutter presentation: `lib/screens/allowed_apps_screen.dart`,
  `lib/screens/disclaimer_screen.dart`, `lib/screens/main_screen.dart`,
  `lib/screens/permission_screen.dart`, `lib/screens/settings_screen.dart`,
  `lib/widgets/notices.dart`.
- Tests: `ios/RunnerTests/RunnerTests.swift`, `test/ios_setup_test.dart`,
  `test/ios_restrictions_test.dart`.
- Documentation: `README.md`, `docs/phase-2-handoff.md`, `docs/phase-3-handoff.md`.
