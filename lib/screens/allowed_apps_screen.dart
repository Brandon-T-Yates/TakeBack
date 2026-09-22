import 'package:flutter/material.dart';
import '../state/takeback_controller.dart';
import '../models/restriction_status.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/notices.dart';

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
      body: _AllowedAppsBody(controller: controller, onboarding: onboarding),
    ),
  );
}

class _AllowedAppsBody extends StatelessWidget {
  const _AllowedAppsBody({required this.controller, required this.onboarding});

  final TakeBackController controller;
  final bool onboarding;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final shortWide =
            constraints.maxHeight < 650 && constraints.maxWidth >= 600;
        final compact = constraints.maxHeight < 800;
        final tight = constraints.maxHeight < 650;
        final horizontalPadding = tight ? 16.0 : 28.0;
        final verticalPadding = tight
            ? 4.0
            : compact
            ? 12.0
            : 24.0;
        final sectionGap = tight
            ? 4.0
            : compact
            ? 12.0
            : 32.0;
        final contentGap = tight
            ? 4.0
            : compact
            ? 8.0
            : 16.0;
        final cardPadding = tight
            ? 8.0
            : compact
            ? 20.0
            : 28.0;
        final intro = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onboarding) ...[
              const StepLabel('03 / 03 · ALLOWED APPS'),
              SizedBox(
                height: tight
                    ? 4
                    : compact
                    ? 12
                    : 24,
              ),
            ],
            Text(
              'Keep what matters.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: contentGap),
            Text(
              controller.mode == RestrictionMode.native
                  ? 'Choose 1–50 individual apps to keep accessible while locked in. Unlock before changing your allowed apps.'
                  : 'Choose individual apps to ALLOW during a future lock session. No apps are blocked yet.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        );
        final card = _AllowedAppsCard(
          controller: controller,
          compact: compact,
          tight: tight,
          padding: cardPadding,
        );
        final action = FilledButton(
          onPressed: controller.busy
              ? null
              : onboarding
              ? controller.finishOnboarding
              : () => Navigator.of(context).pop(),
          child: Text(onboarding ? 'Continue to Unbound' : 'Done'),
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            verticalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: shortWide ? 760 : 460),
              child: shortWide
                  ? Column(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    intro,
                                    const Spacer(),
                                    if (controller.mode ==
                                        RestrictionMode.prototype)
                                      const PrototypeNotice(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: Center(child: card)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ErrorNotice(controller.error),
                        action,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        intro,
                        const Spacer(),
                        SizedBox(height: sectionGap),
                        card,
                        SizedBox(height: sectionGap),
                        const Spacer(),
                        if (controller.mode == RestrictionMode.prototype)
                          const PrototypeNotice(),
                        SizedBox(
                          height: tight
                              ? 6
                              : compact
                              ? 12
                              : 20,
                        ),
                        ErrorNotice(controller.error),
                        action,
                      ],
                    ),
            ),
          ),
        );
      },
    ),
  );
}

class _AllowedAppsCard extends StatelessWidget {
  const _AllowedAppsCard({
    required this.controller,
    required this.compact,
    required this.tight,
    required this.padding,
  });

  final TakeBackController controller;
  final bool compact;
  final bool tight;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      border: Border.all(color: ink.withValues(alpha: 0.14)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.apps_rounded, size: 42, color: muted),
        SizedBox(
          height: tight
              ? 4
              : compact
              ? 12
              : 18,
        ),
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
        SizedBox(
          height: tight
              ? 4
              : compact
              ? 8
              : 12,
        ),
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
          SizedBox(
            height: tight
                ? 4
                : compact
                ? 12
                : 20,
          ),
          AuthorizationSummary(controller.authorization),
          SizedBox(
            height: tight
                ? 4
                : compact
                ? 12
                : 16,
          ),
          FilledButton(
            onPressed: controller.busy || !controller.canEditAllowedApps
                ? null
                : controller.authorization == AuthorizationStatus.authorized
                ? controller.chooseAllowedApps
                : controller.authorize,
            child: Text(
              !controller.canEditAllowedApps
                  ? 'Unlock before editing apps'
                  : controller.authorization == AuthorizationStatus.authorized
                  ? 'Choose Allowed Apps'
                  : 'Authorize Screen Time',
            ),
          ),
        ],
      ],
    ),
  );
}
