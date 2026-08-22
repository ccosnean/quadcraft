import 'package:flutter/material.dart';

import 'theme.dart';

/// Sunken metal plate used for the board and every shape well.
class Plate extends StatelessWidget {
  const Plate({
    super.key,
    required this.child,
    this.radius = 26,
    this.glow = 0.0,
    this.glowColor,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;

  /// 0..1 drop-target or celebration highlight.
  final double glow;
  final Color? glowColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final accent = glowColor ?? Palette.brass;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.panelSunken, Color(0xFF0A1115)],
        ),
        border: Border.all(
          color: Color.lerp(Palette.hairline, accent, glow * 0.9)!,
          width: 1.2 + glow,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          if (glow > 0)
            BoxShadow(
              color: accent.withValues(alpha: 0.28 * glow),
              blurRadius: 26 * glow,
              spreadRadius: 2 * glow,
            ),
        ],
      ),
      child: child,
    );
  }
}

/// Raised surface used for header and tray panels.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.panelRaised, Palette.panel],
        ),
        border: Border.all(color: Palette.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// All-caps tracking label used above groups.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color ?? Palette.inkFaint),
      );
}

/// Primary/secondary action button with a machined look.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = primary
        ? const Color(0xFF20170A)
        : (enabled ? Palette.ink : Palette.inkFaint);

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
        ],
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: primary ? Palette.brass : Palette.panelRaised,
        borderRadius: BorderRadius.circular(16),
        elevation: primary ? 6 : 0,
        shadowColor: Palette.brass.withValues(alpha: 0.5),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primary ? Palette.brassBright.withValues(alpha: 0.7) : Palette.hairline,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Square icon control used in the play screen's tool row.
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tint = !enabled
        ? Palette.inkFaint
        : accent
            ? Palette.brassBright
            : Palette.ink;

    return Semantics(
      button: true,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 66,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Palette.panel,
                border: Border.all(
                  color: accent && enabled
                      ? Palette.brassDim
                      : Palette.hairline,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon, size: 22, color: tint),
                  const SizedBox(height: 4),
                  Text(
                    label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: tint,
                          fontSize: 9,
                          letterSpacing: 1.1,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label plus value, used for move/time readouts.
class Readout extends StatelessWidget {
  const Readout({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Overline(label),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.monoDigits.copyWith(
            fontSize: 20,
            color: highlight ? Palette.brassBright : Palette.ink,
          ),
        ),
        if (hint != null)
          Text(hint!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  if (minutes >= 60) {
    final hours = duration.inHours;
    return '$hours:${(minutes % 60).toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
