import 'package:flutter/material.dart';
import '../widgets/brand.dart';
import '../widgets/notices.dart';
import '../widgets/page_body.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepLabel('ABOUT TAKEBACK'),
          const SizedBox(height: 20),
          Text(
            'Take back your attention.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),
          const PrototypeNotice(),
          const SizedBox(height: 32),
          const DisclaimerText(),
          const SizedBox(height: 28),
          const Text(
            'Your setup and simulated lock state are saved on this device. '
            'Screen Time authorization has not been requested. '
            'Android blocking is not available yet.',
          ),
          const Spacer(),
          const SizedBox(height: 32),
          const Text('TakeBack · Phase 1', style: TextStyle(fontSize: 13)),
        ],
      ),
    ),
  );
}
