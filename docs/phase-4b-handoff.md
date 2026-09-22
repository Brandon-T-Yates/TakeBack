# Phase 4B handoff: interactive Home Screen widget

Phase 4B is implemented. **The repaired widget controls are awaiting successful
physical retesting.** The user reported Phase 3 and Phase 4A physically validated
on an iPhone before this work. No real restrictions were applied by automated tests.

## Post-commit widget interaction repair

Initial physical testing found that tapping the configured widget's LOCK IN or
UNLOCK control opened Runner. `SetLockdownIntent` was compiled only into the widget
extension. [Apple's interactive-widget guidance](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
requires the custom App Intent used by an interactive widget to belong to both the
containing app and widget-extension targets so the system can discover and route it
correctly. The button itself was already a real
`Button(intent:)`; there was no `Link`, `.widgetURL`, `OpenURLIntent`, `OpenIntent`,
or container-level URL causing the launch.

The repair adds the existing intent source to Runner's Sources phase while retaining
the widget-extension membership. It keeps `openAppWhenRun = false`, keeps background
execution on iOS 26, and on the installed iOS 27 SDK explicitly limits execution to
`.widgetKitExtension`. Both built products now publish `SetLockdownIntent` metadata
with `openAppWhenRun: false`, background mode, and the WidgetKit extension target.
No restriction, coordinator, storage, synchronization, or UI code changed.

Automated tests and metadata inspection establish the intended background/widget
execution configuration, but they cannot prove that SpringBoard stays visible.
Reinstall the updated build (and remove/re-add the widget if iOS retains its prior
intent registration) and repeat the focused physical checks at the end of this file.

## User experience

The shared Unbound header is text-only. The main control uses an open padlock with
LOCK IN when unlocked, and a closed padlock with UNLOCK when locked. Checking/error
states use a muted padlock with a question mark and keep immediate recovery.
The status pill stays removed; in-app confirmed unlocking retains the reflection
prompt. Android/simulator app locking remains the original prototype behavior.

The new small Home Screen widget contains only Unbound, a padlock, and one action:

| Native state | Widget action |
| --- | --- |
| Approved, valid 1–50 app allowlist, verified unlocked | Open padlock / LOCK IN |
| Verified locked | Closed padlock / UNLOCK |
| Checking or error | Muted padlock/question mark / direct UNLOCK |
| Setup or migration needed | Neutral padlock / Open Unbound |

Ordinary widget Lock/Unlock executes in the extension without launching Flutter.
Widget UNLOCK is intentionally direct. Repeated/stale actions request an explicit
state; they never blindly toggle. The intent reports success only after native
readback. There is no optimistic Toggle presentation. On the simulator, the actual
widget shows Open Unbound and refuses real restrictions; rendering tests inject
all presentation states.

## Targets and native boundary

- Runner: existing `com.tyleryates.takeback`, iOS 16.0 minimum.
- `UnboundWidgetExtension`: `com.tyleryates.takeback.UnboundWidget`, iOS 17.0 minimum,
  SwiftUI/WidgetKit with only `.systemSmall` support. It has a standalone build scheme,
  is embedded before Flutter's Thin Binary phase, and does not link Flutter.
- `SetLockdownIntent(enabled:)` is extension-only, background-only, undiscoverable,
  and has no Shortcuts provider. Its newer `supportedModes` declaration is guarded
  by SDK availability; older supported systems use `openAppWhenRun = false`.
- Both processes compile the same native selection/policy/backend sources. The
  existing MethodChannel and setup snapshot shape are unchanged.

`NativeRestrictionCoordinator` owns the shared transaction boundary. It rechecks
live authorization, loads native selection data, and calls the existing generic
restriction policy. The named store remains `takeback.lockdown`; the only applied
policy remains `.all(except: applicationTokens)`. The installed SDK's iOS 26.5
`isActive` availability guard is unchanged. Readback verifies configured policy,
not visible enforcement in every app.

A short, nonblocking POSIX transaction lock serializes mutations and reconciliation
across processes. A separate process-held setup lease prevents widget activation
while authorization or picker editing is open. Unlock does not require that setup
lease. Locks release on process exit; contention reports a retryable error rather
than waiting on a suspended process. Failure to open shared storage still permits
an attempt to clear the system policy; success is not claimed when shared intent
cannot be verified.

## Shared state and upgrade migration

Both targets use App Group `group.com.tyleryates.takeback`. The shared container
holds `takeback-native/state-v1.plist`, atomically replaced under the transaction
lock, with file protection until first user authentication. It contains:

- Existing selection key `takeback.ios.allowedApplications.v1`, with its unchanged
  encoded `FamilyActivitySelection` data.
- Existing intent key `takeback.ios.lockdownRequested.v1`.
- Migration marker, pending-clear recovery flag, and token-free widget snapshot
  signature used to avoid notification/reload loops.

This is an atomic shared file, not App Group UserDefaults. There is no second token
store, token export to Dart, or prototype-key migration. Setup/onboarding/prototype
preferences remain where they were.

Runner imports legacy native selection and intent together **before reconciliation**.
It validates the selection, commits a migration marker, verifies the written bytes,
then removes only the old native keys. A valid empty selection remains valid saved
data but cannot activate restrictions. Corrupt legacy selections are discarded
under existing Phase 2 rules. Failed writes retain the legacy data. A completed
shared migration always wins, including after interrupted legacy deletion; it
cannot resurrect a selection subsequently cleared for revocation. A corrupt shared
file produces recovery rather than silently reimporting old data.

The widget cannot access Runner's private preferences. After upgrading, **open
Unbound once before using the widget** so Runner can migrate. A migration-pending
widget does not interpret the absent shared state as an orphan policy and clear it.

## Synchronization and timing

Snapshots and every intent reconcile native state. Changes in either process send
a payload-free Darwin notification and request `WidgetCenter` timeline reloads.
An active Runner rereads native state and emits `setupChanged`; normal scene
activation also covers missed notifications. Selection changes trigger reloads.

The widget requests a refresh approximately every 30 minutes. As agreed, it keeps
its last verified presentation until WidgetKit grants a refresh; every tap performs
fresh validation. Revocation is reflected when a running observer, timeline update,
intent, or app activation detects it. **Immediate revocation display while both
processes are suspended is not guaranteed.**

## Signing setup before iPhone testing

The source adds Family Controls and App Groups entitlements to the extension and
App Groups to Runner while retaining Runner's existing Family Controls entitlement
and team `73VCXU624N`. No Developer Portal changes were made by this implementation.
Unsigned builds do not verify provisioning.

1. In Apple Developer Certificates, Identifiers & Profiles, register App Group
   `group.com.tyleryates.takeback` for the existing team.
2. Assign that group to the existing `com.tyleryates.takeback` App ID.
3. Register explicit App ID `com.tyleryates.takeback.UnboundWidget`, enable Family
   Controls and App Groups, and assign the same group.
4. Open `ios/Runner.xcworkspace`. Confirm both Runner and UnboundWidgetExtension
   use the existing team and automatic signing. Refresh/regenerate their development
   provisioning profiles to include the configured capabilities. Do not delete the
   existing app or change its bundle ID to resolve signing.
5. For distribution, obtain Family Controls approval for the extension identifier
   as required by Apple and regenerate the relevant distribution profiles. Runner's
   existing approval/profile does not establish extension approval.

No extra WidgetKit/App Intents entitlement, shielding extension, background mode,
or weakened Family Controls capability is added.

## Automated validation

Completed September 22, 2026 with the installed Flutter 3.47.5 / Xcode 27 toolchain:

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub` | All 19 passed |
| Runner native tests on iOS 27 simulator | All 35 passed, including containing-app intent publication and non-opening execution configuration |
| `flutter build ios --simulator --no-pub` | Passed; widget embedded |
| Standalone UnboundWidgetExtension simulator build | Passed; no Flutter linkage |
| Existing `integration_test/phase_one_test.dart` simulator smoke test | Passed |
| `flutter build ios --no-codesign --no-pub` | Passed; device release includes widget |
| Simulator and device built manifests | Runner 16.0, widget 17.0; expected bundle IDs and matching versions |
| Both targets, all configurations | Existing signing team; correct Family Controls and shared App Group entitlements |
| Built App Intent metadata | Runner and widget both publish `SetLockdownIntent` with `openAppWhenRun: false`, background mode, and WidgetKit-extension execution target |
| Preservation review | Existing Runner build settings, SwiftPM references, scheme/pre-action, UIScene, native picker UI, Dart dependencies, prototype service and preference keys unchanged |
| `git diff --check` | Passed |

Flutter iOS builds and the smoke test used `FLUTTER_SWIFT_PACKAGE_MANAGER=true`.
The retained CocoaPods scaffolding emits Flutter's optional removal notice; it was
not removed or otherwise migrated in this phase.

Logs are in `/tmp/unbound-phase4b/`: `flutter-tests.log`, `native-tests.log`,
`simulator-build.log`, `widget-build.log`, `smoke-test.log`, and `device-build.log`.
The final native test bundle is `RunnerTests-recovery.xcresult`.

Native tests cover atomic migration, preserved selection bytes and native intent,
interrupted commit/deletion, failed writes, corrupt data, idempotence, non-resurrection
of deleted selections, and prototype-key independence. They also cover shared
app/widget state, process-lock contention, setup guards, pending-clear recovery,
failed activation, revocation, direct recovery, and token-free notifications.
Existing Phase 2/3 tests continue to cover selection persistence and policy safety.
Native SwiftUI tests render the exact widget control content for all four states.
Policy tests use inert identifiers and fake adapters, not fabricated Apple tokens.

Final source review confirmed that the intent delegates to the same coordinator
and policy as Runner, validates authorization/allowlists, uses explicit enable/disable
requests, and returns success only after readback. Both synchronization directions
are present. WidgetKit retains the last timeline presentation when refresh is delayed;
uncertain entries expose direct UNLOCK. Flutter tests preserve the reflection prompt,
header-arrow removal, open/closed padlock states, and immediate error recovery.

**Not automatically validated:** Developer Portal registration and profile contents,
signed device installation, real populated-token migration on an upgraded iPhone,
interactive Home Screen actions while Runner is terminated, reboot behavior, and
visible shield enforcement. Source entitlement checks and unsigned builds do not
establish these results. Physical widget validation is still pending.

## Physical iPhone checklist — still required

Before testing, finish the signing steps above and upgrade the existing Phase 4A
installation without uninstalling it. Use an iPhone on iOS 17 or newer.

1. Open Unbound once; confirm the existing populated allowed-app selection survived
   migration and any pre-existing locked state reconciles accurately.
2. Add the small Unbound widget to the Home Screen.
3. While unlocked, confirm the widget shows an open padlock and LOCK IN.
4. Tap widget LOCK IN and confirm Unbound/Flutter does not open.
5. Open a non-allowed third-party app and confirm it is shielded.
6. Confirm an allowed app remains accessible, and Unbound itself is accessible.
7. Confirm the widget changes to a closed padlock and UNLOCK after verification.
8. Open Unbound and confirm its closed padlock / UNLOCK control reflects locked state.
9. LOCK/UNLOCK from the app and verify the widget follows actual state changes.
10. LOCK again from the widget, without opening the app.
11. UNLOCK from the widget; confirm restrictions clear immediately, with no reflection
    prompt or Flutter launch. Previously shielded apps must open normally.
12. Confirm in-app UNLOCK still presents the reflection prompt; Stay Locked In must
    leave restrictions and the widget state unchanged.
13. Force-close Unbound while locked and verify the widget remains usable for direct
    unlock and subsequent locking. Reopen the app and check accurate state.
14. Revoke authorization while locked. Verify safe clearing/selection invalidation at
    reconciliation, allowing for OS-controlled widget refresh timing; then reauthorize
    and reselect apps as needed.
15. Exercise an uncertain/error state and confirm the neutral widget exposes direct
    UNLOCK recovery, without claiming verified success when clearing fails.
16. Reboot, unlock the device, and relaunch; verify app/widget state reconciliation
    and that saved selections remain intact.
17. Attempt widget LOCK IN while the app's picker is open; it must reject activation.
    Direct widget UNLOCK remains available. Complete/cancel the picker and retry.
18. Check fresh setup, empty/oversized allowlists, rapid/repeated taps, and stale
    widget actions. None may bypass validation, falsely claim locking, or silently
    switch to prototype behavior.

### Focused retest after the interaction repair

1. Install the repaired build. If taps still use cached behavior, remove and re-add
   the widget once so iOS reloads its App Intent registration.
2. From the configured unlocked widget, tap LOCK IN. Confirm the Home Screen remains
   visible, restrictions apply, and the widget reaches verified UNLOCK state.
3. Tap widget UNLOCK. Confirm the Home Screen remains visible, restrictions clear
   immediately, and no in-app reflection prompt appears.
4. Exercise the checking/error presentation and confirm its direct UNLOCK recovery
   also stays on the Home Screen.
5. Exercise the setup/migration presentation and confirm **Open Unbound** remains the
   only widget state that intentionally launches the containing app.
6. Open Unbound and confirm in-app UNLOCK still presents the Phase 4A reflection
   prompt.

## Changed files and scope

The post-commit interaction repair changed only the Xcode project target membership,
`SetLockdownIntent.swift`, its focused native test, and this handoff document.

The complete working-tree inventory below includes the existing uncommitted
Phase 4A changes; those were preserved, not reset or reimplemented.

**Added for Phase 4B (12 files):**

- `docs/phase-4b-handoff.md`
- `ios/Runner.xcodeproj/xcshareddata/xcschemes/UnboundWidgetExtension.xcscheme`
- `ios/RunnerTests/WidgetAndSharedStateTests.swift`
- `ios/Shared/NativePersistence.swift`
- `ios/Shared/NativeRestrictionCoordinator.swift`
- `ios/Shared/WidgetControlLabel.swift`
- `ios/Shared/WidgetRestrictionState.swift`
- `ios/UnboundWidget/Info.plist`
- `ios/UnboundWidget/SetLockdownIntent.swift`
- `ios/UnboundWidget/UnboundWidget.entitlements`
- `ios/UnboundWidget/UnboundWidget.swift`
- `ios/UnboundWidget/Widget.xcconfig`

**Updated during Phase 4B (11 files, some already changed in Phase 4A):**

- `README.md`
- `docs/phase-4a-handoff.md`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner/AllowedAppsStore.swift`
- `ios/Runner/FamilyControlsBridge.swift`
- `ios/Runner/Runner.entitlements`
- `ios/Runner/TakeBackRestrictionStore.swift`
- `lib/screens/main_screen.dart`
- `lib/widgets/brand.dart`
- `test/ios_restrictions_test.dart`
- `test/widget_test.dart`

**Inherited Phase 4A changes, otherwise untouched in Phase 4B (15 files):**

- `android/app/src/main/AndroidManifest.xml`
- `docs/phase-3-handoff.md`
- `integration_test/phase_one_test.dart`
- `ios/Runner/Info.plist`
- `lib/app.dart`
- `lib/models/restriction_status.dart`
- `lib/screens/allowed_apps_screen.dart`
- `lib/screens/disclaimer_screen.dart`
- `lib/screens/permission_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/welcome_screen.dart`
- `lib/services/ios_app_restriction_service.dart`
- `lib/state/takeback_controller.dart`
- `lib/widgets/notices.dart`
- `test/ios_setup_test.dart`

New target/product: `UnboundWidgetExtension` / `UnboundWidgetExtension.appex`.
Runner remains `Runner.app`, now embedding that extension. Tests were added to the
existing RunnerTests target; no new Flutter package, shared framework, or other
extension target was introduced.

No NFC, user-created Shortcuts, schedules, focus timers, streaks, analytics, accounts,
subscriptions, Live Activities, Lock Screen widgets, Control Center controls,
Action Button integration, Android widgets/blocking, App Store metadata, bundle-ID
renaming, or icon redesign. Stopped at Phase 4B.
