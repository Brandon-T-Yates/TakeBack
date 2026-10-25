import 'package:flutter/material.dart';
import '../state/takeback_controller.dart';
import '../theme.dart';
import '../widgets/notices.dart';
import '../widgets/page_body.dart';

/// Full-screen disclosure shown after an Android LOCK IN request, before
/// Unbound sends the user to Accessibility settings. Closes once Settings has
/// opened; nothing is enabled or locked from here.
class AndroidAccessScreen extends StatelessWidget {
  const AndroidAccessScreen({super.key, required this.controller});
  final TakeBackController controller;

  Future<void> _continue(BuildContext context) async {
    await controller.openAccessibilitySettings();
    if (controller.error == null && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.shield_outlined, size: 48, color: ink),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                'Android needs one permission to lock in',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unbound uses Android’s Accessibility service to see which app '
              'is opening. When LOCK IN is on and that app isn’t one you chose '
              'to keep, Unbound takes you back to your Home screen.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unbound only uses the name of the app being opened. It does not '
              'read your screen, what you type, or your messages. Nothing is '
              'stored, shared, or sent off your phone. This access isn’t used '
              'for ads or analytics.',
            ),
            const SizedBox(height: 16),
            Text(
              controller.setup.accessibilityEnabled
                  ? 'Android has paused Unbound’s access. On the next screen, '
                        'find Unbound, turn it off, then turn it on again.'
                  : 'On the next screen, find Unbound and turn it on. You can '
                        'turn it off anytime in Settings.',
            ),
            const SizedBox(height: 32),
            const Spacer(),
            ErrorNotice(controller.error),
            FilledButton(
              onPressed: controller.busy ? null : () => _continue(context),
              child: const Text('Continue to Settings'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not Now'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
