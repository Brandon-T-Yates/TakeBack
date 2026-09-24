import 'dart:async';
import 'package:flutter/services.dart';

import '../models/restriction_status.dart';
import 'app_restriction_service.dart';
import 'local_app_restriction_service.dart';

/// Native restrictions on supported iPhones; explicit simulator fallback only.
class IosAppRestrictionService implements AppRestrictionService {
  IosAppRestrictionService(
    this._prototype, {
    MethodChannel channel = const MethodChannel('takeback/family_controls'),
  }) : _channel = channel {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'setupChanged' && !_changes.isClosed) {
        final state = _accept(
          Map<Object?, Object?>.from(call.arguments as Map),
        );
        if (state != null) _changes.add(state);
      }
    });
  }

  final LocalAppRestrictionService _prototype;
  final MethodChannel _channel;
  final _changes = StreamController<RestrictionSetupState>.broadcast();
  RestrictionMode _mode = RestrictionMode.native;
  bool _capabilityKnown = false;
  RestrictionSetupState? _latestState;
  int? _latestRevision;

  RestrictionSetupState? _accept(Map<Object?, Object?> data) {
    final state = RestrictionSetupState.fromNative(data);
    final revision = state.revision;
    if (_latestRevision case final latest?) {
      if (revision == null || revision <= latest) return null;
    }
    _mode = state.mode;
    _capabilityKnown = true;
    _latestState = state;
    if (revision != null) _latestRevision = revision;
    return state;
  }

  RestrictionSetupState _reconcile(Map<Object?, Object?> data) =>
      _accept(data) ?? _latestState!;

  @override
  RestrictionMode get mode => _mode;
  @override
  Stream<RestrictionSetupState> get setupChanges => _changes.stream;
  @override
  Future<RestrictionSetupState> getSetupState() async {
    final data = await _channel.invokeMapMethod<Object?, Object?>(
      'getSetupState',
    );
    return _reconcile(data ?? {});
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
  Future<void> enableLockdown() =>
      _mutate('enableLockdown', _prototype.enableLockdown);
  @override
  Future<void> disableLockdown() =>
      _mutate('disableLockdown', _prototype.disableLockdown);
  @override
  Future<void> toggleLockdown() =>
      _mutate('toggleLockdown', _prototype.toggleLockdown);
  @override
  Future<bool> isLockdownEnabled() async {
    if (!_capabilityKnown) await getSetupState();
    if (mode == RestrictionMode.prototype) {
      return _prototype.isLockdownEnabled();
    }
    final enabled = await _channel.invokeMethod<bool>('isLockdownEnabled');
    if (enabled == null) {
      throw PlatformException(
        code: 'restriction_state_unknown',
        message:
            'Could not confirm Unbound’s restrictions. You can still unlock.',
      );
    }
    return enabled;
  }

  Future<void> _mutate(String method, Future<void> Function() prototype) async {
    // Recovery must be callable even when a preceding capability read failed.
    if (!_capabilityKnown && method != 'disableLockdown') await getSetupState();
    if (mode == RestrictionMode.prototype) return prototype();
    final data = await _channel.invokeMapMethod<Object?, Object?>(method);
    final state = _accept(data ?? {});
    if (state != null && !_changes.isClosed) _changes.add(state);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _changes.close();
    _prototype.dispose();
  }
}
