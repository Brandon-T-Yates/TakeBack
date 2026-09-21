import 'dart:async';
import 'package:flutter/services.dart';

import '../models/restriction_status.dart';
import 'app_restriction_service.dart';
import 'local_app_restriction_service.dart';

/// Real iOS setup; lock operations deliberately remain local simulations.
class IosAppRestrictionService implements AppRestrictionService {
  IosAppRestrictionService(
    this._prototype, {
    MethodChannel channel = const MethodChannel('takeback/family_controls'),
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

  final LocalAppRestrictionService _prototype;
  final MethodChannel _channel;
  final _changes = StreamController<RestrictionSetupState>.broadcast();

  @override
  RestrictionMode get mode => RestrictionMode.prototype;
  @override
  Stream<RestrictionSetupState> get setupChanges => _changes.stream;
  @override
  Future<RestrictionSetupState> getSetupState() async {
    final data = await _channel.invokeMapMethod<Object?, Object?>(
      'getSetupState',
    );
    return RestrictionSetupState.fromNative(data ?? {});
  }

  @override
  Future<AuthorizationStatus> requestAuthorization() async {
    await _channel.invokeMethod<void>('requestAuthorization');
    return (await getSetupState()).authorization;
  }

  @override
  Future<AppSelectionResult> selectAllowedApps() async =>
      switch (await _channel.invokeMethod<String>('selectAllowedApps')) {
        'selected' => AppSelectionResult.selected,
        'cancelled' => AppSelectionResult.cancelled,
        _ => AppSelectionResult.unavailable,
      };

  @override
  Future<void> enableLockdown() => _prototype.enableLockdown();
  @override
  Future<void> disableLockdown() => _prototype.disableLockdown();
  @override
  Future<void> toggleLockdown() => _prototype.toggleLockdown();
  @override
  Future<bool> isLockdownEnabled() => _prototype.isLockdownEnabled();

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _changes.close();
    _prototype.dispose();
  }
}
