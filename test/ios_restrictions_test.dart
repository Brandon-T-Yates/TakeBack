import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeback/app.dart';
import 'package:takeback/models/restriction_status.dart';
import 'package:takeback/services/ios_app_restriction_service.dart';
import 'package:takeback/services/local_app_restriction_service.dart';
import 'package:takeback/services/preferences_store.dart';
import 'package:takeback/state/takeback_controller.dart';

import 'support.dart';
import 'widget_test.dart' show tapText;

const channel = MethodChannel('takeback/family_controls');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Object> state;
  late List<String> calls;
  late MemoryPreferences memory;
  PlatformException? operationError;
  bool failRead = false;

  setUp(() {
    state = {
      'available': true,
      'authorization': 'authorized',
      'hasSavedSelection': true,
      'applicationCount': 2,
      'selectionUsable': true,
      'restrictionMode': 'native',
      'lockdownState': 'unlocked',
    };
    calls = [];
    memory = MemoryPreferences()
      ..values.addAll({
        PreferencesStore.disclaimerKey: true,
        PreferencesStore.onboardingKey: true,
        PreferencesStore.prototypeLockKey: true,
        PreferencesStore.firstNativeLockSafetyAcknowledgedKey: true,
      });
    operationError = null;
    failRead = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'getSetupState':
              if (failRead) throw PlatformException(code: 'read_failed');
              return state;
            case 'requestAuthorization':
              state['authorization'] = 'authorized';
              return null;
            case 'isLockdownEnabled':
              if (['checking', 'error'].contains(state['lockdownState'])) {
                throw PlatformException(code: 'restriction_state_unknown');
              }
              return state['lockdownState'] == 'locked';
            case 'enableLockdown':
            case 'disableLockdown':
            case 'toggleLockdown':
              if (operationError != null) throw operationError!;
              state['lockdownState'] =
                  call.method == 'disableLockdown' ||
                      (call.method == 'toggleLockdown' &&
                          state['lockdownState'] == 'locked')
                  ? 'unlocked'
                  : 'locked';
              return state;
            default:
              throw MissingPluginException();
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  IosAppRestrictionService service() => IosAppRestrictionService(
    LocalAppRestrictionService(PreferencesStore(preferences: memory)),
  );
  TakeBackController controller() => TakeBackController(
    preferences: PreferencesStore(preferences: memory),
    restrictions: service(),
  );

  Future<void> sendSnapshot() async {
    final delivered = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('setupChanged', state),
          ),
          (_) => delivered.complete(),
        );
    await delivered.future;
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'native operations and restored state never read the prototype lock',
    () async {
      final first = service();
      expect(await first.isLockdownEnabled(), isFalse);
      expect(first.mode, RestrictionMode.native);
      await first.enableLockdown();
      expect(await first.isLockdownEnabled(), isTrue);
      first.dispose();
      final resumed = service();
      expect(await resumed.isLockdownEnabled(), isTrue);
      await resumed.disableLockdown();
      await resumed.disableLockdown();
      expect(await resumed.isLockdownEnabled(), isFalse);
      await resumed.toggleLockdown();
      expect(await resumed.isLockdownEnabled(), isTrue);
      expect(memory.values[PreferencesStore.prototypeLockKey], isTrue);
      expect(
        calls,
        containsAll(['enableLockdown', 'disableLockdown', 'toggleLockdown']),
      );
      resumed.dispose();
    },
  );

  test('simulator explicitly uses the original prototype service', () async {
    state.addAll({
      'available': false,
      'authorization': 'unavailable',
      'restrictionMode': 'prototype',
    });
    final api = service();
    expect(await api.isLockdownEnabled(), isTrue);
    expect(api.mode, RestrictionMode.prototype);
    await api.disableLockdown();
    expect(memory.values[PreferencesStore.prototypeLockKey], isFalse);
    await api.enableLockdown();
    await api.toggleLockdown();
    expect(await api.isLockdownEnabled(), isFalse);
    expect(calls.every((method) => method == 'getSetupState'), isTrue);
    api.dispose();
  });

  test(
    'denial, unknown metadata, and channel errors never select prototype fallback',
    () async {
      state.addAll({
        'authorization': 'denied',
        'hasSavedSelection': false,
        'selectionUsable': false,
      });
      final api = service();
      await api.getSetupState();
      expect(api.mode, RestrictionMode.native);
      operationError = PlatformException(code: 'authorization_required');
      await expectLater(
        api.enableLockdown(),
        throwsA(isA<PlatformException>()),
      );
      state.remove('restrictionMode');
      expect((await api.getSetupState()).lockdownState, LockdownState.error);
      expect(api.mode, RestrictionMode.native);
      failRead = true;
      await expectLater(api.getSetupState(), throwsA(isA<PlatformException>()));
      expect(api.mode, RestrictionMode.native);
      expect(memory.values[PreferencesStore.prototypeLockKey], isTrue);
      api.dispose();
    },
  );

  test('unresolved native boolean queries return errors', () async {
    final api = service();
    for (final value in ['checking', 'error']) {
      state['lockdownState'] = value;
      await expectLater(
        api.isLockdownEnabled(),
        throwsA(isA<PlatformException>()),
      );
    }
    api.dispose();
  });

  test(
    'foreground refresh replaces stale lock state; errors keep unlock recovery',
    () async {
      final c = controller();
      state['lockdownState'] = 'locked';
      await c.initialize();
      expect(c.locked, isTrue);
      state['lockdownState'] = 'unlocked';
      await c.refreshSetup();
      expect(c.locked, isFalse);
      failRead = true;
      await c.refreshSetup();
      expect(c.lockdownState, LockdownState.error);
      expect(c.needsUnlock, isTrue);
      expect(c.ready, isTrue);
      failRead = false;
      await c.toggleLockdown();
      expect(calls, contains('disableLockdown'));
      expect(c.lockdownState, LockdownState.unlocked);
      c.dispose();
    },
  );

  testWidgets('native lock UI, picker guard, and revocation notification', (
    tester,
  ) async {
    final c = controller();
    await tester.pumpWidget(TakeBackApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('LOCK IN'), findsOneWidget);
    expect(find.text('Prototype mode — no apps are blocked'), findsNothing);
    await tapText(tester, 'LOCK IN');
    expect(find.text('UNLOCK'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(calls.where((call) => call == 'toggleLockdown'), hasLength(1));
    expect(find.text('Ready to unlock?'), findsNothing);
    expect(find.text('LOCKED IN'), findsNothing);
    expect(find.text('UNLOCKED'), findsNothing);
    await tapText(tester, 'Edit Allowed Apps');
    expect(find.text('Unlock before editing apps'), findsOneWidget);
    await tester.runAsync(c.chooseAllowedApps);
    expect(calls, isNot(contains('selectAllowedApps')));
    await tapText(tester, 'Done');
    state.addAll({
      'authorization': 'denied',
      'hasSavedSelection': false,
      'selectionUsable': false,
      'lockdownState': 'unlocked',
    });
    await tester.runAsync(sendSnapshot);
    await tester.pumpAndSettle();
    expect(find.text('AUTHORIZE'), findsOneWidget);
    expect(find.text('Authorize to lock in.'), findsOneWidget);
    await tapText(tester, 'AUTHORIZE');
    expect(find.text('CHOOSE APPS'), findsOneWidget);
    await tapText(tester, 'CHOOSE APPS');
    expect(find.text('Allowed Apps'), findsOneWidget);
    expect(find.text('Choose Allowed Apps'), findsOneWidget);
    expect(find.text('LOCKED IN'), findsNothing);
    expect(c.mode, RestrictionMode.native);
    expect(memory.values[PreferencesStore.prototypeLockKey], isTrue);
  });

  testWidgets('invalid saved count routes Main to allowlist recovery', (
    tester,
  ) async {
    state.addAll({'applicationCount': 51, 'selectionUsable': true});
    final c = controller();
    await tester.pumpWidget(TakeBackApp(controller: c));
    await tester.pumpAndSettle();

    expect(c.setup.hasSavedSelection, isTrue);
    expect(c.allowlistReady, isFalse);
    expect(find.text('CHOOSE APPS'), findsOneWidget);
    expect(find.text('Choose 1–50 apps to lock in.'), findsOneWidget);
    await tapText(tester, 'CHOOSE APPS');
    expect(find.text('51 apps saved — choose 1–50'), findsOneWidget);
    expect(calls, isNot(contains('toggleLockdown')));
  });

  testWidgets(
    'first native lock notice cancels safely, confirms once, and stays dismissed',
    (tester) async {
      memory.values.remove(
        PreferencesStore.firstNativeLockSafetyAcknowledgedKey,
      );
      final c = controller();
      await tester.pumpWidget(TakeBackApp(controller: c));
      await tester.pumpAndSettle();

      await tapText(tester, 'LOCK IN');
      expect(find.text('Before you lock in'), findsOneWidget);
      expect(
        find.textContaining('remove Unbound, unlock first'),
        findsOneWidget,
      );
      expect(calls, isNot(contains('toggleLockdown')));

      await tapText(tester, 'Cancel');
      expect(find.text('Before you lock in'), findsNothing);
      expect(c.locked, isFalse);
      expect(calls, isNot(contains('toggleLockdown')));
      expect(
        memory.values[PreferencesStore.firstNativeLockSafetyAcknowledgedKey],
        isNull,
      );

      await tapText(tester, 'LOCK IN');
      await tapText(tester, 'Got it — Lock In');
      expect(c.locked, isTrue);
      expect(calls.where((call) => call == 'toggleLockdown'), hasLength(1));
      expect(
        memory.values[PreferencesStore.firstNativeLockSafetyAcknowledgedKey],
        isTrue,
      );

      await tapText(tester, 'UNLOCK');
      await tapText(tester, 'Unlock');
      await tapText(tester, 'LOCK IN');
      expect(find.text('Before you lock in'), findsNothing);
      expect(c.locked, isTrue);
      expect(calls.where((call) => call == 'toggleLockdown'), hasLength(2));
    },
  );

  testWidgets(
    'checking at startup keeps main screen and explicit unlock available',
    (tester) async {
      state.addAll({
        'authorization': 'notDetermined',
        'lockdownState': 'checking',
      });
      final c = controller();
      await tester.pumpWidget(TakeBackApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Checking Screen Time authorization. You can still unlock.'),
        findsOneWidget,
      );
      expect(find.text('LOCKED IN'), findsNothing);
      expect(find.text('UNLOCKED'), findsNothing);
      expect(find.byIcon(Icons.help), findsOneWidget);
      await tapText(tester, 'UNLOCK');
      expect(calls, contains('disableLockdown'));
      expect(find.text('Ready to unlock?'), findsNothing);
      expect(calls, isNot(contains('enableLockdown')));
      expect(find.text('AUTHORIZE'), findsOneWidget);
    },
  );

  testWidgets(
    'failed activation and failed clearing never show false success',
    (tester) async {
      final c = controller();
      await tester.pumpWidget(TakeBackApp(controller: c));
      await tester.pumpAndSettle();
      operationError = PlatformException(
        code: 'empty_selection',
        message: 'Choose at least one allowed app before locking in.',
      );
      await tapText(tester, 'LOCK IN');
      expect(
        find.text('Choose at least one allowed app before locking in.'),
        findsOneWidget,
      );
      expect(find.text('LOCKED IN'), findsNothing);
      state['lockdownState'] = 'error';
      operationError = PlatformException(
        code: 'restriction_clear_failed',
        message: 'Tap UNLOCK to retry.',
      );
      await tester.runAsync(sendSnapshot);
      await tester.pumpAndSettle();
      await tapText(tester, 'UNLOCK');
      expect(c.lockdownState, LockdownState.error);
      expect(find.text('UNLOCKED'), findsNothing);
      expect(find.text('UNLOCK'), findsOneWidget);
      expect(find.text('Ready to unlock?'), findsNothing);
      operationError = null;
      await tapText(tester, 'UNLOCK');
      expect(c.lockdownState, LockdownState.unlocked);
      expect(calls.where((call) => call == 'disableLockdown'), hasLength(2));
    },
  );

  testWidgets('initial channel failure still renders unlock recovery', (
    tester,
  ) async {
    failRead = true;
    final c = controller();
    await tester.pumpWidget(TakeBackApp(controller: c));
    await tester.pumpAndSettle();
    expect(c.lockdownState, LockdownState.error);
    expect(find.text('UNLOCK'), findsOneWidget);
    expect(find.text('Prototype mode — no apps are blocked'), findsNothing);
  });

  testWidgets(
    'native unlock reflects first; stay and dismissal preserve policy',
    (tester) async {
      state['lockdownState'] = 'locked';
      final c = controller();
      await tester.pumpWidget(TakeBackApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('LOCKED IN'), findsNothing);
      expect(find.text('UNLOCKED'), findsNothing);
      expect(find.text('Unbound'), findsOneWidget);
      await tapText(tester, 'UNLOCK');
      expect(find.text('Ready to unlock?'), findsOneWidget);
      expect(
        find.text(
          'If you’re done focusing or need something outside your allowed apps, go for it. Otherwise, you can stay locked in.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Stay Locked In'),
        findsOneWidget,
      );
      expect(calls, isNot(contains('disableLockdown')));
      await tapText(tester, 'Stay Locked In');
      expect(find.text('Ready to unlock?'), findsNothing);
      expect(c.locked, isTrue);
      expect(calls, isNot(contains('disableLockdown')));
      await tapText(tester, 'UNLOCK');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(c.locked, isTrue);
      expect(calls, isNot(contains('disableLockdown')));
      await tapText(tester, 'UNLOCK');
      await tapText(tester, 'Unlock');
      expect(calls.where((call) => call == 'disableLockdown'), hasLength(1));
      expect(calls, isNot(contains('toggleLockdown')));
      expect(c.locked, isFalse);
      expect(find.text('LOCK IN'), findsOneWidget);
      expect(find.text('Ready to unlock?'), findsNothing);
    },
  );

  testWidgets(
    'confirmation after state changes only clears and never re-locks',
    (tester) async {
      state['lockdownState'] = 'locked';
      final c = controller();
      await tester.pumpWidget(TakeBackApp(controller: c));
      await tester.pumpAndSettle();
      await tapText(tester, 'UNLOCK');
      state['lockdownState'] = 'unlocked';
      await tester.runAsync(sendSnapshot);
      await tester.pumpAndSettle();
      await tapText(tester, 'Unlock');
      expect(calls.where((call) => call == 'disableLockdown'), hasLength(1));
      expect(calls, isNot(contains('toggleLockdown')));
      expect(c.locked, isFalse);
    },
  );
}
