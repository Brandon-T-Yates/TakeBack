import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeback/app.dart';
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
    await tapText(tester, 'Get Started');
    expect(memory.values[PreferencesStore.disclaimerKey], isNull);
    await tapText(tester, 'I Understand');
    expect(memory.values[PreferencesStore.disclaimerKey], isTrue);
    expect(find.textContaining('does not request or grant'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.text('App selection is coming soon'), findsOneWidget);
    await tapText(tester, 'Continue to TakeBack');
    expect(find.text('UNLOCKED'), findsOneWidget);
    await tapText(tester, 'LOCK IN');
    expect(find.text('LOCKED IN'), findsOneWidget);
    expect(
      find.text('Prototype mode — no apps are blocked').hitTestable(),
      findsOneWidget,
    );
    await tapText(tester, 'Edit Allowed Apps');
    expect(find.text('App selection is coming soon'), findsOneWidget);
    await tapText(tester, 'Done');
    expect(find.text('LOCKED IN'), findsOneWidget);
    await tapText(tester, 'UNLOCK');
    expect(find.text('UNLOCKED'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('A tool for your attention'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('UNLOCKED'), findsOneWidget);
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
      expect(find.text('LOCKED IN'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
      expect(
        find.text('Prototype mode — no apps are blocked').hitTestable(),
        findsOneWidget,
      );
      await tapText(tester, 'UNLOCK');
      expect(find.text('UNLOCKED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
