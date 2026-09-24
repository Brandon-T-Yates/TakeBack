import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:takeback/screens/allowed_apps_screen.dart';
import 'package:takeback/screens/main_screen.dart';
import 'package:takeback/screens/settings_screen.dart';
import 'package:takeback/theme.dart';

import 'support.dart';

void expectActionableMainControl(
  WidgetTester tester, {
  required String label,
  required String hint,
}) {
  final node = tester.getSemantics(find.byType(FilledButton).first);
  final labeledControl = find.bySemanticsLabel(label);
  expect(labeledControl, findsOneWidget);
  expect(tester.getSemantics(labeledControl).id, node.id);
  expect(node.label, label);
  expect(node.hint, hint);
  expect(node.flagsCollection.isButton, isTrue);
  expect(node.flagsCollection.isEnabled, Tristate.isTrue);
  expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
}

void useCompactLargeText(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets('Main exposes one descriptive lock control', (tester) async {
    final controller = makeController(MemoryPreferences());
    addTearDown(controller.dispose);
    await controller.initialize();
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: takeBackTheme(),
        home: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MainScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expectActionableMainControl(
      tester,
      label: 'Lock in, currently unlocked',
      hint: 'Restricts apps outside your allowed list',
    );
    await tester.tap(find.text('LOCK IN'));
    await tester.pumpAndSettle();
    expectActionableMainControl(
      tester,
      label: 'Unlock, currently locked',
      hint: 'Opens unlock options',
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Settings links are merged, headed, and tappable', (
    tester,
  ) async {
    useCompactLargeText(tester);
    final controller = makeController(MemoryPreferences());
    addTearDown(controller.dispose);
    await controller.initialize();
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: takeBackTheme(),
        home: SettingsScreen(
          controller: controller,
          launchUri: (_) async => true,
          loadPackageInfo: () async => PackageInfo(
            appName: 'Unbound',
            packageName: 'com.tyleryates.takeback',
            version: '1.0.0',
            buildNumber: '1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final supportHeading = find.text('SUPPORT & PRIVACY');
    await tester.ensureVisible(supportHeading);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(supportHeading),
      matchesSemantics(label: 'SUPPORT & PRIVACY', isHeader: true),
    );
    final support = find.bySemanticsLabel('Support, support@tyleryates.me');
    expect(support, findsOneWidget);
    await tester.ensureVisible(support);
    await tester.pumpAndSettle();
    expect(tester.getSize(support).height, greaterThanOrEqualTo(48));
    expect(support.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Allowed Apps scrolls only when large text needs room', (
    tester,
  ) async {
    useCompactLargeText(tester);
    final controller = makeController(MemoryPreferences());
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: takeBackTheme(),
        home: AllowedAppsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final done = find.text('Done');
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    expect(done.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
