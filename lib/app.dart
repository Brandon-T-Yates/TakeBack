import 'package:flutter/material.dart';
import 'screens/allowed_apps_screen.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/main_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/takeback_controller.dart';
import 'theme.dart';

class TakeBackApp extends StatefulWidget {
  const TakeBackApp({super.key, required this.controller});
  final TakeBackController controller;
  @override
  State<TakeBackApp> createState() => _TakeBackAppState();
}

class _TakeBackAppState extends State<TakeBackApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TakeBack',
    debugShowCheckedModeBanner: false,
    theme: takeBackTheme(),
    home: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        if (!controller.ready) {
          return Scaffold(
            body: Center(
              child: controller.error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(controller.error!, textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: controller.busy
                                ? null
                                : controller.initialize,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        }
        return switch (controller.step) {
          SetupStep.welcome => WelcomeScreen(
            onGetStarted: controller.getStarted,
          ),
          SetupStep.disclaimer => DisclaimerScreen(controller: controller),
          SetupStep.permission => PermissionScreen(controller: controller),
          SetupStep.allowedApps => AllowedAppsScreen(
            controller: controller,
            onboarding: true,
          ),
          SetupStep.complete => MainScreen(controller: controller),
        };
      },
    ),
  );
}
