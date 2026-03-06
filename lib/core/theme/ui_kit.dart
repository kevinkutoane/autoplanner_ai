import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

// ── Brand palette ─────────────────────────────────────────────────────────────
const kIndigo = Color(0xFF6C63FF);
const kCyan = Color(0xFF00D4AA);
const kCoral = Color(0xFFFF6B6B);
const kAmber = Color(0xFFFFD93D);
const kDark0 = Color(0xFF0A0A1A);
const kDark1 = Color(0xFF12122A);
const kLight0 = Color(0xFFF0F0FF);
const kLight1 = Color(0xFFE8F4FD);

const kGradientMain = LinearGradient(
  colors: [kIndigo, kCyan],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kGradientWarm = LinearGradient(
  colors: [kCoral, kAmber],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);
const kGradientHero = LinearGradient(
  colors: [Color(0xFF1A1A2E), kIndigo],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kGradientTeal = LinearGradient(
  colors: [kCyan, kIndigo],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ── Animated orb background ─────────────────────────────────────────────────
class OrbBackground extends StatefulWidget {
  final Widget child;
  final bool subtle;
  const OrbBackground({super.key, required this.child, this.subtle = false});

  @override
  State<OrbBackground> createState() => _OrbBackgroundState();
}

class _OrbBackgroundState extends State<OrbBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [kDark0, kDark1]
                  : const [kLight0, kLight1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _OrbPainter(_ctrl.value, isDark, widget.subtle),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final bool isDark;
  final bool subtle;
  _OrbPainter(this.t, this.isDark, this.subtle);

  @override
  void paint(Canvas canvas, Size size) {
    final a = subtle ? 0.6 : 1.0;
    final orbs = [
      _O(
        0.15 + 0.12 * math.sin(t * math.pi * 2),
        0.12 + 0.07 * math.cos(t * math.pi * 2),
        200,
        isDark
            ? Color((0x20 * a).round() << 24 | 0x6C63FF)
            : Color((0x18 * a).round() << 24 | 0x6C63FF),
      ),
      _O(
        0.82 + 0.08 * math.cos(t * math.pi * 2 + 1.5),
        0.22 + 0.10 * math.sin(t * math.pi * 2 + 1.5),
        160,
        isDark
            ? Color((0x18 * a).round() << 24 | 0x00D4AA)
            : Color((0x14 * a).round() << 24 | 0x00D4AA),
      ),
      _O(
        0.50 + 0.18 * math.sin(t * math.pi * 2 + 3.0),
        0.68 + 0.09 * math.cos(t * math.pi * 2 + 3.0),
        140,
        isDark
            ? Color((0x18 * a).round() << 24 | 0xFF6B6B)
            : Color((0x10 * a).round() << 24 | 0xFF6B6B),
      ),
    ];
    for (final o in orbs) {
      canvas.drawCircle(
        Offset(o.cx * size.width, o.cy * size.height),
        o.r,
        Paint()
          ..shader = RadialGradient(colors: [o.c, o.c.withAlpha(0)])
              .createShader(
                Rect.fromCircle(
                  center: Offset(o.cx * size.width, o.cy * size.height),
                  radius: o.r,
                ),
              ),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter o) => o.t != t;
}

class _O {
  final double cx, cy, r;
  final Color c;
  _O(this.cx, this.cy, this.r, this.c);
}

// ── Gradient header ───────────────────────────────────────────────────────────
class GradientHeader extends StatelessWidget {
  final Widget child;
  final LinearGradient gradient;
  final double extraTop;
  const GradientHeader({
    super.key,
    required this.child,
    this.gradient = kGradientHero,
    this.extraTop = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + extraTop,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          child,
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withAlpha(18)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

// ── Glass card ────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: d ? Colors.white.withAlpha(12) : Colors.white.withAlpha(170),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: d
                  ? Colors.white.withAlpha(28)
                  : Colors.white.withAlpha(210),
              width: 1,
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

// ── Gradient stat card ────────────────────────────────────────────────────────
class GradStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;
  const GradStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradient[0].withAlpha(d ? 55 : 38),
                  gradient[1].withAlpha(d ? 32 : 22),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: gradient[0].withAlpha(d ? 65 : 52),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      LinearGradient(colors: gradient).createShader(b),
                  child: Icon(icon, size: 20, color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: d ? Colors.white : kDark0,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: d
                        ? Colors.white.withAlpha(140)
                        : const Color(0xFF7C7C8A),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Gradient button ───────────────────────────────────────────────────────────
class GradBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final LinearGradient gradient;
  final double height;
  const GradBtn({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.gradient = kGradientMain,
    this.height = 52,
  });

  @override
  State<GradBtn> createState() => _GradBtnState();
}

class _GradBtnState extends State<GradBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) =>
            Transform.scale(scale: 1 - 0.02 * _c.value, child: child),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withAlpha(70),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ghost button ──────────────────────────────────────────────────────────────
class GhostBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  const GhostBtn({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final fg = d ? Colors.white.withAlpha(160) : const Color(0xFF7C7C8A);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: d ? Colors.white.withAlpha(35) : Colors.black.withAlpha(22),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glass filter chip ─────────────────────────────────────────────────────────
class GlassChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final List<Color> activeGradient;
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    this.activeGradient = const [kIndigo, kCyan],
  });

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: activeGradient) : null,
          color: selected
              ? null
              : (d ? Colors.white.withAlpha(14) : Colors.black.withAlpha(7)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? activeGradient[0].withAlpha(0)
                : (d ? Colors.white.withAlpha(22) : Colors.black.withAlpha(14)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected
                    ? Colors.white
                    : (d
                          ? Colors.white.withAlpha(160)
                          : const Color(0xFF7C7C8A)),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? Colors.white
                    : (d
                          ? Colors.white.withAlpha(160)
                          : const Color(0xFF7C7C8A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const SectionLabel({
    super.key,
    required this.icon,
    required this.label,
    this.color = kIndigo,
  });

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(d ? 40 : 25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── Shimmer box ───────────────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: d
                ? [
                    Colors.white.withAlpha(14),
                    Colors.white.withAlpha(28),
                    Colors.white.withAlpha(14),
                  ]
                : [
                    Colors.black.withAlpha(8),
                    Colors.black.withAlpha(16),
                    Colors.black.withAlpha(8),
                  ],
            stops: [
              (_c.value - 0.3).clamp(0.0, 1.0),
              _c.value.clamp(0.0, 1.0),
              (_c.value + 0.3).clamp(0.0, 1.0),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

// ── Stagger wrapper ───────────────────────────────────────────────────────────
class Stagger extends StatefulWidget {
  final int index;
  final Widget child;
  final double baseDelay;
  const Stagger({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = 80,
  });

  @override
  State<Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<Stagger> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(
      Duration(milliseconds: (widget.index * widget.baseDelay).round()),
      () {
        if (mounted) _c.forward();
      },
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Glass text field ──────────────────────────────────────────────────────────
class GlassField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final IconData? icon;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final String? hintText;
  final bool readOnly;

  const GlassField({
    super.key,
    this.controller,
    required this.label,
    this.icon,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
    this.maxLines = 1,
    this.hintText,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: d ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: d ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        onChanged: onChanged,
        maxLines: maxLines,
        readOnly: readOnly,
        style: TextStyle(color: d ? Colors.white : kDark0, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(
            color: d ? Colors.white.withAlpha(120) : const Color(0xFF7C7C8A),
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            color: d ? Colors.white.withAlpha(80) : Colors.black.withAlpha(60),
            fontSize: 14,
          ),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: kIndigo)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// ── Section header (body section divider) ────────────────────────────────────
class BodySectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  const BodySectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: d ? Colors.white : kDark0,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kCyan.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trailing!,
                  style: const TextStyle(
                    color: kCyan,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (b) =>
                const LinearGradient(colors: [kIndigo, kCyan]).createShader(b),
            child: Icon(icon, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: d ? Colors.white.withAlpha(140) : const Color(0xFF7C7C8A),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
