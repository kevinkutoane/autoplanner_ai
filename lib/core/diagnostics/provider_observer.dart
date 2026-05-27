import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/app_monitor_service.dart';

/// Monitors Riverpod provider state changes and errors.
///
/// Forwards unexpected exceptions to [AppMonitorService] so they appear in
/// the **App Health** analytics tab.
class AppProviderObserver extends ProviderObserver {
  final AppMonitorService _monitor;

  AppProviderObserver(this._monitor);

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    if (kDebugMode) {
      debugPrint('Provider ${provider.name ?? provider.runtimeType} failed: $error');
    }
    _monitor.logFatalError(error, stackTrace);
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // Optional: Log significant state transitions if needed for debugging.
  }
}
