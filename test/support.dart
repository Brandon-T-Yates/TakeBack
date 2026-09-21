import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takeback/services/local_app_restriction_service.dart';
import 'package:takeback/services/preferences_store.dart';
import 'package:takeback/state/takeback_controller.dart';

class MemoryPreferences extends Fake implements SharedPreferencesAsync {
  final values = <String, bool>{};

  @override
  Future<bool?> getBool(String key) async => values[key];

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }
}

TakeBackController makeController(MemoryPreferences memory) {
  final store = PreferencesStore(preferences: memory);
  return TakeBackController(
    preferences: store,
    restrictions: LocalAppRestrictionService(store),
  );
}
