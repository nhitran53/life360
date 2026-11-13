part of '../circle_screen.dart';

// ---------------------------------------------------------------------------
// PULSE MAP — rings with members placed around "You"
// ---------------------------------------------------------------------------

class _PulseMap extends StatelessWidget {
  const _PulseMap({required this.members});

  /// Placed around "You" in order; the map has room for [_spots].length.
  final List<CircleMember> members;

  /// Where members sit, straight from the 342×248 design frame.
  static const _spots = [
    Offset(48, 24),
    Offset(248, 40),
    Offset(58, 160),
    Offset(262, 128),
  ];

  @override
  Widget build(BuildContext context) {
    final placed = [
      for (var i = 0; i < members.length && i < _spots.length; i++)
        (member: members[i], spot: _spots[i]),
    ];

    return Container(
      height: 248,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary, width: _outline + 0.5),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 342,
        height: 248,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _svgAt('ring_outer', left: 63, top: 16, size: 216),
            _svgAt('ring_middle', left: 99, top: 52, size: 144),
            _svgAt('ring_inner', left: 135, top: 88, size: 72),
            // Soft red glow behind anyone with a high heart rate.
            for (final (:member, :spot) in placed)
              if (member.highHeartRate) ...[
                _svgAt('glow_outer',
                    left: spot.dx - 8, top: spot.dy - 6, size: 68),
                _svgAt('glow_inner', left: spot.dx, top: spot.dy + 2, size: 52),
              ],
            const Positioned(
              left: 145,
              top: 92,
              child: _MapMember(
                initial: 'You',
                color: CircleColors.avatarYou,
                size: 52,
                badge: _HeartBadge(bpm: circleYouBpm),
              ),
            ),
            for (final (:member, :spot) in placed)
              Positioned(
                left: spot.dx,
                top: spot.dy,
                child: _MapMember(
                  initial: member.initial,
                  color: member.color,
                  ringColor: member.highHeartRate
                      ? CircleColors.alert
                      : member.idle
                      ? CircleColors.idle
                      : AppColors.primarySoft,
                  badge: member.idle
                      ? _TextBadge(
                    text: member.idleFor == null
                        ? 'idle'
                        : 'idle ${member.idleFor}',
                  )
                      : _HeartBadge(
                    bpm: member.bpm,
                    alert: member.highHeartRate,
                  ),
                ),
              ),
            const Positioned(left: 178, top: 213, child: _LiveChip()),
          ],
        ),
      ),
    );
  }

  static Widget _svgAt(
      String name, {
        required double left,
        required double top,
        required double size,
      }) {
    return Positioned(
      left: left,
      top: top,
      child: SvgPicture.asset(
        '$circleAssets/$name.svg',
        width: size,
        height: size,
      ),
    );
  }
}

class _MapMember extends StatelessWidget {
  const _MapMember({
    required this.initial,
    required this.color,
    required this.badge,
    this.size = 44,
    this.ringColor = AppColors.primarySoft,
  });

  final String initial;
  final Color color;
  final Widget badge;
  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MemberAvatar(
          initial: initial,
          color: color,
          size: size,
          fontSize: size > 44 ? 17 : 14,
          ringColor: ringColor,
        ),
        const SizedBox(height: 4),
        badge,
      ],
    );
  }
}

class _HeartBadge extends StatelessWidget {
  const _HeartBadge({required this.bpm, this.alert = false});

  final int bpm;

  /// Red pill for a high heart rate.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      color: alert ? CircleColors.alert : CircleColors.surface,
      children: [
        SvgPicture.asset(
          '$circleAssets/${alert ? 'icon_heart_white' : 'icon_heart'}.svg',
          width: 10,
          height: 10,
        ),
        const SizedBox(width: 3),
        Text(
          '$bpm',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: alert ? Colors.white : CircleColors.heart,
          ),
        ),
      ],
    );
  }
}

class _TextBadge extends StatelessWidget {
  const _TextBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      color: CircleColors.surface,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: CircleColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.children});

  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CircleColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('$circleAssets/live_dot.svg', width: 7, height: 7),
          const SizedBox(width: 6),
          const Text(
            'Live · synced 1 min ago',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: CircleColors.liveText,
            ),
          ),
        ],
      ),
    );
  }
}
