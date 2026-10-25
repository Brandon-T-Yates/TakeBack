import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:takeback/app.dart';
import 'package:takeback/models/restriction_status.dart';
import 'package:takeback/services/android_app_restriction_service.dart';
import 'package:takeback/services/preferences_store.dart';
import 'package:takeback/state/takeback_controller.dart';

import 'support.dart';
import 'widget_test.dart' show tapText;

const channel = MethodChannel('unbound/android_restrictions');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Set<String> packages;
  late bool lock;
  late bool accessEnabled;
  late bool accessRunning;
  late bool accessInterrupted;
  late List<String> calls;
  late String pickerResult;
  Set<String>? pickerSaves;
  late MemoryPreferences memory;

  bool usable() => packages.isNotEmpty && packages.length <= 50;
  bool running() => accessEnabled && accessRunning;

  void lockIn() {
    accessInterrupted = false;
    lock = true;
  }

  /// Mirrors AndroidRestrictionsBridge.setupState().
  Map<String, Object> snapshot() {
    if (!usable()) lock = false;
    if (lock && !accessEnabled) {
      lock = false;
      accessInterrupted = true;
    }
    final enforcing = lock && usable() && running();
    return {
      'available': true,
      'authorization': 'authorized',
      'hasSavedSelection': packages.isNotEmpty,
      'applicationCount': packages.length,
      'selectionUsable': usable(),
      'restrictionMode': 'android',
      'accessibilityEnabled': accessEnabled,
      'accessibilityRunning': running(),
      'accessInterrupted': accessInterrupted,
      'enforcing': enforcing,
      'lockdownState': !lock
          ? 'unlocked'
          : enforcing
          ? 'locked'
          : 'error',
      if (lock && !enforcing)
        'restrictionMessage':
            'Android paused Unbound’s access, so apps aren’t being blocked. '
            'Tap UNLOCK, then LOCK IN to set it up again.',
    };
  }

  setUp(() {
    packages = {};
    lock = false;
    accessEnabled = false;
    accessRunning = false;
    accessInterrupted = false;
    calls = [];
    pickerResult = 'selected';
    pickerSaves = null;
    memory = MemoryPreferences()
      ..values.addAll({
        PreferencesStore.disclaimerKey: true,
        PreferencesStore.onboardingKey: true,
      });
    PackageInfo.setMockInitialValues(
      appName: 'Unbound',
      packageName: 'com.tyleryates.takeback',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'getSetupState':
              return snapshot();
            case 'selectAllowedApps':
              if (lock) {
                throw PlatformException(
                  code: 'unlock_required',
                  message: 'Unlock Unbound before changing your allowed apps.',
                );
              }
              if (pickerSaves case final saved?) packages = saved;
              return pickerResult;
            case 'getAllowedApps':
              return [
                for (final p in packages) {'packageName': p, 'label': 'App $p'},
              ];
            case 'openAccessibilitySettings':
              return true;
            case 'isLockdownEnabled':
              return lock;
            case 'enableLockdown':
            case 'toggleLockdown':
              if (call.method == 'toggleLockdown' && lock) {
                lock = false;
                return snapshot();
              }
              if (!usable()) {
                throw PlatformException(code: 'selection_required');
              }
              if (!running()) {
                throw PlatformException(code: 'accessibility_required');
              }
              lockIn();
              return snapshot();
            case 'disableLockdown':
              lock = false;
              return snapshot();
            default:
              throw MissingPluginException();
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  TakeBackController controller() => TakeBackController(
    preferences: PreferencesStore(preferences: memory),
    restrictions: AndroidAppRestrictionService(),
  );

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> sendSetupChanged() async {
    final delivered = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('setupChanged', snapshot()),
          ),
          (_) => delivered.complete(),
        );
    await delivered.future;
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> returnFromSettings(WidgetTester tester) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
  }

  void expectNoAndroidImplementationLabels() {
    expect(find.text('ENABLE ACCESS'), findsNothing);
    expect(find.text('SETUP READY'), findsNothing);
    expect(find.text('Turn On Accessibility Access'), findsNothing);
    expect(find.textContaining('Screen Time'), findsNothing);
  }

  group('parsing', () {
    test('existing iOS and prototype payloads parse exactly as before', () {
      final native = RestrictionSetupState.fromNative({
        'available': true,
        'authorization': 'authorized',
        'hasSavedSelection': true,
        'applicationCount': 3,
        'selectionUsable': true,
        'restrictionMode': 'native',
        'lockdownState': 'locked',
        'accessInterrupted': true,
      });
      expect(native.mode, RestrictionMode.native);
      expect(native.lockdownState, LockdownState.locked);
      expect(native.selectionUsable, isTrue);
      expect(native.enforcing, isFalse);
      expect(native.accessibilityEnabled, isFalse);
      expect(native.accessInterrupted, isFalse);

      final simulator = RestrictionSetupState.fromNative({
        'available': false,
        'restrictionMode': 'prototype',
        'lockdownState': 'unlocked',
      });
      expect(simulator.mode, RestrictionMode.prototype);

      final missing = RestrictionSetupState.fromNative({'available': true});
      expect(missing.mode, RestrictionMode.native);
      expect(missing.lockdownState, LockdownState.error);
    });

    test('Android setup is usable only with 1–50 saved apps', () {
      for (final count in [0, 1, 50, 51]) {
        packages = {for (var i = 0; i < count; i++) 'pkg.$i'};
        final parsed = RestrictionSetupState.fromNative(snapshot());
        expect(parsed.mode, RestrictionMode.android, reason: 'count $count');
        expect(parsed.applicationCount, count, reason: 'count $count');
        expect(
          parsed.selectionUsable,
          count >= 1 && count <= 50,
          reason: 'count $count',
        );
      }
    });

    test('a locked report without enforcement is never shown as locked', () {
      final parsed = RestrictionSetupState.fromNative({
        ...snapshot(),
        'hasSavedSelection': true,
        'applicationCount': 2,
        'selectionUsable': true,
        'lockdownState': 'locked',
        'enforcing': false,
      });
      expect(parsed.lockdownState, LockdownState.error);
      expect(parsed.enforcing, isFalse);
    });
  });

  group('controller', () {
    test('service maps selection results', () async {
      final service = AndroidAppRestrictionService();
      pickerSaves = {'com.a', 'com.b'};
      expect(await service.selectAllowedApps(), AppSelectionResult.selected);
      expect((await service.getSetupState()).applicationCount, 2);
      pickerResult = 'cancelled';
      expect(await service.selectAllowedApps(), AppSelectionResult.cancelled);
      service.dispose();
    });

    test(
      'valid allowlist with access off offers LOCK IN via disclosure',
      () async {
        packages = {'com.a'};
        final c = controller();
        await c.initialize();
        expect(c.canLockIn, isTrue);
        expect(c.androidLockInNeedsAccess, isTrue);
        // The native lock is never attempted without access.
        await c.toggleLockdown();
        expect(calls, isNot(contains('toggleLockdown')));
        expect(c.error, isNull);
        expect(c.locked, isFalse);
        c.dispose();
      },
    );

    test(
      'returning user with access on locks immediately; UNLOCK stops it',
      () async {
        packages = {'com.a', 'com.b'};
        accessEnabled = true;
        accessRunning = true;
        final c = controller();
        await c.initialize();
        expect(c.androidLockInNeedsAccess, isFalse);
        await c.toggleLockdown();
        expect(c.lockdownState, LockdownState.locked);
        expect(c.setup.enforcing, isTrue);
        expect(c.canEditAllowedApps, isFalse);

        await c.unlock();
        expect(c.lockdownState, LockdownState.unlocked);
        expect(c.setup.enforcing, isFalse);
        expect(c.canEditAllowedApps, isTrue);
        c.dispose();
      },
    );

    test(
      'turning access on in Settings never locks; the next LOCK IN does',
      () async {
        packages = {'com.a'};
        final c = controller();
        await c.initialize();
        await c.openAccessibilitySettings();
        expect(calls, contains('openAccessibilitySettings'));

        accessEnabled = true;
        accessRunning = true;
        await c.refreshSetup();
        await sendSetupChanged();
        expect(c.lockdownState, LockdownState.unlocked);
        expect(c.setup.enforcing, isFalse);
        expect(c.setup.accessibilityEnabled, isTrue);
        expect(c.androidLockInNeedsAccess, isFalse);
        expect(c.error, isNull);
        expect(lock, isFalse);
        expect(calls, isNot(contains('enableLockdown')));
        expect(calls, isNot(contains('toggleLockdown')));

        await c.toggleLockdown();
        expect(c.lockdownState, LockdownState.locked);
        expect(c.setup.enforcing, isTrue);
        expect(lock, isTrue);
        c.dispose();
      },
    );

    test('resume without enabling access stays unlocked, quietly', () async {
      packages = {'com.a'};
      final c = controller();
      await c.initialize();
      await c.openAccessibilitySettings();
      await c.refreshSetup();
      expect(c.lockdownState, LockdownState.unlocked);
      expect(c.androidLockInNeedsAccess, isTrue);
      expect(c.error, isNull);
      c.dispose();
    });

    test('a cold start with access on stays unlocked', () async {
      packages = {'com.a'};
      accessEnabled = true;
      accessRunning = true;
      final c = controller();
      await c.initialize();
      await c.refreshSetup();
      expect(c.lockdownState, LockdownState.unlocked);
      expect(calls, isNot(contains('enableLockdown')));
      expect(calls, isNot(contains('toggleLockdown')));
      c.dispose();
    });

    test(
      'access disabled while locked returns to LOCK IN with a hint',
      () async {
        packages = {'com.a'};
        accessEnabled = true;
        accessRunning = true;
        lock = true;
        final c = controller();
        await c.initialize();
        expect(c.lockdownState, LockdownState.locked);

        accessEnabled = false;
        accessRunning = false;
        await sendSetupChanged();
        expect(c.setup.enforcing, isFalse);
        expect(c.lockdownState, LockdownState.unlocked);
        expect(c.setup.accessInterrupted, isTrue);
        expect(c.androidLockInNeedsAccess, isTrue);
        expect(lock, isFalse);
        c.dispose();
      },
    );

    test('a failed setup read still offers UNLOCK', () async {
      final c = controller();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'disableLockdown') return null;
            throw PlatformException(code: 'read_failed');
          });
      await c.initialize();
      expect(c.lockdownState, LockdownState.error);
      expect(c.needsUnlock, isTrue);
      await c.unlock();
      expect(calls, contains('disableLockdown'));
      c.dispose();
    });
  });

  group('main screen', () {
    testWidgets('no apps shows CHOOSE APPS', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(TakeBackApp(controller: controller()));
      await tester.pumpAndSettle();
      expect(find.text('CHOOSE APPS'), findsOneWidget);
      expectNoAndroidImplementationLabels();
    });

    testWidgets(
      'LOCK IN with access off opens the disclosure; Not Now stays unlocked',
      (tester) async {
        phoneSize(tester);
        packages = {'com.a'};
        await tester.pumpWidget(TakeBackApp(controller: controller()));
        await tester.pumpAndSettle();
        expect(find.text('LOCK IN'), findsOneWidget);
        expect(
          find.text('A little intention goes a long way.'),
          findsOneWidget,
        );
        expectNoAndroidImplementationLabels();

        await tapText(tester, 'LOCK IN');
        expect(
          find.text('Android needs one permission to lock in'),
          findsOneWidget,
        );
        expect(find.text('Continue to Settings'), findsOneWidget);
        expect(
          find.textContaining('only uses the name of the app'),
          findsOneWidget,
        );
        expect(
          find.textContaining('find Unbound and turn it on'),
          findsOneWidget,
        );
        expect(calls, isNot(contains('openAccessibilitySettings')));
        expect(calls, isNot(contains('toggleLockdown')));

        await tapText(tester, 'Not Now');
        expect(find.text('LOCK IN'), findsOneWidget);
        expect(lock, isFalse);
        expect(
          find.textContaining('Tap LOCK IN to turn it back on'),
          findsNothing,
        );
        expectNoAndroidImplementationLabels();
        expect(tester.takeException(), isNull);

        // Access is still off, so the next LOCK IN explains again.
        await tapText(tester, 'LOCK IN');
        expect(
          find.text('Android needs one permission to lock in'),
          findsOneWidget,
        );
      },
    );

    testWidgets('system back from the disclosure stays unlocked', (
      tester,
    ) async {
      phoneSize(tester);
      packages = {'com.a'};
      await tester.pumpWidget(TakeBackApp(controller: controller()));
      await tester.pumpAndSettle();
      await tapText(tester, 'LOCK IN');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('LOCK IN'), findsOneWidget);
      expect(lock, isFalse);
    });

    testWidgets(
      'enabling access in Settings stays unlocked; second LOCK IN locks',
      (tester) async {
        phoneSize(tester);
        packages = {'com.a', 'com.b'};
        final c = controller();
        await tester.pumpWidget(TakeBackApp(controller: c));
        await tester.pumpAndSettle();

        await tapText(tester, 'LOCK IN');
        await tapText(tester, 'Continue to Settings');
        expect(calls, contains('openAccessibilitySettings'));
        // Back on the main screen, not the disclosure, when the user returns.
        expect(find.text('LOCK IN'), findsOneWidget);

        accessEnabled = true;
        accessRunning = true;
        await returnFromSettings(tester);
        expect(find.text('LOCK IN'), findsOneWidget);
        expect(find.text('UNLOCK'), findsNothing);
        expect(
          find.text('A little intention goes a long way.'),
          findsOneWidget,
        );
        expect(
          find.text('Android needs one permission to lock in'),
          findsNothing,
        );
        expect(c.lockdownState, LockdownState.unlocked);
        expect(c.setup.enforcing, isFalse);
        expect(c.setup.accessibilityEnabled, isTrue);
        expect(c.error, isNull);
        expect(lock, isFalse);
        expect(calls, isNot(contains('enableLockdown')));
        expect(calls, isNot(contains('toggleLockdown')));
        expectNoAndroidImplementationLabels();

        // Second LOCK IN: access is on, so it locks without the disclosure.
        await tapText(tester, 'LOCK IN');
        expect(
          find.text('Android needs one permission to lock in'),
          findsNothing,
        );
        expect(find.text('UNLOCK'), findsOneWidget);
        expect(
          find.text('Apps outside your allowed list return you Home.'),
          findsOneWidget,
        );
        expect(lock, isTrue);
        expect(c.setup.enforcing, isTrue);

        await tapText(tester, 'Edit Allowed Apps');
        expect(find.text('Unlock before editing apps'), findsOneWidget);
        await tapText(tester, 'Done');

        await tapText(tester, 'UNLOCK');
        await tapText(tester, 'Unlock');
        expect(find.text('LOCK IN'), findsOneWidget);
        expect(lock, isFalse);
        expectNoAndroidImplementationLabels();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('returning without enabling shows plain LOCK IN, no error', (
      tester,
    ) async {
      phoneSize(tester);
      packages = {'com.a'};
      await tester.pumpWidget(TakeBackApp(controller: controller()));
      await tester.pumpAndSettle();
      await tapText(tester, 'LOCK IN');
      await tapText(tester, 'Continue to Settings');
      await returnFromSettings(tester);
      expect(find.text('LOCK IN'), findsOneWidget);
      expect(
        find.text('Android needs one permission to lock in'),
        findsNothing,
      );
      expect(lock, isFalse);
      expect(find.textContaining('aren’t being blocked'), findsNothing);
      expectNoAndroidImplementationLabels();
    });

    testWidgets('access lost while locked shows LOCK IN and a short hint', (
      tester,
    ) async {
      phoneSize(tester);
      packages = {'com.a'};
      lock = true;
      accessEnabled = false;
      await tester.pumpWidget(TakeBackApp(controller: controller()));
      await tester.pumpAndSettle();
      expect(find.text('LOCK IN'), findsOneWidget);
      expect(find.text('UNLOCK'), findsNothing);
      expect(
        find.text('Android access is off. Tap LOCK IN to turn it back on.'),
        findsOneWidget,
      );
      expect(
        find.text('Android needs one permission to lock in'),
        findsNothing,
      );
      expectNoAndroidImplementationLabels();

      await tapText(tester, 'LOCK IN');
      expect(
        find.text('Android needs one permission to lock in'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings explains Android enforcement without Screen Time', (
      tester,
    ) async {
      phoneSize(tester);
      packages = {'com.a'};
      accessEnabled = true;
      accessRunning = true;
      await tester.pumpWidget(TakeBackApp(controller: controller()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('to see which app is opening'),
        findsOneWidget,
      );
      expect(find.text('Android access is on.'), findsOneWidget);
      expect(find.textContaining('only while'), findsNothing);
      expect(find.textContaining('Screen Time'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('manifest', () {
    test('main and allowed-apps activities are portrait-only', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      for (final name in ['.MainActivity', '.AllowedAppsActivity']) {
        final activity = RegExp(
          '<activity[^>]*android:name="${RegExp.escape(name)}"[^>]*>',
        ).firstMatch(manifest);
        expect(activity, isNotNull, reason: name);
        expect(
          activity!.group(0),
          contains('android:screenOrientation="portrait"'),
          reason: name,
        );
      }
    });
  });
}
