import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'app.dart';
import 'services/local_app_restriction_service.dart';
import 'services/ios_app_restriction_service.dart';
import 'services/preferences_store.dart';
import 'state/takeback_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = PreferencesStore();
  final prototype = LocalAppRestrictionService(preferences);
  runApp(
    TakeBackApp(
      controller: TakeBackController(
        preferences: preferences,
        restrictions: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? IosAppRestrictionService(prototype)
            : prototype,
      ),
    ),
  );
}
