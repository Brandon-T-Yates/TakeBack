import 'package:flutter/material.dart';
import '../theme.dart';

class PrototypeNotice extends StatelessWidget {
  const PrototypeNotice({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    decoration: BoxDecoration(
      color: softGreen,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'Prototype mode — no apps are blocked',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
}

class DisclaimerText extends StatelessWidget {
  const DisclaimerText({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DisclaimerItem(
        'A tool for your attention',
        'TakeBack is a focus and productivity tool. It is not a security tool '
            'or a parental-control guarantee.',
      ),
      SizedBox(height: 24),
      _DisclaimerItem(
        'Your device sets the limits',
        'App restrictions require operating-system permissions. Certain '
            'system apps and emergency functions may remain accessible. '
            'Platform limitations affect what can be restricted.',
      ),
      SizedBox(height: 24),
      _DisclaimerItem(
        'This is an early prototype',
        'Permissions and app selection are not connected yet. LOCK IN only '
            'changes the state inside TakeBack; other apps remain accessible.',
      ),
    ],
  );
}

class _DisclaimerItem extends StatelessWidget {
  const _DisclaimerItem(this.title, this.body);
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      const SizedBox(height: 6),
      Text(body),
    ],
  );
}
