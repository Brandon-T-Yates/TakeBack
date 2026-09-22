import 'package:flutter/material.dart';
import '../theme.dart';
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
          const Spacer(),
          Center(
            child: Container(
              width: 196,
              height: 196,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ink.withValues(alpha: 0.12)),
              ),
              padding: const EdgeInsets.all(18),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: softGreen,
                ),
                child: const Icon(
                  Icons.north_west_rounded,
                  size: 76,
                  color: ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
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
          const SizedBox(height: 36),
          const Spacer(),
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
