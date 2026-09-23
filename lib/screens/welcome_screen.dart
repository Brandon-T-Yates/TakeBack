import 'package:flutter/material.dart';
import '../widgets/brand.dart';
import '../widgets/page_body.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onGetStarted});
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Brand()),
    body: PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          const StepLabel('LESS NOISE. MORE YOU.'),
          const SizedBox(height: 18),
          Text(
            'Take back your time.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 20),
          Text(
            'Choose the apps you want to keep. Unbound is designed to '
            'restrict the rest with one button.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          const Text('No account. No subscription. Just focus.'),
          const Spacer(),
          const SizedBox(height: 36),
          FilledButton(
            onPressed: onGetStarted,
            child: const Text('Get Started'),
          ),
          const SizedBox(height: 16),
          const Center(child: Text('A little space for what matters.')),
        ],
      ),
    ),
  );
}
