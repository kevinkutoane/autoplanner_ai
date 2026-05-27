import 'package:flutter/foundation.dart';

// ── Exception types ───────────────────────────────────────────────────────────

/// Thrown when user input violates the content policy.
///
/// [reason] is a user-friendly message suitable for display in a snackbar.
/// [code] is a machine-readable code for logging/analytics.
class ContentPolicyException implements Exception {
  final String reason;
  final ContentPolicyCode code;
  const ContentPolicyException(this.reason, {this.code = ContentPolicyCode.generic});

  @override
  String toString() => 'ContentPolicyException(${code.name}): $reason';
}

/// Thrown when a per-minute or per-hour call-frequency limit is exceeded.
class CallFrequencyException implements Exception {
  final String message;
  const CallFrequencyException(this.message);

  @override
  String toString() => 'CallFrequencyException: $message';
}

/// Categorises the reason a content policy check failed.
enum ContentPolicyCode {
  /// Input exceeds the maximum allowed character length.
  tooLong,

  /// Input appears to be empty or whitespace-only after normalisation.
  empty,

  /// Input contains a prompt-injection attempt.
  promptInjection,

  /// Input contains content that violates the app's usage policy
  /// (hate speech, explicit content, self-harm, etc.).
  harmfulContent,

  /// AI response output contains content that should not be shown to the user.
  unsafeOutput,

  /// Catch-all for policy violations not covered by the above.
  generic,
}

// ── AIGuard ───────────────────────────────────────────────────────────────────

/// Centralised abuse-prevention layer for all AI interactions.
///
/// This class is the single choke-point between user-supplied text and the
/// AI provider. It enforces:
///
/// 1. **Input length caps** — prevents context-flooding attacks.
/// 2. **Prompt-injection defence** — strips and rejects role-switch markers,
///    delimiter escapes, and instruction-override patterns.
/// 3. **Content policy** — keyword-based pre-flight check for categories of
///    harmful content (hate speech, self-harm, explicit content, violence).
/// 4. **Call-frequency throttle** — sliding-window rate limiter that caps
///    AI calls per minute and per hour, independent of the daily token budget.
/// 5. **Output screening** — post-generation check to catch model jailbreaks
///    or unexpected harmful content in AI responses before they reach the UI.
///
/// Usage:
/// ```dart
/// // Validate before sending to AI
/// AIGuard.instance.validateInput(userText, context: 'brainDump');
///
/// // Throttle check (call before every AI invocation)
/// AIGuard.instance.checkCallFrequency();
///
/// // Screen AI output before displaying
/// AIGuard.instance.validateOutput(aiResponseText);
/// ```
class AIGuard {
  AIGuard._();

  /// Singleton — one guard per app process.
  static final AIGuard instance = AIGuard._();

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Hard maximum characters accepted from any single user input field.
  static const int maxInputChars = 8000;

  /// Soft warning threshold — inputs above this are trimmed with a notice.
  static const int softInputLimit = 4000;

  /// Maximum AI calls allowed within any rolling 60-second window.
  static const int maxCallsPerMinute = 10;

  /// Maximum AI calls allowed within any rolling 3600-second window.
  static const int maxCallsPerHour = 60;

  // ── Call-frequency state ──────────────────────────────────────────────────

  final List<DateTime> _callTimestamps = [];

  // ── Prompt-injection patterns ─────────────────────────────────────────────

  /// Patterns that indicate an attempt to override the system prompt or
  /// assume a different AI persona. Matched case-insensitively.
  static const List<String> _injectionPatterns = [
    // Role-switch markers used in ChatML / Llama / Gemini instruction formats
    '\nsystem:', '\nhuman:', '\nassistant:', '\nuser:',
    '[inst]', '[/inst]', '[system]', '[/system]',
    '<<sys>>', '<</sys>>',
    // Delimiter escapes
    '"""', "'''", '\x00',
    // Common jailbreak prefixes
    'ignore previous instructions',
    'ignore all previous',
    'disregard your instructions',
    'forget your instructions',
    'you are now',
    'act as if you are',
    'pretend you are',
    'roleplay as',
    'your new instructions are',
    'override system prompt',
    'bypass your guidelines',
    'jailbreak',
    'dan mode',
    'do anything now',
    // Exfiltration probes
    'print your system prompt',
    'repeat your instructions',
    'show me your prompt',
    'what are your instructions',
  ];

  // ── Harmful content patterns ──────────────────────────────────────────────

  /// Keyword sets for content categories that should not be processed.
  /// These are intentionally conservative — false positives are preferable
  /// to processing genuinely harmful content.
  ///
  /// NOTE: This is a client-side first line of defence only. Server-side
  /// moderation (e.g. Google Cloud Natural Language API SafeSearch, or
  /// Gemini's built-in safety filters) should be the primary enforcement
  /// mechanism in production.
  static const Map<String, List<String>> _harmfulPatterns = {
    'self_harm': [
      'how to kill myself',
      'ways to commit suicide',
      'methods of self-harm',
      'how to hurt myself',
      'want to die',
      'end my life',
    ],
    'explicit_content': [
      'generate explicit',
      'write explicit',
      'explicit sexual',
      'pornographic',
    ],
    'hate_speech': [
      'write a manifesto',
      'hate speech against',
      'racial slur',
      'genocide of',
    ],
    'illegal_activity': [
      'how to make a bomb',
      'how to synthesize drugs',
      'how to hack into',
      'how to steal',
      'instructions for violence',
    ],
  };

  // ── Output screening patterns ─────────────────────────────────────────────

  /// Patterns in AI output that suggest the model was jailbroken or produced
  /// content outside its intended scope. If found, the output is suppressed.
  static const List<String> _unsafeOutputPatterns = [
    'i am now in dan mode',
    'i have no restrictions',
    'as an unrestricted ai',
    'i can now do anything',
    'jailbreak successful',
    'system prompt:',
    'my instructions are:',
  ];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Validates [input] before it is sent to the AI provider.
  ///
  /// - [context] is a label used in debug logs (e.g. `'brainDump'`, `'parseTasks'`).
  /// - Returns the cleaned, trimmed input string if validation passes.
  /// - Throws [ContentPolicyException] if the input violates any policy.
  ///
  /// This method does NOT throw for inputs that merely exceed [softInputLimit];
  /// it silently truncates them to [maxInputChars] instead.
  String validateInput(String input, {String context = 'unknown'}) {
    final trimmed = input.trim();

    // 1. Empty check
    if (trimmed.isEmpty) {
      throw const ContentPolicyException(
        'Please enter some text before sending.',
        code: ContentPolicyCode.empty,
      );
    }

    // 2. Hard length cap
    final capped = trimmed.length > maxInputChars
        ? trimmed.substring(0, maxInputChars)
        : trimmed;

    if (kDebugMode && trimmed.length > softInputLimit) {
      debugPrint(
        '[AIGuard] Input truncated from ${trimmed.length} to $maxInputChars chars ($context)',
      );
    }

    // 3. Prompt-injection check (case-insensitive)
    final lower = capped.toLowerCase();
    for (final pattern in _injectionPatterns) {
      if (lower.contains(pattern.toLowerCase())) {
        if (kDebugMode) {
          debugPrint('[AIGuard] Injection pattern detected: "$pattern" ($context)');
        }
        throw ContentPolicyException(
          'Your input contains text that cannot be processed. '
          'Please rephrase and try again.',
          code: ContentPolicyCode.promptInjection,
        );
      }
    }

    // 4. Harmful content check
    for (final entry in _harmfulPatterns.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword.toLowerCase())) {
          if (kDebugMode) {
            debugPrint(
              '[AIGuard] Harmful content detected: category=${entry.key} ($context)',
            );
          }
          // Self-harm gets a compassionate message; others get a generic block.
          final message = entry.key == 'self_harm'
              ? 'It sounds like you may be going through a difficult time. '
                'Please reach out to a mental health professional or crisis line. '
                'This app is not able to assist with this request.'
              : 'This request cannot be processed as it may violate our usage policy. '
                'Please rephrase and try again.';
          throw ContentPolicyException(
            message,
            code: ContentPolicyCode.harmfulContent,
          );
        }
      }
    }

    return capped;
  }

  /// Checks whether the current call frequency is within allowed limits.
  ///
  /// Throws [CallFrequencyException] if the per-minute or per-hour cap is hit.
  /// Call this immediately before every AI provider invocation.
  void checkCallFrequency() {
    final now = DateTime.now();

    // Prune timestamps older than 1 hour
    _callTimestamps.removeWhere(
      (t) => now.difference(t).inSeconds > 3600,
    );

    // Per-minute check (last 60 seconds)
    final lastMinute = _callTimestamps
        .where((t) => now.difference(t).inSeconds <= 60)
        .length;
    if (lastMinute >= maxCallsPerMinute) {
      throw CallFrequencyException(
        'You are sending requests too quickly. Please wait a moment before trying again.',
      );
    }

    // Per-hour check
    if (_callTimestamps.length >= maxCallsPerHour) {
      throw CallFrequencyException(
        'Hourly AI request limit reached. Please try again later.',
      );
    }

    // Record this call
    _callTimestamps.add(now);
  }

  /// Screens AI [output] before it is displayed to the user.
  ///
  /// Throws [ContentPolicyException] with code [ContentPolicyCode.unsafeOutput]
  /// if the response appears to have been jailbroken or contains harmful content.
  void validateOutput(String output) {
    final lower = output.toLowerCase();
    for (final pattern in _unsafeOutputPatterns) {
      if (lower.contains(pattern.toLowerCase())) {
        if (kDebugMode) {
          debugPrint('[AIGuard] Unsafe output pattern detected: "$pattern"');
        }
        throw const ContentPolicyException(
          'The AI response could not be displayed. Please try again.',
          code: ContentPolicyCode.unsafeOutput,
        );
      }
    }
  }

  /// Resets the call-frequency window. Intended for testing only.
  @visibleForTesting
  void resetFrequencyWindow() => _callTimestamps.clear();
}
