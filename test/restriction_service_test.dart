import 'package:flutter_test/flutter_test.dart';
import 'package:takeback/models/restriction_status.dart';
import 'package:takeback/services/local_app_restriction_service.dart';
import 'package:takeback/services/preferences_store.dart';
import 'package:takeback/state/takeback_controller.dart';

import 'support.dart';

void main() {
  test(
    'lock, unlock and toggle persist only the prototype preference',
    () async {
      final memory = MemoryPreferences();
      final store = PreferencesStore(preferences: memory);
      final service = LocalAppRestrictionService(store);
      expect(await service.isLockdownEnabled(), isFalse);
      await service.enableLockdown();
      expect(
        await LocalAppRestrictionService(store).isLockdownEnabled(),
        isTrue,
      );
      await service.disableLockdown();
      expect(await service.isLockdownEnabled(), isFalse);
      await service.toggleLockdown();
      expect(await service.isLockdownEnabled(), isTrue);
      await service.toggleLockdown();
      expect(await service.isLockdownEnabled(), isFalse);
      expect(memory.values, {PreferencesStore.prototypeLockKey: false});
    },
  );

  test('prototype never reports real permissions or selected apps', () async {
    final service = LocalAppRestrictionService(
      PreferencesStore(preferences: MemoryPreferences()),
    );
    expect(service.mode, RestrictionMode.prototype);
    expect(
      await service.requestAuthorization(),
      AuthorizationStatus.unavailable,
    );
    expect(await service.selectAllowedApps(), AppSelectionResult.unavailable);
  });

  test(
    'acceptance resumes setup and completed onboarding restores lock',
    () async {
      final memory = MemoryPreferences();
      final first = makeController(memory);
      await first.initialize();
      await first.finishOnboarding();
      expect(first.step, SetupStep.disclaimer);
      expect(memory.values[PreferencesStore.onboardingKey], isNull);
      await first.acceptDisclaimer();
      first.dispose();

      final resumed = makeController(memory);
      await resumed.initialize();
      expect(resumed.step, SetupStep.permission);
      await resumed.continueSetup();
      await resumed.finishOnboarding();
      // The busy guard ignores a second tap while the first is pending.
      await Future.wait([resumed.toggleLockdown(), resumed.toggleLockdown()]);
      expect(resumed.locked, isTrue);
      resumed.dispose();

      final restored = makeController(memory);
      await restored.initialize();
      expect(restored.step, SetupStep.complete);
      expect(restored.locked, isTrue);
      restored.dispose();
    },
  );
}
