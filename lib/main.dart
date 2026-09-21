import 'package:flutter/material.dart';

import 'app.dart';
import 'services/local_app_restriction_service.dart';
import 'services/preferences_store.dart';
import 'state/takeback_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = PreferencesStore();
  runApp(
    TakeBackApp(
      controller: TakeBackController(
        preferences: preferences,
        restrictions: LocalAppRestrictionService(preferences),
      ),
    ),
  );
}
