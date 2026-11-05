import 'package:flutter/material.dart';

import '../data/mock_circle.dart';
import '../theme/circle_colors.dart';
import '../widgets/circle_widgets.dart';

// ---------------------------------------------------------------------------
// SEND A NUDGE — pick someone, pick or write a note, optionally add a challenge
// ---------------------------------------------------------------------------

class NudgeScreen extends StatefulWidget {
  const NudgeScreen({super.key, this.initialRecipient});

  /// Defaults to the first person in [circleNudgeMembers].
  final CircleMember? initialRecipient;

  @override
  State<NudgeScreen> createState() => _NudgeScreenState();
}

class _NudgeScreenState extends State<NudgeScreen> {
  late CircleMember _recipient =
      widget.initialRecipient ?? circleNudgeMembers.first;

  /// Index into [circleQuickNotes], or null once the note is edited by hand.
  int? _quickNote = 0;

  late final _note = TextEditingController(text: circleQuickNotes.first);

  bool _challenge = true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _pickNote(int index) {
    setState(() {
      _quickNote = index;
      _note.text = circleQuickNotes[index];
    });
  }

  void _onNoteEdited(String text) {
    final match = circleQuickNotes.indexOf(text);
    setState(() => _quickNote = match == -1 ? null : match);
  }

  void _send() {
    if (_note.text.trim().isEmpty) {
      showCircleSnack(context, 'Write a quick note first ✍️');
      return;
    }
    FocusScope.of(context).unfocus();
    showCircleSnack(context, 'Nudge sent to ${_recipient.name} 👋');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CircleTitle(
            title: 'Send a nudge',
            subtitle: 'A friendly note to get someone moving',
          ),
          const SizedBox(height: 14),

          // TO
          const CircleSectionLabel('To'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final member in circleNudgeMembers) ...[
                  if (member != circleNudgeMembers.first)
                    const SizedBox(width: 6),
                  _RecipientChip(
                    member: member,
                    selected: member == _recipient,
                    onTap: () => setState(() => _recipient = member),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _recipient.nudgeHint,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CircleColors.secondary,
            ),
          ),
          const SizedBox(height: 14),

          // QUICK NOTES
          const CircleSectionLabel('Quick notes'),
          for (var i = 0; i < circleQuickNotes.length; i++) ...[
            const SizedBox(height: 8),
            _QuickNote(
              text: circleQuickNotes[i],
              selected: i == _quickNote,
              onTap: () => _pickNote(i),
            ),
          ],
          const SizedBox(height: 14),

          // YOUR NOTE
          const CircleSectionLabel('Your note'),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: CircleColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CircleColors.outline),
            ),
            child: TextField(
              controller: _note,
              onChanged: _onNoteEdited,
              minLines: 2,
              maxLines: 4,
              maxLength: 140,
              buildCounter: (
                _, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 15,
                height: 21 / 15,
                fontWeight: FontWeight.w500,
                color: CircleColors.ink,
              ),
              decoration: const InputDecoration.collapsed(
                hintText: 'Write something encouraging…',
              ),
            ),
          ),
          const SizedBox(height: 14),

          // CHALLENGE
          _ChallengeToggle(
            value: _challenge,
            onChanged: (v) => setState(() => _challenge = v),
          ),
          const SizedBox(height: 14),

          CirclePillButton(
            label: 'Send to ${_recipient.name}',
            icon: 'icon_send_18',
            iconSize: 18,
            filled: true,
            height: 54,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            horizontalPadding: 16,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final CircleMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? CircleColors.surface : CircleColors.divider,
        shape: StadiumBorder(
          side: selected
              ? const BorderSide(color: CircleColors.ink, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 4, right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MemberAvatar(
                  initial: member.initial,
                  color: member.color,
                  size: 30,
                  fontSize: 12,
                ),
                const SizedBox(width: 5),
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CircleColors.ink,
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

class _QuickNote extends StatelessWidget {
  const _QuickNote({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? CircleColors.surface : CircleColors.noteBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? CircleColors.ink : CircleColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                CircleSvg(selected ? 'radio_on' : 'radio_off', size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CircleColors.ink,
                    ),
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

class _ChallengeToggle extends StatelessWidget {
  const _ChallengeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      child: Material(
        color: CircleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: CircleColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value ? CircleColors.ink : CircleColors.surface,
                    borderRadius: BorderRadius.circular(5),
                    border: value
                        ? null
                        : Border.all(
                            color: CircleColors.checkboxOff,
                            width: 1.5,
                          ),
                  ),
                  child: value ? const CircleSvg('icon_check', size: 14) : null,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Attach a challenge: 2,000 steps by 8 PM',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CircleColors.ink,
                    ),
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
