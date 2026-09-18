import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';

class AiCoachScreen extends ConsumerStatefulWidget {
  const AiCoachScreen({super.key});

  @override
  ConsumerState<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends ConsumerState<AiCoachScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'content': 'Hi! I am your AI Coach. How can I help you plan your day, overcome procrastination, or reflect on your goals?',
    });
  }

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    final aiService = ref.read(aiServiceProvider);

    try {
      final response = await aiService.chatWithCoach(text, _messages);
      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Error processing your request: $e',
        });
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _cleanMessageContent(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final list = jsonDecode(trimmed);
        if (list is List && list.isNotEmpty && list.first is Map) {
          final buffer = StringBuffer('Here is the action plan suggested for your schedule:\n\n');
          for (final item in list) {
            if (item is Map) {
              final title = item['title'] ?? 'Task';
              final time = item['startTime'] != null ? ' (${item['startTime']})' : '';
              final est = item['estimatedMinutes'] != null ? ' · ${item['estimatedMinutes']}m' : '';
              buffer.writeln('• **$title**$time$est');
            }
          }
          buffer.writeln('\nWould you like me to help you schedule these into AutoPlanner?');
          return buffer.toString();
        }
      } catch (_) {}
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientHeader(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(30),
                      border: Border.all(color: Colors.white.withAlpha(60)),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Coach & Tutor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your personal productivity assistant',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (_messages.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                      ),
                      tooltip: 'Reset Conversation',
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _messages.add({
                            'role': 'assistant',
                            'content':
                                'Hi! I am your AI Coach. How can I help you plan your day, overcome procrastination, or reflect on your goals?',
                          });
                        });
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _TypingBubble(isDark: isDark);
                  }

                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  final displayContent = _cleanMessageContent(msg['content'] ?? '');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisAlignment: isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser) ...[
                          Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE94057).withAlpha(80),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.smart_toy_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.74,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              gradient: isUser
                                  ? const LinearGradient(colors: [kIndigo, kCyan])
                                  : LinearGradient(
                                      colors: isDark
                                          ? [
                                              Colors.white.withAlpha(16),
                                              Colors.white.withAlpha(12),
                                            ]
                                          : [Colors.white, Colors.white],
                                    ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(isUser ? 18 : 4),
                                topRight: Radius.circular(isUser ? 4 : 18),
                                bottomLeft: const Radius.circular(18),
                                bottomRight: const Radius.circular(18),
                              ),
                              border: !isUser
                                  ? Border.all(
                                      color: isDark
                                          ? Colors.white.withAlpha(25)
                                          : Colors.black.withAlpha(12),
                                    )
                                  : null,
                              boxShadow: [
                                if (!isUser && !isDark)
                                  BoxShadow(
                                    color: Colors.black.withAlpha(10),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                if (isUser)
                                  BoxShadow(
                                    color: kIndigo.withAlpha(isDark ? 60 : 35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child: Text(
                              displayContent,
                              style: TextStyle(
                                color: isUser
                                    ? Colors.white
                                    : (isDark ? Colors.white : kDark0),
                                height: 1.45,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                        if (isUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [kIndigo, kCyan],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kCyan.withAlpha(80),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_messages.length <= 2)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _PromptChip(
                      label: '🗓️ Plan my day',
                      isDark: isDark,
                      onTap: () {
                        _ctrl.text =
                            'Can you help me structure my day for maximum productivity?';
                        _sendMessage();
                      },
                    ),
                    _PromptChip(
                      label: '⚡ Beat procrastination',
                      isDark: isDark,
                      onTap: () {
                        _ctrl.text =
                            'I feel stuck on a difficult task. How do I get momentum?';
                        _sendMessage();
                      },
                    ),
                    _PromptChip(
                      label: '🎯 Lock in Big 3',
                      isDark: isDark,
                      onTap: () {
                        _ctrl.text =
                            'Help me pick my Big 3 must-complete tasks for today.';
                        _sendMessage();
                      },
                    ),
                    _PromptChip(
                      label: '🧘 Flow state tips',
                      isDark: isDark,
                      onTap: () {
                        _ctrl.text =
                            'What is the best way to maintain deep focus without burnout?';
                        _sendMessage();
                      },
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        style: TextStyle(color: isDark ? Colors.white : kDark0),
                        decoration: InputDecoration(
                          hintText: 'Ask me anything...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: ShaderMask(
                        shaderCallback: (b) =>
                            const LinearGradient(colors: [kIndigo, kCyan])
                                .createShader(b),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _PromptChip({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(16) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(30)
                : Colors.black.withAlpha(20),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : kDark0,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  final bool isDark;
  const _TypingBubble({required this.isDark});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF8A2387), Color(0xFFE94057)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE94057).withAlpha(80),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withAlpha(16)
                  : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: widget.isDark
                    ? Colors.white.withAlpha(25)
                    : Colors.black.withAlpha(12),
              ),
              boxShadow: [
                if (!widget.isDark)
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0.0),
                const SizedBox(width: 4),
                _buildDot(0.2),
                const SizedBox(width: 4),
                _buildDot(0.4),
                const SizedBox(width: 10),
                Text(
                  'AI Coach is thinking…',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = (_controller.value - delay) % 1.0;
        final bounce = (math.sin(t * math.pi * 2) + 1.0) / 2.0;
        return Transform.translate(
          offset: Offset(0, -3.5 * bounce),
          child: Container(
            width: 6.5,
            height: 6.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE94057).withAlpha((130 + 125 * bounce).round()),
            ),
          ),
        );
      },
    );
  }
}
