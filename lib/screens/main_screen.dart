import 'package:flutter/material.dart';
import '../models/restriction_status.dart';
import '../state/takeback_controller.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/notices.dart';
import '../widgets/page_body.dart';
import 'allowed_apps_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.controller});
  final TakeBackController controller;
  @override
  Widget build(BuildContext context) {
    final locked = controller.locked;
    return Scaffold(
      bottomNavigationBar: controller.mode == RestrictionMode.prototype
          ? const SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, 8, 28, 16),
                child: PrototypeNotice(),
              ),
            )
          : null,
      appBar: AppBar(
        title: const Brand(),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined, size: 23),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: locked ? softGreen : const Color(0xFFEDECE6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        locked ? Icons.circle : Icons.circle_outlined,
                        size: 8,
                        color: ink,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        locked ? 'LOCKED IN' : 'UNLOCKED',
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              locked
                  ? 'Make room\nfor what matters.'
                  : 'Your attention.\nBack in your hands.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              locked
                  ? 'Your prototype session is active.'
                  : 'A little intention goes a long way.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: locked ? const Color(0xFF315A4F) : ink,
                    minimumSize: const Size(248, 224),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 46,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(64),
                    ),
                  ),
                  onPressed: controller.busy ? null : controller.toggleLockdown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        locked
                            ? Icons.lock_open_rounded
                            : Icons.north_west_rounded,
                        size: 42,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        locked ? 'UNLOCK' : 'LOCK IN',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AllowedAppsScreen(controller: controller),
                ),
              ),
              icon: const Icon(Icons.apps_rounded, size: 19),
              label: const Text('Edit Allowed Apps'),
            ),
            const SizedBox(height: 28),
            const Spacer(),
            ErrorNotice(controller.error),
          ],
        ),
      ),
    );
  }
}
