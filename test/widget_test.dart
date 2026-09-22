import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeback/app.dart';
import 'package:takeback/widgets/brand.dart';
import 'package:takeback/services/preferences_store.dart';

import 'support.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding, lock controls, allowed apps and settings work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final memory = MemoryPreferences();
    await tester.pumpWidget(TakeBackApp(controller: makeController(memory)));
    await tester.pumpAndSettle();
    expect(find.text('Unbound'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Brand), matching: find.byType(Icon)),
      findsNothing,
    );
    expect(find.text('Take back your time.'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Unbound',
    );
    await tapText(tester, 'Get Started');
    expect(find.text('Here’s what to expect from Unbound.'), findsOneWidget);
    expect(memory.values[PreferencesStore.disclaimerKey], isNull);
    await tapText(tester, 'I Understand');
    expect(memory.values[PreferencesStore.disclaimerKey], isTrue);
    expect(find.textContaining('does not request or grant'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.text('App selection is coming soon'), findsOneWidget);
    await tapText(tester, 'Continue to Unbound');
    expect(find.text('LOCK IN'), findsOneWidget);
    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    expect(find.byIcon(Icons.north_west_rounded), findsNothing);
    await tapText(tester, 'LOCK IN');
    expect(find.text('UNLOCK'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(
      find.text('Prototype mode — no apps are blocked').hitTestable(),
      findsOneWidget,
    );
    await tapText(tester, 'Edit Allowed Apps');
    expect(find.text('App selection is coming soon'), findsOneWidget);
    expect(find.text('YOUR ALLOWED APPS'), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
    await tapText(tester, 'Done');
    expect(find.text('UNLOCK'), findsOneWidget);
    await tapText(tester, 'UNLOCK');
    expect(find.text('Ready to unlock?'), findsNothing);
    expect(find.text('LOCK IN'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('A tool for your attention'), findsOneWidget);
    expect(find.text('ABOUT UNBOUND'), findsOneWidget);
    expect(find.text('Take back your time.'), findsOneWidget);
    expect(find.text('Removing Unbound?'), findsOneWidget);
    expect(
      find.text(
        'Unlock before deleting the app so your restrictions can be cleared properly.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('TakeBack'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('LOCK IN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('allowed apps fits a compact iPhone without scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final memory = MemoryPreferences()
      ..values.addAll({
        PreferencesStore.disclaimerKey: true,
        PreferencesStore.onboardingKey: true,
      });
    await tester.pumpWidget(TakeBackApp(controller: makeController(memory)));
    await tester.pumpAndSettle();
    await tapText(tester, 'Edit Allowed Apps');

    expect(find.text('YOUR ALLOWED APPS'), findsNothing);
    expect(find.text('Keep what matters.'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
    expect(find.text('Done').hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(find.text('Done')).dy, lessThanOrEqualTo(667));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saved lock opens Main and notice stays visible with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final memory = MemoryPreferences()
        ..values.addAll({
          PreferencesStore.disclaimerKey: true,
          PreferencesStore.onboardingKey: true,
          PreferencesStore.prototypeLockKey: true,
        });
      await tester.pumpWidget(TakeBackApp(controller: makeController(memory)));
      await tester.pumpAndSettle();
      expect(find.text('UNLOCK'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
      expect(
        find.text('Prototype mode — no apps are blocked').hitTestable(),
        findsOneWidget,
      );
      await tapText(tester, 'UNLOCK');
      expect(find.text('LOCK IN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
