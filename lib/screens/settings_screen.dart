import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/external_links.dart';
import '../state/takeback_controller.dart';
import '../models/restriction_status.dart';
import '../widgets/brand.dart';
import '../widgets/notices.dart';
import '../widgets/page_body.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);
typedef PackageInfoLoader = Future<PackageInfo> Function();

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.launchUri,
    this.loadPackageInfo,
  });

  final TakeBackController controller;
  final ExternalUriLauncher? launchUri;
  final PackageInfoLoader? loadPackageInfo;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = widget.loadPackageInfo?.call() ?? PackageInfo.fromPlatform();
  }

  Future<void> _open(Uri uri) async {
    var opened = false;
    try {
      opened =
          await widget.launchUri?.call(uri) ??
          await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Couldn’t open that link.')));
    }
  }

  String _versionLabel(PackageInfo info) {
    final build = info.buildNumber;
    return build.isEmpty
        ? 'Version ${info.version}'
        : 'Version ${info.version} ($build)';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
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
            if (widget.controller.mode == RestrictionMode.prototype)
              const PrototypeNotice(),
            if (widget.controller.mode == RestrictionMode.prototype)
              const SizedBox(height: 32),
            const StepLabel('HOW UNBOUND WORKS'),
            const SizedBox(height: 14),
            Text(
              widget.controller.mode == RestrictionMode.native
                  ? 'Unbound uses Apple’s Screen Time controls to restrict apps '
                        'you haven’t chosen to keep available.'
                  : 'On supported iPhones, Unbound uses Apple’s Screen Time '
                        'controls to restrict apps you haven’t chosen to keep available.',
            ),
            const SizedBox(height: 28),
            AuthorizationSummary(widget.controller.authorization),
            const SizedBox(height: 16),
            Text(
              widget.controller.mode == RestrictionMode.native
                  ? 'Unbound checks its native app restriction policy when you return. '
                        'Allowed app selections stay on your iPhone as private tokens. '
                        'Android blocking is not available yet.'
                  : 'Your setup and simulated lock state are saved on this device. '
                        'Allowed app selections stay on your iPhone as private tokens. '
                        'Android blocking is not available yet.',
            ),
            const SizedBox(height: 28),
            Text(
              'Removing Unbound?',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Unlock before deleting the app so your restrictions can be cleared properly.',
            ),
            const SizedBox(height: 32),
            const StepLabel('SUPPORT & PRIVACY'),
            const SizedBox(height: 8),
            _SettingsRow(
              title: 'Support',
              subtitle: supportEmail,
              onTap: () => _open(supportEmailUri),
            ),
            _SettingsRow(
              title: 'Privacy Policy',
              subtitle: privacyPolicyUri == null
                  ? 'Production URL not configured'
                  : 'View Privacy Policy',
              onTap: privacyPolicyUri == null
                  ? null
                  : () => _open(privacyPolicyUri!),
            ),
            const SizedBox(height: 28),
            const StepLabel('ABOUT'),
            const SizedBox(height: 14),
            const Text(
              'Unbound',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) => Text(
                snapshot.hasData
                    ? _versionLabel(snapshot.requireData)
                    : snapshot.hasError
                    ? 'Version unavailable'
                    : 'Loading version…',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    enabled: onTap != null,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.open_in_new_rounded, size: 18),
          ],
        ),
      ),
    ),
  );
}
