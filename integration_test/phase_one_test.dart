import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takeback/app.dart';
import 'package:takeback/services/local_app_restriction_service.dart';
import 'package:takeback/services/preferences_store.dart';
import 'package:takeback/state/takeback_controller.dart';

TakeBackApp freshApp() {
  final store = PreferencesStore();
  return TakeBackApp(
    controller: TakeBackController(
      preferences: store,
      restrictions: LocalAppRestrictionService(store),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 1 flow with real device preferences', (tester) async {
    // Clears only TakeBack's prototype/setup keys on the test device.
    await SharedPreferencesAsync().clear(
      allowList: {
        PreferencesStore.disclaimerKey,
        PreferencesStore.onboardingKey,
        PreferencesStore.prototypeLockKey,
      },
    );

    Future<void> tap(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(freshApp());
    await tester.pumpAndSettle();
    await tap('Get Started');
    await tap('I Understand');
    await tap('Continue');
    expect(find.text('App selection is coming soon'), findsOneWidget);
    await tap('Continue to TakeBack');
    await tap('LOCK IN');
    expect(find.text('LOCKED IN'), findsOneWidget);
    expect(
      find.text('Prototype mode — no apps are blocked').hitTestable(),
      findsOneWidget,
    );
    await tap('Edit Allowed Apps');
    await tap('Done');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('A tool for your attention'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Recreate all app state and the preference client, preserving device data.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(freshApp());
    await tester.pumpAndSettle();
    expect(find.text('LOCKED IN'), findsOneWidget);
    await tap('UNLOCK');
    expect(find.text('UNLOCKED'), findsOneWidget);
    expect(await PreferencesStore().prototypeLockEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
