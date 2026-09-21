import 'package:flutter/material.dart';
import '../state/takeback_controller.dart';
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
                  ? 'TakeBack will use Screen Time authorization to restrict apps on your iPhone.'
                  : 'TakeBack will need device permissions to restrict apps. '
                        'Android blocking will follow the iOS implementation.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            const Text(
              'Permission setup is coming in a future version. Continuing '
              'does not request or grant any device permissions.',
            ),
            const SizedBox(height: 36),
            const Spacer(),
            const PrototypeNotice(),
            const SizedBox(height: 20),
            ErrorNotice(controller.error),
            FilledButton(
              onPressed: controller.busy ? null : controller.continueSetup,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
