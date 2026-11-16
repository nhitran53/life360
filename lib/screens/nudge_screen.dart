import 'package:flutter/material.dart';

import '../data/mock_circle.dart';
import '../theme/app_colors.dart';
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CircleTitle(
            title: 'Send a nudge',
            subtitle: 'A friendly note to get someone moving',
          ),
          const SizedBox(height: 20),

          // 1. Who
          const CircleGroupLabel('Who are you nudging?'),
          CircleGroup(
            rows: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final member in circleNudgeMembers)
                      _RecipientChip(
                        member: member,
                        selected: member == _recipient,
                        onTap: () => setState(() => _recipient = member),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_walk_rounded,
                      size: 18,
                      color: AppColors.primaryText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _recipient.nudgeHint,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CircleColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            dividerIndent: 0,
          ),
          const SizedBox(height: 22),

          // 2. Message: quick picks, then the note itself
          const CircleGroupLabel('Pick a message'),
          CircleGroup(
            dividerIndent: 46,
            rows: [
              for (var i = 0; i < circleQuickNotes.length; i++)
                _QuickNote(
                  text: circleQuickNotes[i],
                  selected: i == _quickNote,
                  onTap: () => _pickNote(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder(
            valueListenable: _note,
            builder: (context, value, _) =>
                _NoteBox(
                  controller: _note,
                  length: value.text.length,
                  onChanged: _onNoteEdited,
                ),
          ),
          const SizedBox(height: 22),

          // 3. Extra
          const CircleGroupLabel('Make it a challenge'),
          CircleGroup(
            rows: [
              Semantics(
                toggled: _challenge,
                child: InkWell(
                  onTap: () => setState(() => _challenge = !_challenge),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const CircleEmojiBubble('🏁'),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attach a challenge',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: CircleColors.ink,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                '2,000 steps by 8 PM',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CircleColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleSwitch(value: _challenge),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          CirclePillButton(
            label: 'Send to ${_recipient.name}',
            icon: 'icon_send_18',
            iconSize: 18,
            filled: true,
            fillColor: AppColors.primary,
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
        color: selected ? AppColors.primaryTint : CircleColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.primary : CircleColors.border,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 4, right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MemberAvatar(
                  initial: member.initial,
                  color: member.color,
                  size: 32,
                  fontSize: 12,
                ),
                const SizedBox(width: 6),
                Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected ? AppColors.primaryText : CircleColors.ink,
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
        color: selected ? AppColors.primaryTint : CircleColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleSvg(selected ? 'radio_on' : 'radio_off', size: 18),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

/// The note you'll send, with a character count.
class _NoteBox extends StatelessWidget {
  const _NoteBox({
    required this.controller,
    required this.length,
    required this.onChanged,
  });

  static const maxLength = 140;

  final TextEditingController controller;
  final int length;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: CircleColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primarySoft, width: circleOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_rounded, size: 16, color: AppColors.primaryText),
              SizedBox(width: 6),
              Text(
                'Your note',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: 2,
            maxLines: 4,
            maxLength: maxLength,
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
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$length/$maxLength',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: CircleColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}