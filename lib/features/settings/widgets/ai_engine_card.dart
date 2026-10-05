import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/ui_kit.dart';
import '../controllers/settings_controller.dart';
import '../models/app_settings_model.dart';
import '../screens/api_key_screen.dart';

class AIEngineCard extends StatefulWidget {
  final AppSettings settings;
  final SettingsController ctrl;

  const AIEngineCard({
    super.key,
    required this.settings,
    required this.ctrl,
  });

  @override
  State<AIEngineCard> createState() => _AIEngineCardState();
}

class _AIEngineCardState extends State<AIEngineCard> {
  late TextEditingController _urlController;
  bool _isPinging = false;
  String? _pingStatus;
  bool? _pingSuccess;
  int? _pingLatencyMs;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.settings.cloudGatewayUrl,
    );
  }

  @override
  void didUpdateWidget(covariant AIEngineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.cloudGatewayUrl != widget.settings.cloudGatewayUrl &&
        _urlController.text != widget.settings.cloudGatewayUrl) {
      _urlController.text = widget.settings.cloudGatewayUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pingGateway() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _pingSuccess = false;
        _pingStatus = 'Gateway URL is empty';
        _pingLatencyMs = null;
      });
      return;
    }

    setState(() {
      _isPinging = true;
      _pingStatus = 'Pinging gateway...';
      _pingSuccess = null;
      _pingLatencyMs = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final base = rawUrl.endsWith('/') ? rawUrl.substring(0, rawUrl.length - 1) : rawUrl;
      final healthUri = Uri.parse('$base/health');
      final res = await http.get(healthUri).timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final version = data['version'] ?? '3.0.0';
        final status = data['status'] ?? 'healthy';
        setState(() {
          _isPinging = false;
          _pingSuccess = true;
          _pingLatencyMs = stopwatch.elapsedMilliseconds;
          _pingStatus = '$status (v$version)';
        });
      } else {
        setState(() {
          _isPinging = false;
          _pingSuccess = false;
          _pingLatencyMs = stopwatch.elapsedMilliseconds;
          _pingStatus = 'HTTP ${res.statusCode}';
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _isPinging = false;
        _pingSuccess = false;
        _pingLatencyMs = null;
        _pingStatus = 'Unreachable (${e.runtimeType})';
      });
    }
  }

  static String _formatTokens(int t) {
    if (t >= 1000000) return '${(t / 1000000).toStringAsFixed(1)}M';
    if (t >= 1000) return '${(t / 1000).round()}K';
    return '$t';
  }

  static const _tokenOptions = [10000, 50000, 100000, 250000, 500000];

  void _showTokenPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Daily Token Limit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : kDark0,
                  ),
                ),
                const SizedBox(height: 12),
                ..._tokenOptions.map((opt) {
                  final selected = widget.settings.maxTokensPerDay == opt;
                  return ListTile(
                    title: Text(
                      '${_formatTokens(opt)} tokens / day',
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? kIndigo : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: kIndigo)
                        : null,
                    onTap: () {
                      widget.ctrl.updateMaxTokensPerDay(opt);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMode = widget.settings.aiConnectionMode;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kIndigo, kCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Assistant Connection',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : kDark0,
                      ),
                    ),
                    Text(
                      'Choose how AutoPlanner powers your smart scheduling',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3-way Architecture Switcher
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withAlpha(45) : Colors.grey.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildModeTab(
                  mode: 'direct_gemini',
                  title: 'Gemini Key',
                  icon: Icons.key_rounded,
                  selected: currentMode == 'direct_gemini',
                  isDark: isDark,
                ),
                _buildModeTab(
                  mode: 'offline_mock',
                  title: 'Offline Mode',
                  icon: Icons.offline_bolt_rounded,
                  selected: currentMode == 'offline_mock' || widget.settings.useMockAI,
                  isDark: isDark,
                ),
                _buildModeTab(
                  mode: 'cloud_gateway',
                  title: 'Custom Server',
                  icon: Icons.dns_rounded,
                  selected: currentMode == 'cloud_gateway',
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Dynamic Body based on Mode
          if (currentMode == 'cloud_gateway') ...[
            _buildGatewayConfigSection(isDark),
          ] else if (currentMode == 'direct_gemini') ...[
            _buildByokSection(isDark),
          ] else ...[
            _buildMockSection(isDark),
          ],

          const SizedBox(height: 14),

          // ── Autonomous Schedule Drift Subcard ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(7) : Colors.black.withAlpha(5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: kCoral, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Automatic Schedule Catch-Up',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: isDark ? Colors.white : kDark0,
                        ),
                      ),
                    ),
                    Switch(
                      value: widget.settings.autoRippleDrift,
                      onChanged: (v) => widget.ctrl.updateAutoRippleDrift(v),
                      activeThumbColor: kCoral,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                Text(
                  'When tasks run over time, automatically shifts subsequent tasks forward without overlapping meetings',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 10),

                // Grace window wrap (Never overflows!)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Sensitivity: ',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: [5, 10, 15, 30].map((mins) {
                          final isSelected = widget.settings.driftGraceMinutes == mins;
                          return ChoiceChip(
                            label: Text('${mins}m'),
                            selected: isSelected,
                            onSelected: (_) => widget.ctrl.updateDriftGraceMinutes(mins),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            labelStyle: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            selectedColor: kIndigo,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Collapsible Advanced Safeguards & Telemetry ──
          GestureDetector(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  Icon(
                    _showAdvanced
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AI Telemetry & Token Safeguards',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showAdvanced) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    secondary: Icon(
                      Icons.receipt_long_outlined,
                      color: isDark ? Colors.white60 : Colors.black54,
                      size: 18,
                    ),
                    title: Text(
                      'Log AI Operations',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : kDark0,
                      ),
                    ),
                    subtitle: Text(
                      'Records prompt telemetry & token usage',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    value: widget.settings.enableAILogging,
                    onChanged: (v) => widget.ctrl.updateEnableAILogging(v),
                    activeThumbColor: kIndigo,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      Icons.token_outlined,
                      color: isDark ? Colors.white60 : Colors.black54,
                      size: 18,
                    ),
                    title: Text(
                      'Daily Token Limit',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : kDark0,
                      ),
                    ),
                    subtitle: Text(
                      '${_formatTokens(widget.settings.maxTokensPerDay)} tokens / day',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 16),
                    onTap: () => _showTokenPicker(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String mode,
    required String title,
    required IconData icon,
    required bool selected,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          widget.ctrl.updateAIConnectionMode(mode);
          if (mode == 'offline_mock') {
            widget.ctrl.updateUseMockAI(true);
          } else {
            widget.ctrl.updateUseMockAI(false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? kIndigo.withAlpha(160) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? (isDark ? Colors.white : kIndigo)
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? (isDark ? Colors.white : kDark0)
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGatewayConfigSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(7) : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Gateway URL',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const Spacer(),
              // Preset chip
              GestureDetector(
                onTap: () {
                  _urlController.text = 'http://127.0.0.1:8000';
                  widget.ctrl.updateCloudGatewayUrl('http://127.0.0.1:8000');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kCyan.withAlpha(25),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'Local :8000',
                    style: TextStyle(fontSize: 10, color: kCyan, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _urlController,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : kDark0,
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://gateway-xxx.a.run.app',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white30 : Colors.black26,
                        fontSize: 11,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: isDark ? Colors.black.withAlpha(40) : Colors.grey.withAlpha(20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kIndigo),
                      ),
                    ),
                    onSubmitted: (val) => widget.ctrl.updateCloudGatewayUrl(val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: _isPinging ? null : _pingGateway,
                  icon: _isPinging
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bolt_rounded, size: 15),
                  label: Text(
                    _isPinging ? '...' : 'Ping',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kIndigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),

          // Ping status feedback
          if (_pingStatus != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _pingSuccess == true
                    ? Colors.green.withAlpha(25)
                    : (_pingSuccess == false
                        ? Colors.red.withAlpha(25)
                        : Colors.blue.withAlpha(25)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _pingSuccess == true
                      ? Colors.green.withAlpha(100)
                      : (_pingSuccess == false
                          ? Colors.red.withAlpha(100)
                          : Colors.blue.withAlpha(100)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _pingSuccess == true
                        ? Icons.check_circle_rounded
                        : (_pingSuccess == false
                            ? Icons.error_outline_rounded
                            : Icons.hourglass_top_rounded),
                    size: 13,
                    color: _pingSuccess == true
                        ? Colors.green
                        : (_pingSuccess == false ? Colors.red : Colors.blue),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _pingStatus!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _pingSuccess == true
                            ? Colors.green
                            : (_pingSuccess == false ? Colors.red : Colors.blue),
                      ),
                    ),
                  ),
                  if (_pingLatencyMs != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${_pingLatencyMs}ms)',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildByokSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(7) : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(10),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.key_rounded,
            size: 18,
            color: widget.settings.geminiApiKey.isNotEmpty ? kCyan : kCoral,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google Gemini Key',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : kDark0,
                  ),
                ),
                Text(
                  widget.settings.geminiApiKey.isNotEmpty
                      ? '••••••••${widget.settings.geminiApiKey.length > 4 ? widget.settings.geminiApiKey.substring(widget.settings.geminiApiKey.length - 4) : ''} (Connected)'
                      : 'Free key from Google AI Studio. Stored privately on your device.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApiKeyScreen()),
            ),
            child: const Text('Manage', style: TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildMockSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withAlpha(70)),
      ),
      child: const Row(
        children: [
          Icon(Icons.offline_pin_rounded, color: Colors.amber, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline Mode active. Intelligent scheduling and day planning run on-device with no internet needed.',
              style: TextStyle(fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
