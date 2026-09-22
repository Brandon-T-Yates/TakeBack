import 'package:flutter/material.dart';
import '../state/takeback_controller.dart';
import '../models/restriction_status.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/notices.dart';
import '../widgets/page_body.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key, required this.controller});
  final TakeBackController controller;
  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final available = controller.setup.available;
    final native = controller.mode == RestrictionMode.native;
    final authorized =
        controller.authorization == AuthorizationStatus.authorized;
    return Scaffold(
      appBar: AppBar(title: const Brand()),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepLabel('02 / 03 · PERMISSIONS'),
            const Spacer(),
            const SizedBox(height: 36),
            const Icon(Icons.tune_rounded, size: 56, color: ink),
            const SizedBox(height: 28),
            Text(
              'Your focus.\nYour permission.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              isIOS
                  ? native
                        ? 'Authorize Screen Time to choose the apps that remain accessible while locked in.'
                        : 'Authorize Screen Time to choose the apps you want to allow in a future lock session.'
                  : 'Unbound will need device permissions to restrict apps. '
                        'Android blocking will follow the iOS implementation.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              !isIOS
                  ? 'Permission setup is coming in a future version. Continuing '
                        'does not request or grant any device permissions.'
                  : native
                  ? 'LOCK IN requires Screen Time approval and 1–50 saved allowed apps. UNLOCK clears Unbound’s restrictions.'
                  : !available
                  ? 'Screen Time setup requires a provisioned physical iPhone. '
                        'It is unavailable in the simulator. You can continue in prototype mode.'
                  : 'Authorization and app selection are real. LOCK IN remains '
                        'a simulation and does not block any apps.',
            ),
            if (available) ...[
              const SizedBox(height: 20),
              AuthorizationSummary(controller.authorization),
            ],
            const SizedBox(height: 36),
            const Spacer(),
            if (!native) const PrototypeNotice(),
            const SizedBox(height: 20),
            ErrorNotice(controller.error),
            if (available && !authorized) ...[
              FilledButton(
                onPressed: controller.busy ? null : controller.authorize,
                child: const Text('Authorize Screen Time'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: controller.busy ? null : controller.continueSetup,
                child: Text(
                  native ? 'Continue without locking' : 'Continue in Prototype',
                ),
              ),
            ] else
              FilledButton(
                onPressed: controller.busy ? null : controller.continueSetup,
                child: Text(
                  isIOS && !native ? 'Continue in Prototype' : 'Continue',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
