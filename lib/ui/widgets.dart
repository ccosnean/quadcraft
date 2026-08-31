import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Metal plate used for shape wells, thumbnails and cards.
///
/// [sunken] swaps the elevated look (a gradient fill, dropped shadow — "this
/// floats above the page") for an engraved one (a flat fill, an inset-shadow
/// gradient — "this is cut into the page"). The board uses the sunken form so
/// the one surface that is genuinely a physical object on screen reads as
/// carved into the machine rather than floating a card above it.
class Plate extends StatelessWidget {
  const Plate({
    super.key,
    required this.child,
    this.radius = 26,
    this.glow = 0.0,
    this.glowColor,
    this.padding = EdgeInsets.zero,
    this.sunken = false,
  });

  final Widget child;
  final double radius;

  /// 0..1 drop-target or celebration highlight.
  final double glow;
  final Color? glowColor;
  final EdgeInsets padding;
  final bool sunken;

  @override
  Widget build(BuildContext context) {
    final accent = glowColor ?? Palette.brass;
    final borderRadius = BorderRadius.circular(radius);

    if (sunken) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: Color.lerp(Palette.hairline, accent, glow * 0.9)!,
            width: 1 + glow * 0.6,
          ),
          boxShadow: glow > 0
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22 * glow),
                    blurRadius: 22 * glow,
                    spreadRadius: 1.5 * glow,
                  ),
                ]
              : const [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(math.max(0, radius - 1)),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              const ColoredBox(color: Palette.panelSunken),
              // Light doesn't reach the bottom of a well: a shadow fading in
              // from the top is the cue that this is cut in, not stuck on.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Colors.transparent],
                      stops: [0.0, 0.26],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0x0DFFFFFF), Colors.transparent],
                      stops: [0.0, 0.2],
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
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
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

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
    style: Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: color ?? Palette.inkFaint),
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
    this.danger = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool danger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = primary
        ? const Color(0xFF20170A)
        : (enabled ? Palette.ink : Palette.inkFaint);
    final fill = primary
        ? Palette.brass
        : danger
        ? const Color(0xFF3A1A18)
        : Palette.panelRaised;
    final stroke = primary
        ? Palette.brassBright.withValues(alpha: 0.7)
        : danger
        ? Palette.danger.withValues(alpha: 0.7)
        : Palette.hairline;

    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: danger && !primary ? Palette.danger : foreground,
    );
    final labelText = Text(
      label.toUpperCase(),
      maxLines: 1,
      softWrap: false,
      style: labelStyle,
    );

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: danger && !primary ? Palette.danger : foreground,
          ),
          const SizedBox(width: 8),
        ],
        if (expand)
          Flexible(
            child: FittedBox(fit: BoxFit.scaleDown, child: labelText),
          )
        else
          labelText,
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: fill,
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
              border: Border.all(color: stroke),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Flat icon control used in the play screen's tool row.
///
/// Sits flush against its neighbours — the row supplies the seam between
/// tools — rather than reading as its own bordered chip. A small dot below
/// the label stands in for the old accent border, marking a tool this level
/// has taught.
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
        : Palette.inkMuted;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 21, color: tint),
                  const SizedBox(height: 6),
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tint,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 4,
                    height: 4,
                    child: accent && enabled
                        ? const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Palette.brassBright,
                            ),
                          )
                        : null,
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
