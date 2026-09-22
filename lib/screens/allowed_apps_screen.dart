import 'package:flutter/material.dart';
import '../state/takeback_controller.dart';
import '../models/restriction_status.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/notices.dart';
import '../widgets/page_body.dart';

class AllowedAppsScreen extends StatelessWidget {
  const AllowedAppsScreen({
    super.key,
    required this.controller,
    this.onboarding = false,
  });
  final TakeBackController controller;
  final bool onboarding;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: onboarding ? const Brand() : const Text('Allowed Apps'),
      ),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StepLabel(
              onboarding ? '03 / 03 · ALLOWED APPS' : 'YOUR ALLOWED APPS',
            ),
            const SizedBox(height: 24),
            Text(
              'Keep what matters.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              controller.mode == RestrictionMode.native
                  ? 'Choose 1–50 individual apps to keep accessible while locked in. Unlock before changing your allowed apps.'
                  : 'Choose individual apps to ALLOW during a future lock session. No apps are blocked yet.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                border: Border.all(color: ink.withValues(alpha: 0.14)),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(Icons.apps_rounded, size: 42, color: muted),
                  const SizedBox(height: 18),
                  Text(
                    controller.setup.available
                        ? controller.setup.selectionUsable
                              ? '${controller.setup.applicationCount} allowed apps saved'
                              : 'No usable app selection saved'
                        : Theme.of(context).platform == TargetPlatform.iOS
                        ? 'App selection requires an iPhone'
                        : 'App selection is coming soon',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.setup.available
                        ? 'Select individual apps only. Expand categories to choose apps; '
                              'category and website selections cannot be saved. '
                              'You can review your saved apps in the native picker.'
                        : Theme.of(context).platform == TargetPlatform.iOS
                        ? 'Use a provisioned physical iPhone to authorize Screen Time '
                              'and select apps. The simulator supports prototype navigation only.'
                        : 'Android app selection is not available yet. No apps are restricted.',
                    textAlign: TextAlign.center,
                  ),
                  if (controller.setup.available) ...[
                    const SizedBox(height: 20),
                    AuthorizationSummary(controller.authorization),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed:
                          controller.busy || !controller.canEditAllowedApps
                          ? null
                          : controller.authorization ==
                                AuthorizationStatus.authorized
                          ? controller.chooseAllowedApps
                          : controller.authorize,
                      child: Text(
                        !controller.canEditAllowedApps
                            ? 'Unlock before editing apps'
                            : controller.authorization ==
                                  AuthorizationStatus.authorized
                            ? 'Choose Allowed Apps'
                            : 'Authorize Screen Time',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Spacer(),
            if (controller.mode == RestrictionMode.prototype)
              const PrototypeNotice(),
            const SizedBox(height: 20),
            ErrorNotice(controller.error),
            FilledButton(
              onPressed: controller.busy
                  ? null
                  : onboarding
                  ? controller.finishOnboarding
                  : () => Navigator.of(context).pop(),
              child: Text(onboarding ? 'Continue to TakeBack' : 'Done'),
            ),
          ],
        ),
      ),
    ),
  );
}
