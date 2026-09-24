import 'dart:async';
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
  late String pickerResult;
  PlatformException? authorizationError;

  setUp(() {
    state = {
      'available': true,
      'authorization': 'notDetermined',
      'hasSavedSelection': false,
      'applicationCount': 0,
      'selectionUsable': false,
      'restrictionMode': 'native',
      'lockdownState': 'unlocked',
    };
    pickerResult = 'selected';
    authorizationError = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getSetupState':
              return state;
            case 'requestAuthorization':
              if (authorizationError != null) throw authorizationError!;
              state['authorization'] = 'authorized';
              return null;
            case 'selectAllowedApps':
              if (pickerResult == 'selected') {
                state.addAll({
                  'hasSavedSelection': true,
                  'applicationCount': 2,
                  'selectionUsable': true,
                });
              }
              return pickerResult;
            case 'toggleLockdown':
              throw PlatformException(
                code: 'authorization_required',
                message: 'Authorize Screen Time before locking in.',
              );
            default:
              throw MissingPluginException();
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  TakeBackController controllerFor(MemoryPreferences memory) {
    final store = PreferencesStore(preferences: memory);
    return TakeBackController(
      preferences: store,
      restrictions: IosAppRestrictionService(LocalAppRestrictionService(store)),
    );
  }

  test('authorization parsing fails closed for revoked and unknown status', () {
    for (final status in [
      'denied',
      'notDetermined',
      'unavailable',
      'unexpected',
    ]) {
      final parsed = RestrictionSetupState.fromNative({
        ...state,
        'authorization': status,
        'hasSavedSelection': true,
        'applicationCount': 9,
        'selectionUsable': true,
      });
      expect(parsed.selectionUsable, isFalse);
      expect(parsed.applicationCount, 0);
      expect(parsed.hasSavedSelection, isFalse);
    }
  });

  test('allowlist readiness requires 1–50 saved apps', () {
    for (final count in [0, 1, 50, 51]) {
      final parsed = RestrictionSetupState.fromNative({
        ...state,
        'authorization': 'authorized',
        'hasSavedSelection': true,
        'applicationCount': count,
        'selectionUsable': true,
      });
      expect(parsed.hasSavedSelection, isTrue, reason: 'count $count');
      expect(parsed.applicationCount, count, reason: 'count $count');
      expect(
        parsed.selectionUsable,
        count >= 1 && count <= 50,
        reason: 'count $count',
      );
    }
  });

  test(
    'cancelled authorization never activates native or prototype restrictions',
    () async {
      final memory = MemoryPreferences()
        ..values.addAll({
          PreferencesStore.disclaimerKey: true,
          PreferencesStore.onboardingKey: true,
          PreferencesStore.prototypeLockKey: true,
        });
      final controller = controllerFor(memory);
      await controller.initialize();
      authorizationError = PlatformException(
        code: 'authorization_cancelled',
        message: 'Authorization was cancelled.',
      );
      await controller.authorize();
      expect(controller.error, contains('cancelled'));
      expect(controller.authorization, AuthorizationStatus.notDetermined);
      expect(controller.locked, isFalse);
      expect(controller.mode, RestrictionMode.native);
      expect(memory.values[PreferencesStore.prototypeLockKey], isTrue);
      await controller.continueSetup();
      await controller.finishOnboarding();
      expect(controller.step, SetupStep.complete);
      controller.dispose();
    },
  );

  testWidgets('iOS authorization, picker outcomes, restore and revocation', (
    tester,
  ) async {
    final memory = MemoryPreferences()
      ..values[PreferencesStore.disclaimerKey] = true;
    final controller = controllerFor(memory);
    await tester.pumpWidget(TakeBackApp(controller: controller));
    await tester.pumpAndSettle();
    await tapText(tester, 'Authorize Screen Time');
    expect(find.text('Screen Time access is authorized.'), findsOneWidget);
    await tapText(tester, 'Continue');
    await tapText(tester, 'Choose Allowed Apps');
    expect(find.text('2 allowed apps saved'), findsOneWidget);
    pickerResult = 'cancelled';
    await tapText(tester, 'Choose Allowed Apps');
    expect(find.text('2 allowed apps saved'), findsOneWidget);
    expect(controller.selection, AppSelectionResult.cancelled);

    // Reload metadata from native storage rather than Flutter preferences.
    controller.setup = const RestrictionSetupState();
    await tester.runAsync(controller.refreshSetup);
    await tester.pumpAndSettle();
    expect(controller.setup.applicationCount, 2);
    expect(memory.values.containsKey('applicationTokens'), isFalse);

    // Simulate the native authorization-change notification while a route is open.
    state.addAll({
      'authorization': 'denied',
      'hasSavedSelection': false,
      'applicationCount': 0,
      'selectionUsable': false,
    });
    final delivered = Completer<void>();
    tester.binding.channelBuffers.push(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('setupChanged', state),
      ),
      (_) => delivered.complete(),
    );
    await tester.runAsync(() => delivered.future);
    await tester.pumpAndSettle();
    expect(find.text('No usable app selection saved'), findsOneWidget);
    expect(find.text('Authorize Screen Time'), findsOneWidget);
    expect(controller.setup.selectionUsable, isFalse);
    await tapText(tester, 'Continue to Unbound');
    expect(find.text('AUTHORIZE'), findsOneWidget);
    expect(find.text('Authorize to lock in.'), findsOneWidget);
    await tapText(tester, 'AUTHORIZE');
    expect(find.text('CHOOSE APPS'), findsOneWidget);
    await tapText(tester, 'CHOOSE APPS');
    expect(find.text('Screen Time access is authorized.'), findsOneWidget);
    pickerResult = 'selected';
    await tapText(tester, 'Choose Allowed Apps');
    expect(find.text('2 allowed apps saved'), findsOneWidget);
    await tapText(tester, 'Done');
    expect(find.text('LOCK IN'), findsOneWidget);
    expect(find.text('Prototype mode — no apps are blocked'), findsNothing);
    expect(controller.locked, isFalse);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
