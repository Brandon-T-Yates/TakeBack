import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takeback/app.dart';
import 'package:takeback/services/local_app_restriction_service.dart';
import 'package:takeback/services/ios_app_restriction_service.dart';
import 'package:takeback/services/preferences_store.dart';
import 'package:takeback/state/takeback_controller.dart';

TakeBackApp freshApp() {
  final store = PreferencesStore();
  final prototype = LocalAppRestrictionService(store);
  return TakeBackApp(
    controller: TakeBackController(
      preferences: store,
      restrictions: defaultTargetPlatform == TargetPlatform.iOS
          ? IosAppRestrictionService(prototype)
          : prototype,
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
    expect(find.byIcon(Icons.north_west_rounded), findsNothing);
    expect(
      find.text('No account. No subscription. Just focus.'),
      findsOneWidget,
    );
    await tap('Get Started');
    await tap('I Understand');
    await tap(
      defaultTargetPlatform == TargetPlatform.iOS
          ? 'Continue in Prototype'
          : 'Continue',
    );
    expect(
      find.text(
        defaultTargetPlatform == TargetPlatform.iOS
            ? 'App selection requires an iPhone'
            : 'App selection is coming soon',
      ),
      findsOneWidget,
    );
    await tap('Continue to Unbound');
    await tap('LOCK IN');
    expect(find.text('UNLOCK'), findsOneWidget);
    expect(
      find.text('Prototype mode — no apps are blocked').hitTestable(),
      findsOneWidget,
    );
    await tap('Edit Allowed Apps');
    await tap('Done');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('HOW UNBOUND WORKS'), findsOneWidget);
    expect(find.text('support@tyleryates.me'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Recreate all app state and the preference client, preserving device data.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(freshApp());
    await tester.pumpAndSettle();
    expect(find.text('UNLOCK'), findsOneWidget);
    await tap('UNLOCK');
    expect(find.text('LOCK IN'), findsOneWidget);
    expect(await PreferencesStore().prototypeLockEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
