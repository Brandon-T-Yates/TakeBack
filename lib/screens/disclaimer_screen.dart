import 'package:flutter/material.dart';
import '../state/takeback_controller.dart';
import '../widgets/brand.dart';
import '../widgets/notices.dart';
import '../widgets/page_body.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key, required this.controller});
  final TakeBackController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Brand()),
    body: PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepLabel('01 / 03 · BEFORE YOU BEGIN'),
          const SizedBox(height: 20),
          Text(
            'A moment of clarity.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          Text(
            'Here’s what to expect from TakeBack.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 36),
          const DisclaimerText(),
          const SizedBox(height: 32),
          const Spacer(),
          ErrorNotice(controller.error),
          FilledButton(
            onPressed: controller.busy ? null : controller.acceptDisclaimer,
            child: const Text('I Understand'),
          ),
        ],
      ),
    ),
  );
}
