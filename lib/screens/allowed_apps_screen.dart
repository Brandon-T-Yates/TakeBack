import 'package:flutter/material.dart';
import '../state/takeback_controller.dart';
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
              'Choose the apps that should remain accessible when TakeBack is locked in.',
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
              child: const Column(
                children: [
                  Icon(Icons.apps_rounded, size: 42, color: muted),
                  SizedBox(height: 18),
                  Text(
                    'App selection is coming soon',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'The native app picker will be connected in the next iOS phase. '
                    'No apps have been selected or restricted.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Spacer(),
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
