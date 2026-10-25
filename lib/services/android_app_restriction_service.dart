import 'dart:async';
import 'package:flutter/services.dart';

import '../models/restriction_status.dart';
import 'app_restriction_service.dart';

/// An installed app the user chose to keep available on Android.
class AndroidAllowedApp {
  const AndroidAllowedApp({required this.packageName, required this.label});
  final String packageName;
  final String label;
}

/// Android app selection and LOCK IN. Enforcement runs natively in Unbound's
/// Accessibility service, which the user turns on in Android Settings.
class AndroidAppRestrictionService implements AppRestrictionService {
  AndroidAppRestrictionService({
    MethodChannel channel = const MethodChannel('unbound/android_restrictions'),
  }) : _channel = channel {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'setupChanged' && !_changes.isClosed) {
        _changes.add(
          RestrictionSetupState.fromNative(
            Map<Object?, Object?>.from(call.arguments as Map),
          ),
        );
      }
    });
  }

  final MethodChannel _channel;
  final _changes = StreamController<RestrictionSetupState>.broadcast();

  @override
  RestrictionMode get mode => RestrictionMode.android;
  @override
  Stream<RestrictionSetupState> get setupChanges => _changes.stream;

  @override
  Future<RestrictionSetupState> getSetupState() async =>
      RestrictionSetupState.fromNative(
        await _channel.invokeMapMethod<Object?, Object?>('getSetupState') ??
            const {},
      );

  @override
  Future<AuthorizationStatus> requestAuthorization() async =>
      (await getSetupState()).authorization;

  @override
  Future<AppSelectionResult> selectAllowedApps() async =>
      switch (await _channel.invokeMethod<String>('selectAllowedApps')) {
        'selected' => AppSelectionResult.selected,
        'cancelled' => AppSelectionResult.cancelled,
        _ => AppSelectionResult.unavailable,
      };

  Future<List<AndroidAllowedApp>> getAllowedApps() async {
    final apps =
        await _channel.invokeListMethod<Object?>('getAllowedApps') ?? const [];
    return [
      for (final app in apps.whereType<Map<Object?, Object?>>())
        if (app['packageName'] case final String packageName)
          AndroidAllowedApp(
            packageName: packageName,
            label: app['label'] as String? ?? packageName,
          ),
    ];
  }

  /// Opens Android's Accessibility settings. Call only after the in-app
  /// disclosure has been shown and the user chose to continue.
  Future<bool> openAccessibilitySettings() async =>
      await _channel.invokeMethod<bool>('openAccessibilitySettings') ?? false;

  @override
  Future<bool> isLockdownEnabled() async =>
      await _channel.invokeMethod<bool>('isLockdownEnabled') ?? false;
  @override
  Future<void> enableLockdown() => _mutate('enableLockdown');
  @override
  Future<void> disableLockdown() => _mutate('disableLockdown');
  @override
  Future<void> toggleLockdown() => _mutate('toggleLockdown');

  Future<void> _mutate(String method) async {
    final data = await _channel.invokeMapMethod<Object?, Object?>(method);
    if (data != null && !_changes.isClosed) {
      _changes.add(RestrictionSetupState.fromNative(data));
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _changes.close();
  }
}
