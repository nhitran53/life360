import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The building block behind every "3D" button, card and chip.
///
/// A flat face sits on a solid, darker edge. When pressed, the face slides
/// down onto the edge. The total height never changes, so pressing doesn't
/// push surrounding content around.
class ChunkySurface extends StatefulWidget {
  const ChunkySurface({
    super.key,
    required this.child,
    required this.color,
    required this.edgeColor,
    this.borderColor,
    this.depth = AppDepth.card,
    this.radius = AppRadius.card,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final Color color;
  final Color edgeColor;

  /// Optional 2px outline around the face (used by white cards).
  final Color? borderColor;
  final double depth;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Null makes the surface static (no press animation, not focusable).
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<ChunkySurface> createState() => _ChunkySurfaceState();
}

class _ChunkySurfaceState extends State<ChunkySurface> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _activate() {
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final down = interactive && _pressed;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final radius = BorderRadius.circular(widget.radius);
    final border = widget.borderColor;

    Widget surface = Stack(
      // Let the face fill whatever width the parent gives it.
      fit: StackFit.passthrough,
      children: [
        // The edge: same shape as the face, shifted down by [depth].
        Positioned.fill(
          top: widget.depth,
          child: DecoratedBox(
            decoration: BoxDecoration(color: widget.edgeColor, borderRadius: radius),
          ),
        ),
        AnimatedPadding(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 70),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            top: down ? widget.depth : 0,
            bottom: down ? 0 : widget.depth,
          ),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: radius,
              border: border == null ? null : Border.all(color: border, width: 2),
            ),
            child: widget.child,
          ),
        ),
      ],
    );

    if (!interactive) return surface;

    if (_focused) {
      surface = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: AppColors.blue, width: 3),
        ),
        child: surface,
      );
    }

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      onTap: _activate,
      // An explicit label replaces whatever text is inside.
      excludeSemantics: widget.semanticLabel != null,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: _activate,
          child: surface,
        ),
      ),
    );
  }
}

/// Big, chunky call-to-action button.
class ChunkyButton extends StatelessWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primary,
    this.edgeColor = AppColors.primaryDark,
    this.foregroundColor = Colors.white,
    this.icon,
    this.expand = true,
  });

  /// White button with an outline, for secondary actions.
  const ChunkyButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  })  : color = AppColors.surface,
        edgeColor = AppColors.border,
        foregroundColor = AppColors.blue;

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final Color color;
  final Color edgeColor;
  final Color foregroundColor;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final secondary = color == AppColors.surface;
    final fg = enabled ? foregroundColor : AppColors.muted;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg),
          ),
        ),
      ],
    );

    final surface = ChunkySurface(
      color: enabled ? color : AppColors.border,
      edgeColor: enabled ? edgeColor : AppColors.borderDark,
      borderColor: secondary && enabled ? AppColors.border : null,
      depth: AppDepth.button,
      radius: AppRadius.button,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: onPressed,
      child: SizedBox(height: 50, child: Center(child: content)),
    );

    return enabled
        ? surface
        : Semantics(button: true, enabled: false, child: surface);
  }
}

/// White card with a light outline and a chunky bottom edge.
///
/// Pass [onTap] to make the whole card pressable.
class ChunkyCard extends StatelessWidget {
  const ChunkyCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.edgeColor = AppColors.border,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final Color edgeColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ChunkySurface(
      color: color,
      edgeColor: edgeColor,
      borderColor: borderColor,
      padding: padding,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}
