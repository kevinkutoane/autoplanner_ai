import 'package:flutter/material.dart';
import '../theme/ui_kit.dart';

/// A composable widget that handles the three common async states:
/// loading, empty, and error — with consistent glassmorphic styling.
///
/// Usage:
/// ```dart
/// AsyncStateWidget(
///   isLoading: isLoading,
///   isEmpty: items.isEmpty,
///   hasError: hasError,
///   emptyIcon: Icons.inbox_rounded,
///   emptyMessage: 'No items yet',
///   emptySubtitle: 'Tap + to create your first item',
///   onRetry: () => reload(),
///   child: ListView(...),
/// )
/// ```
class AsyncStateWidget extends StatelessWidget {
  final bool isLoading;
  final bool isEmpty;
  final bool hasError;
  final String? errorMessage;
  final IconData emptyIcon;
  final String emptyMessage;
  final String? emptySubtitle;
  final VoidCallback? onRetry;
  final VoidCallback? onEmptyAction;
  final String? emptyActionLabel;
  final Widget child;

  const AsyncStateWidget({
    super.key,
    this.isLoading = false,
    this.isEmpty = false,
    this.hasError = false,
    this.errorMessage,
    this.emptyIcon = Icons.inbox_rounded,
    this.emptyMessage = 'Nothing here yet',
    this.emptySubtitle,
    this.onRetry,
    this.onEmptyAction,
    this.emptyActionLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandedLoader(),
            const SizedBox(height: 16),
            Text(
              'Loading…',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kCoral.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 28,
                  color: kCoral,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                errorMessage ?? 'Something went wrong',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : kDark0,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                GradBtn(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onTap: onRetry!,
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (r) => kGradientMain.createShader(r),
                child: Icon(emptyIcon, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                emptyMessage,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : kDark0,
                ),
                textAlign: TextAlign.center,
              ),
              if (emptySubtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  emptySubtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onEmptyAction != null && emptyActionLabel != null) ...[
                const SizedBox(height: 18),
                GradBtn(
                  label: emptyActionLabel!,
                  icon: Icons.add_rounded,
                  onTap: onEmptyAction!,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return child;
  }
}
