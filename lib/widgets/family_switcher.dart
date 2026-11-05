import 'package:flutter/material.dart';

import '../data/mock_circle.dart';
import '../theme/circle_colors.dart';
import 'circle_widgets.dart';

// ---------------------------------------------------------------------------
// FAMILY SWITCHER — bottom sheet opened from the Circle header button.
// Pick one of your families, or create a new one.
// ---------------------------------------------------------------------------

/// Shows the switcher and returns the family to show next: one of [families],
/// a brand-new family the user just created (not in [families] yet), or null
/// if they backed out.
Future<CircleFamily?> showFamilySwitcher(
    BuildContext context, {
      required List<CircleFamily> families,
      required CircleFamily current,
    }) async {
  final choice = await showModalBottomSheet<_SheetChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: CircleColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FamilySheet(families: families, current: current),
  );
  if (choice == null || !context.mounted) return null;

  final picked = choice.family;
  if (picked != null) return picked;

  final name = await showDialog<String>(
    context: context,
    builder: (_) => _CreateFamilyDialog(
      takenNames: {for (final f in families) f.name.toLowerCase()},
    ),
  );
  if (name == null) return null;

  return CircleFamily(
    id: 'family-${DateTime.now().microsecondsSinceEpoch}',
    name: name,
  );
}

/// What the sheet closes with: a family to switch to, or "create a new one".
class _SheetChoice {
  const _SheetChoice.pick(CircleFamily this.family);
  const _SheetChoice.create() : family = null;

  final CircleFamily? family;
}

// ---------------------------------------------------------------------------
// SHEET
// ---------------------------------------------------------------------------

class _FamilySheet extends StatelessWidget {
  const _FamilySheet({required this.families, required this.current});

  final List<CircleFamily> families;
  final CircleFamily current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your families',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: CircleColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Switch circles or start a new one',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CircleColors.secondary,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Material(
                  color: CircleColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: CircleColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final family in families) ...[
                        if (family != families.first)
                          Container(
                            height: 1,
                            margin: const EdgeInsets.only(left: 68),
                            color: CircleColors.divider,
                          ),
                        _FamilyRow(
                          family: family,
                          selected: family.id == current.id,
                          onTap: () => Navigator.of(context)
                              .pop(_SheetChoice.pick(family)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            CirclePillButton(
              label: 'Create a new family',
              filled: true,
              height: 48,
              fontSize: 15,
              onPressed: () =>
                  Navigator.of(context).pop(const _SheetChoice.create()),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyRow extends StatelessWidget {
  const _FamilyRow({
    required this.family,
    required this.selected,
    required this.onTap,
  });

  final CircleFamily family;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = family.memberCount;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: CircleColors.mapBackground,
                  shape: BoxShape.circle,
                ),
                child: const CircleSvg('icon_users', size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CircleColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 1 ? 'Just you so far' : '$count members',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CircleColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircleSvg(selected ? 'radio_on' : 'radio_off', size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CREATE DIALOG — name the new family
// ---------------------------------------------------------------------------

class _CreateFamilyDialog extends StatefulWidget {
  const _CreateFamilyDialog({required this.takenNames});

  /// Existing family names, lowercased, so we don't make duplicates.
  final Set<String> takenNames;

  @override
  State<_CreateFamilyDialog> createState() => _CreateFamilyDialogState();
}

class _CreateFamilyDialogState extends State<_CreateFamilyDialog> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your family a name');
      return;
    }
    if (widget.takenNames.contains(name.toLowerCase())) {
      setState(() => _error = 'You already have a family called "$name"');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return Dialog(
      backgroundColor: CircleColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New family',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: CircleColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Name it something everyone will recognize',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CircleColors.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: CircleColors.noteBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: error == null
                      ? CircleColors.outline
                      : CircleColors.dangerOutline,
                ),
              ),
              child: TextField(
                controller: _name,
                autofocus: true,
                maxLength: 30,
                buildCounter: (
                    _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CircleColors.ink,
                ),
                decoration: const InputDecoration.collapsed(
                  hintText: 'e.g. Roommates',
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CircleColors.heart,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: CirclePillButton(
                    label: 'Cancel',
                    height: 44,
                    fontSize: 15,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CirclePillButton(
                    label: 'Create',
                    filled: true,
                    height: 44,
                    fontSize: 15,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}