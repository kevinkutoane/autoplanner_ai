import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Thin abstraction around remote crash reporting.
///
/// App code depends on this interface so production monitoring can be enabled
/// or disabled without changing the rest of the application.
abstract class CrashReporter {
  const CrashReporter();

  bool get isEnabled;

  Future<void> runApp(
    FutureOr<void> Function() appRunner, {
    required String environment,
  });

  Future<void> captureException(Object error, StackTrace? stackTrace);

  Future<void> captureFlutterError(FlutterErrorDetails details);

  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  });
}

class NoOpCrashReporter extends CrashReporter {
  const NoOpCrashReporter();

  @override
  bool get isEnabled => false;

  @override
  Future<void> runApp(
    FutureOr<void> Function() appRunner, {
    required String environment,
  }) async {
    await appRunner();
  }

  @override
  Future<void> captureException(Object error, StackTrace? stackTrace) async {}

  @override
  Future<void> captureFlutterError(FlutterErrorDetails details) async {}

  @override
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {}
}

class SentryCrashReporter extends CrashReporter {
  final String dsn;

  const SentryCrashReporter({required this.dsn});

  @override
  bool get isEnabled => dsn.isNotEmpty;

  @override
  Future<void> runApp(
    FutureOr<void> Function() appRunner, {
    required String environment,
  }) async {
    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.environment = environment;
      options.attachStacktrace = true;
      options.enableAutoPerformanceTracing = false;
    }, appRunner: () async => appRunner());
  }

  @override
  Future<void> captureException(Object error, StackTrace? stackTrace) {
    return Sentry.captureException(error, stackTrace: stackTrace);
  }

  @override
  Future<void> captureFlutterError(FlutterErrorDetails details) {
    return Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
      hint: Hint.withMap({'library': details.library}),
    );
  }

  @override
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(message: message, category: category ?? 'app', data: data),
    );
  }
}
