import 'package:flutter/material.dart';
import '../models/restriction_status.dart';
import '../state/takeback_controller.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/notices.dart';
import '../widgets/page_body.dart';
import 'allowed_apps_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.controller});
  final TakeBackController controller;
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _promptOpen = false;
  TakeBackController get controller => widget.controller;

  Future<void> _openAllowedApps() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AllowedAppsScreen(controller: controller),
      ),
    );
  }

  Future<void> _handleLockControl() async {
    if (_promptOpen || controller.busy) return;
    if (controller.mode == RestrictionMode.native &&
        !controller.needsUnlock &&
        !controller.canLockIn) {
      if (controller.authorization != AuthorizationStatus.authorized) {
        await controller.authorize();
      } else {
        await _openAllowedApps();
      }
      return;
    }
    if (controller.mode == RestrictionMode.native &&
        !controller.needsUnlock &&
        !controller.firstNativeLockSafetyAcknowledged) {
      _promptOpen = true;
      try {
        final confirmed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Before you lock in',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unbound restricts other apps using Screen Time. If you ever '
                      'decide to remove Unbound, unlock first so your restrictions '
                      'can be cleared properly.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Got it — Lock In'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (confirmed == true && mounted) {
          await controller.acknowledgeSafetyAndLockIn();
        }
      } finally {
        _promptOpen = false;
      }
      return;
    }
    if (controller.mode != RestrictionMode.native || !controller.needsUnlock) {
      await controller.toggleLockdown();
      return;
    }
    // Uncertain states retain the immediate recovery path.
    if (controller.lockdownState != LockdownState.locked) {
      await controller.unlock();
      return;
    }
    _promptOpen = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Ready to unlock?'),
          content: const Text(
            'If you’re done focusing or need something outside your allowed apps, '
            'go for it. Otherwise, you can stay locked in.',
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  autofocus: true,
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Stay Locked In'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Unlock'),
                ),
              ],
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        // Always clear, even if a notification changed state during the prompt.
        await controller.unlock();
      }
    } finally {
      _promptOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = controller.locked;
    final native = controller.mode == RestrictionMode.native;
    final status = controller.lockdownState;
    final needsUnlock = controller.needsUnlock;
    final needsAuthorization =
        native &&
        !needsUnlock &&
        controller.authorization != AuthorizationStatus.authorized;
    final needsAllowlist = native && !needsUnlock && !controller.allowlistReady;
    final actionLabel = needsUnlock
        ? 'UNLOCK'
        : needsAuthorization
        ? 'AUTHORIZE'
        : needsAllowlist
        ? 'CHOOSE APPS'
        : 'LOCK IN';
    final actionSemanticsLabel = needsUnlock
        ? status == LockdownState.locked
              ? 'Unlock, currently locked'
              : 'Unlock, restriction state unconfirmed'
        : needsAuthorization
        ? 'Authorize Screen Time'
        : needsAllowlist
        ? 'Choose allowed apps'
        : 'Lock in, currently unlocked';
    final actionSemanticsHint = needsUnlock
        ? status == LockdownState.locked
              ? 'Opens unlock options'
              : 'Attempts to clear restrictions'
        : needsAuthorization
        ? 'Requests Screen Time access'
        : needsAllowlist
        ? 'Opens allowed apps'
        : 'Restricts apps outside your allowed list';
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
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
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: controller),
              ),
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
            Text(
              locked
                  ? 'Make room\nfor what matters.'
                  : 'Your attention.\nBack in your hands.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              status == LockdownState.checking
                  ? 'Checking Screen Time authorization. You can still unlock.'
                  : status == LockdownState.error
                  ? 'You can still clear Unbound’s restrictions.'
                  : locked
                  ? native
                        ? 'Your app restriction policy is active.'
                        : 'Your prototype session is active.'
                  : needsAuthorization
                  ? 'Authorize to lock in.'
                  : needsAllowlist
                  ? 'Choose 1–50 apps to lock in.'
                  : 'A little intention goes a long way.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: needsAuthorization || needsAllowlist ? 24 : 36),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Semantics(
                  container: true,
                  button: true,
                  enabled: !controller.busy,
                  label: actionSemanticsLabel,
                  hint: actionSemanticsHint,
                  onTap: controller.busy ? null : _handleLockControl,
                  excludeSemantics: true,
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
                    onPressed: controller.busy ? null : _handleLockControl,
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                status == LockdownState.unlocked
                                    ? Icons.lock_open_rounded
                                    : Icons.lock_rounded,
                                size: 42,
                                color:
                                    status == LockdownState.checking ||
                                        status == LockdownState.error
                                    ? Colors.white70
                                    : null,
                              ),
                              if (status == LockdownState.checking ||
                                  status == LockdownState.error)
                                const Positioned(
                                  right: -8,
                                  bottom: -3,
                                  child: Icon(Icons.help, size: 19),
                                ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          if (largeText)
                            Text(
                              actionLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            )
                          else
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                actionLabel,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _openAllowedApps,
              icon: const Icon(Icons.apps_rounded, size: 19),
              label: const Text('Edit Allowed Apps'),
            ),
            const SizedBox(height: 28),
            const Spacer(),
            ErrorNotice(
              controller.error ??
                  (status == LockdownState.error
                      ? controller.setup.restrictionMessage
                      : null),
            ),
          ],
        ),
      ),
    );
  }
}
