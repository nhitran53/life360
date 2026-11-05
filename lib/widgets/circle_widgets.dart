import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/circle_colors.dart';

// ---------------------------------------------------------------------------
// Shared pieces of the Circle screens (home, member detail, nudge, privacy).
// ---------------------------------------------------------------------------

const circleAssets = 'assets/circle';

/// An SVG from `assets/circle/` at its design size.
class CircleSvg extends StatelessWidget {
  const CircleSvg(this.name, {super.key, required this.size, this.height});

  final String name;
  final double size;

  /// Defaults to [size] (square icons).
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      '$circleAssets/$name.svg',
      width: size,
      height: height ?? size,
    );
  }
}

// ---------------------------------------------------------------------------
// AVATAR — colored circle with an initial
// ---------------------------------------------------------------------------

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.initial,
    required this.color,
    this.size = 44,
    this.fontSize = 14,
    this.ringColor,
  });

  final String initial;
  final Color color;
  final double size;
  final double fontSize;

  /// Optional 3px ring (used on the pulse map).
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final isYou = color == CircleColors.avatarYou;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!, width: 3),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: isYou ? Colors.white : CircleColors.ink,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CARD + TITLES
// ---------------------------------------------------------------------------

/// White rounded card with a hairline border.
class CircleCard extends StatelessWidget {
  const CircleCard({
    super.key,
    required this.radius,
    required this.padding,
    required this.child,
  });

  final double radius;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: CircleColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: CircleColors.border),
      ),
      child: child,
    );
  }
}

/// Big page title with a one-line subtitle ("Send a nudge", "Sharing & privacy").
class CircleTitle extends StatelessWidget {
  const CircleTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: CircleColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CircleColors.secondary,
          ),
        ),
      ],
    );
  }
}

/// Small grey label above a group ("To", "Quick notes", "What you share").
class CircleSectionLabel extends StatelessWidget {
  const CircleSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: CircleColors.secondary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BUTTONS — dark filled pill and white outlined pill
// ---------------------------------------------------------------------------

class CirclePillButton extends StatelessWidget {
  const CirclePillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconSize = 16,
    this.height = 36,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w700,
    this.horizontalPadding = 14,
    this.filled = false,
    this.borderColor = CircleColors.outline,
    this.textColor = CircleColors.ink,
  });

  final String label;
  final VoidCallback onPressed;

  /// SVG asset name shown before the label.
  final String? icon;
  final double iconSize;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final double horizontalPadding;

  /// Dark ink fill with white text; otherwise white with an outline.
  final bool filled;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    final icon = this.icon;

    return Material(
      color: filled ? CircleColors.ink : CircleColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: filled ? BorderSide.none : BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                CircleSvg(icon, size: iconSize),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    color: filled ? Colors.white : textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB BAR — Circle / Ranks / Nudges / Privacy
// ---------------------------------------------------------------------------

enum CircleTab { circle, ranks, nudges, privacy }

class CircleTabBar extends StatelessWidget {
  const CircleTabBar({super.key, required this.active, required this.onSelect});

  final CircleTab active;
  final ValueChanged<CircleTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      decoration: const BoxDecoration(
        color: CircleColors.surface,
        border: Border(top: BorderSide(color: CircleColors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final tab in CircleTab.values)
              _Tab(tab: tab, active: tab == active, onTap: () => onSelect(tab)),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.active, required this.onTap});

  final CircleTab tab;
  final bool active;
  final VoidCallback onTap;

  static const _labels = {
    CircleTab.circle: 'Circle',
    CircleTab.ranks: 'Ranks',
    CircleTab.nudges: 'Nudges',
    CircleTab.privacy: 'Privacy',
  };

  // Design exports: dark icon when active, grey when not. Ranks is never
  // active yet, so it only has the grey one.
  static const _icons = {
    CircleTab.circle: ('tab_circle', 'tab_circle_inactive'),
    CircleTab.ranks: ('tab_ranks', 'tab_ranks'),
    CircleTab.nudges: ('tab_nudges_active', 'tab_nudges'),
    CircleTab.privacy: ('tab_privacy_active', 'tab_privacy'),
  };

  @override
  Widget build(BuildContext context) {
    final (activeIcon, inactiveIcon) = _icons[tab]!;

    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleSvg(active ? activeIcon : inactiveIcon, size: 22),
              const SizedBox(height: 3),
              Text(
                _labels[tab]!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  color: active ? CircleColors.ink : CircleColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------

/// 38412 → "38,412".
String formatNumber(int n) {
  final digits = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

void showCircleSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
