import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/restriction_status.dart';

class AuthorizationSummary extends StatelessWidget {
  const AuthorizationSummary(this.status, {super.key});
  final AuthorizationStatus status;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(switch (status) {
      AuthorizationStatus.authorized => 'Screen Time access is authorized.',
      AuthorizationStatus.denied =>
        'Screen Time access is denied. Authorize again to choose apps.',
      AuthorizationStatus.notDetermined =>
        'Screen Time access is not authorized yet.',
      AuthorizationStatus.unavailable =>
        'Screen Time setup is unavailable on this device.',
    }),
  );
}

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
  const DisclaimerText({super.key, this.nativeMode = false});
  final bool nativeMode;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _DisclaimerItem(
        'A tool for your attention',
        'Unbound is a focus and productivity tool. It is not a security tool '
            'or a parental-control guarantee.',
      ),
      const SizedBox(height: 24),
      const _DisclaimerItem(
        'Your device sets the limits',
        'App restrictions require operating-system permissions. Certain '
            'system apps and emergency functions may remain accessible. '
            'Platform limitations affect what can be restricted.',
      ),
      const SizedBox(height: 24),
      _DisclaimerItem(
        nativeMode
            ? 'You choose what stays accessible'
            : 'This is an early prototype',
        nativeMode
            ? 'On supported iPhones, LOCK IN applies Apple’s app shields except for '
                  'your 1–50 allowed apps. UNLOCK clears Unbound’s restrictions. '
                  'Other Screen Time restrictions may still apply.'
            : 'Screen Time authorization and app selection are available on supported '
                  'iPhones. LOCK IN only changes the state inside Unbound; other apps '
                  'remain accessible. Android setup is not available yet.',
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
