import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/app_monitor_service.dart';

/// Monitors Riverpod provider state changes and errors.
///
/// Forwards unexpected exceptions to [AppMonitorService] so they appear in
/// the **App Health** analytics tab.
final class AppProviderObserver extends ProviderObserver {
  final AppMonitorService _monitor;

  AppProviderObserver(this._monitor);

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (kDebugMode) {
      debugPrint('Provider ${context.provider.name ?? context.provider.runtimeType} failed: $error');
    }
    _monitor.logFatalError(error, stackTrace);
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    // Optional: Log significant state transitions if needed for debugging.
  }
}
