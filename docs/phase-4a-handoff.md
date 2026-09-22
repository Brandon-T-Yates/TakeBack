# Phase 4A handoff: Unbound branding and interaction polish

Phase 3 was reported physically validated on an iPhone by the user on September
22, 2026: authorization, app selection, real shielding, allowed-app access,
reliable unlocking, and accurate restriction state after relaunch. Phase 4A keeps
that native behavior intact. The user subsequently reported Phase 4A physically validated on September 22, 2026.
This handoff preserves the Phase 4A baseline; see the [Phase 4B handoff](phase-4b-handoff.md)
for the subsequent interactive widget and padlock changes.

## Visible changes

- Visible product branding is **Unbound**, including onboarding, settings,
  disclaimers, error messages, Flutter's application title, the iOS display/bundle
  name, and the Android launcher label.
- **Take back your time.** appears on Welcome and Settings. The main screen retains
  “Make room for what matters.” and its existing palette, typography, and large control.
- The main-screen status pill and its spacing are removed without a replacement.
  The existing checking/error explanation and recovery control remain available.
- LOCK IN is immediate. Confirmed native UNLOCK presents “Ready to unlock?” with:
  “If you’re done focusing or need something outside your allowed apps, go for it.
  Otherwise, you can stay locked in.”
- **Stay Locked In** is the prominent action. It, back navigation, and dismissal
  leave restrictions unchanged. **Unlock** calls the existing native disable
  operation once, then refreshes the snapshot. Confirmation always clears instead
  of toggling, even if native state changes while the dialog is open.
- Checking/error recovery and prototype unlocking bypass the prompt.

## Preservation and naming audit

`com.tyleryates.takeback`, all preferences/token/intent keys, MethodChannel and
plugin names, class/service names, and the named ManagedSettings store are unchanged.
There is no data migration. The native Swift diff changes only visible messages.
Entitlements, signing, UIScene, SwiftPM, iOS 16.0 minimum, authorization, selection
persistence, and shielding rules are unchanged.

No intentional TakeBack branding remains in app-controlled user-visible text.
Technical identifiers and historical Phase 2/3 documentation retain the old name.
System-controlled cached labels were not checked on a physical device in this run.
The app icon is unchanged.

## Validation

Completed September 22, 2026:

- `flutter analyze`: no issues.
- `flutter test --no-pub`: all 19 tests passed, including branding, absence of the
  pill, immediate locking, reflection dismissal, exactly-once confirmation,
  state changes during confirmation, and direct checking/error recovery.
- Runner native tests on iOS 27: all 19 passed, including Phase 2 persistence and
  Phase 3 policy/reconciliation coverage. Results: `/tmp/unbound-phase4a/RunnerTests.xcresult`.
- iOS simulator build: passed.
- Unsigned iOS physical-device release build: passed.
- Existing simulator onboarding/persistence smoke test: passed after updating its
  visible branding and button assertions.
- Built simulator/device manifests: Unbound display/bundle name,
  `com.tyleryates.takeback` identifier, and iOS 16.0 minimum.
- `git diff --check` and preservation/naming audits: passed.

Builds and the simulator smoke test used `FLUTTER_SWIFT_PACKAGE_MANAGER=true`.

## Changed files

- Visible platform labels: `ios/Runner/Info.plist`,
  `android/app/src/main/AndroidManifest.xml`.
- Native messages only: `ios/Runner/FamilyControlsBridge.swift`,
  `ios/Runner/TakeBackRestrictionStore.swift`.
- Flutter branding/messages: `lib/app.dart`, `lib/widgets/brand.dart`,
  `lib/widgets/notices.dart`, `lib/models/restriction_status.dart`,
  `lib/services/ios_app_restriction_service.dart`,
  `lib/screens/welcome_screen.dart`, `lib/screens/disclaimer_screen.dart`,
  `lib/screens/permission_screen.dart`, `lib/screens/allowed_apps_screen.dart`,
  `lib/screens/settings_screen.dart`.
- Interaction: `lib/screens/main_screen.dart`, `lib/state/takeback_controller.dart`.
- Tests: `test/widget_test.dart`, `test/ios_setup_test.dart`,
  `test/ios_restrictions_test.dart`, `integration_test/phase_one_test.dart`.
- Documentation: `README.md`, `docs/phase-3-handoff.md`, `docs/phase-4a-handoff.md`.

Stopped at Phase 4A. No widgets, App Intents, NFC, Shortcuts, Android blocking,
timers, schedules, streaks, analytics, accounts, sync, subscriptions, new restriction
behavior, icon redesign, App Store metadata, or bundle-ID changes were added.
