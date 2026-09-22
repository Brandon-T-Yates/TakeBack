import 'package:flutter/material.dart';
import '../state/takeback_controller.dart';
import '../models/restriction_status.dart';
import '../widgets/brand.dart';
import '../widgets/notices.dart';
import '../widgets/page_body.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final TakeBackController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepLabel('ABOUT UNBOUND'),
            const SizedBox(height: 20),
            Text(
              'Take back your time.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            if (controller.mode == RestrictionMode.prototype)
              const PrototypeNotice(),
            const SizedBox(height: 32),
            DisclaimerText(
              nativeMode: controller.mode == RestrictionMode.native,
            ),
            const SizedBox(height: 28),
            AuthorizationSummary(controller.authorization),
            const SizedBox(height: 16),
            Text(
              controller.mode == RestrictionMode.native
                  ? 'Unbound checks its native app restriction policy when you return. '
                        'Allowed app selections stay on your iPhone as private tokens. '
                        'Android blocking is not available yet.'
                  : 'Your setup and simulated lock state are saved on this device. '
                        'Allowed app selections stay on your iPhone as private tokens. '
                        'Android blocking is not available yet.',
            ),
            const Spacer(),
            const SizedBox(height: 32),
            Text(
              controller.mode == RestrictionMode.native
                  ? 'Unbound · Phase 3'
                  : 'Unbound · Phase 2',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}
