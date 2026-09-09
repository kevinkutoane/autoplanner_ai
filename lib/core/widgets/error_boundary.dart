import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/ui_kit.dart';

/// A widget that catches errors in its child subtree and displays a
/// user-friendly fallback instead of a red error screen.
///
/// Usage:
/// ```dart
/// ErrorBoundary(
///   child: SomeComplexWidget(),
///   onRetry: () => setState(() {}),
/// )
/// ```
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final VoidCallback? onRetry;
  final String? errorTitle;
  final String? errorMessage;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onRetry,
    this.errorTitle,
    this.errorMessage,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
  }

  void _reset() {
    setState(() {
      _hasError = false;
      _errorDetails = null;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _ErrorFallback(
        title: widget.errorTitle ?? 'Something went wrong',
        message:
            widget.errorMessage ??
            'An unexpected error occurred. Please try again.',
        details: kDebugMode ? _errorDetails?.exceptionAsString() : null,
        onRetry: _reset,
      );
    }
    return widget.child;
  }
}

/// A reusable error fallback UI with glassmorphic styling.
class _ErrorFallback extends StatelessWidget {
  final String title;
  final String message;
  final String? details;
  final VoidCallback? onRetry;

  const _ErrorFallback({
    required this.title,
    required this.message,
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCoral.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 32,
                  color: kCoral,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : kDark0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              if (details != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(8)
                        : Colors.black.withAlpha(8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    details!,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                GradBtn(
                  label: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onTap: onRetry!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A reusable retry dialog shown when an operation fails.
///
/// Returns `true` if the user taps Retry, `false` if they dismiss.
Future<bool> showRetryDialog(
  BuildContext context, {
  required String title,
  required String message,
  String retryLabel = 'Retry',
  String cancelLabel = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: isDark ? kDark1 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: kCoral, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : kDark0,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              cancelLabel,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              retryLabel,
              style: TextStyle(color: kIndigo, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
