import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/friends_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/friend_widgets.dart';

// ---------------------------------------------------------------------------
// INVITE PEOPLE — bottom sheet opened from the Circle home. Type an email,
// @username or friend code, or pick someone from the suggestions. Inviting
// sends a friend request.
// ---------------------------------------------------------------------------

/// Opens the invite sheet. [familyName] is only used in the copy.
Future<void> showInvitePeopleSheet(
  BuildContext context, {
  required FriendsRepository friends,
  String? familyName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => InvitePeopleSheet(friends: friends, familyName: familyName),
  );
}

/// Where someone stands with you, which decides their button.
enum _Relation { none, friend, sent, received }

class InvitePeopleSheet extends StatefulWidget {
  const InvitePeopleSheet({super.key, required this.friends, this.familyName});

  final FriendsRepository friends;
  final String? familyName;

  @override
  State<InvitePeopleSheet> createState() => _InvitePeopleSheetState();
}

class _InvitePeopleSheetState extends State<InvitePeopleSheet> {
  FriendsRepository get _repo => widget.friends;

  /// How long typing has to pause before searching.
  static const _debounce = Duration(milliseconds: 350);

  final _query = TextEditingController();
  Timer? _timer;
  int _searchToken = 0;

  UserProfile? _me;
  final _friendIds = <String>{};
  final _sentIds = <String>{};
  final _receivedIds = <String>{};
  List<UserProfile> _suggestions = const [];
  bool _loading = true;
  bool _loadFailed = false;

  /// Null until something has been searched for.
  List<UserProfile>? _results;
  bool _searching = false;

  /// Users with an invite in flight, so buttons can't be double-tapped.
  final _busy = <String>{};

  /// The last problem (e.g. "A request is already pending"), shown under
  /// the text field because a snackbar would be hidden behind the sheet.
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await _repo.currentUser();
      final friends = await _repo.friends();
      final incoming = await _repo.incomingRequests();
      final outgoing = await _repo.outgoingRequests();
      final suggestions = await _repo.suggestions();
      if (!mounted) return;
      setState(() {
        _me = me;
        _friendIds.addAll(friends.map((f) => f.id));
        _receivedIds.addAll(incoming.map((f) => f.otherUserId(me.id)));
        _sentIds.addAll(outgoing.map((f) => f.otherUserId(me.id)));
        _suggestions = suggestions;
        _loading = false;
      });
    } on Exception {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _onChanged(String input) {
    _timer?.cancel();
    if (input.trim().isEmpty) {
      _searchToken++;
      setState(() {
        _results = null;
        _searching = false;
        _message = null;
      });
      return;
    }
    _timer = Timer(_debounce, () => _search(input));
  }

  /// An email finds that one account, a friend code or invite link finds
  /// that one person, and anything else searches usernames.
  Future<void> _search(String input) async {
    _timer?.cancel();
    final text = input.trim();
    if (text.isEmpty) return;
    final token = ++_searchToken;
    setState(() {
      _searching = true;
      _message = null;
    });
    List<UserProfile> found;
    try {
      if (looksLikeEmail(text)) {
        final user = await _repo.findByEmail(text);
        found = [?user];
      } else {
        final code = friendCodeFrom(text);
        final byCode = code == null ? null : await _repo.findByFriendCode(code);
        final byName = await _repo.searchUsers(text);
        found = [?byCode, ...byName.where((u) => u.id != byCode?.id)];
      }
    } on Exception {
      found = const [];
      if (mounted && token == _searchToken) {
        setState(() => _message = "Couldn't search right now. Try again.");
      }
    }
    if (!mounted || token != _searchToken) return;
    setState(() {
      _results = found.where((u) => u.id != _me?.id).toList();
      _searching = false;
    });
  }

  _Relation _relationTo(UserProfile user) {
    if (_friendIds.contains(user.id)) return _Relation.friend;
    if (_sentIds.contains(user.id)) return _Relation.sent;
    if (_receivedIds.contains(user.id)) return _Relation.received;
    return _Relation.none;
  }

  Future<void> _invite(UserProfile user) async {
    if (_busy.contains(user.id)) return;
    setState(() {
      _busy.add(user.id);
      _message = null;
    });
    String? problem;
    try {
      await _repo.sendRequest(user.id);
    } on FriendRequestException catch (e) {
      problem = e.message;
    } on Exception {
      problem = "Couldn't send the invite. Try again.";
    }
    if (!mounted) return;
    setState(() {
      _busy.remove(user.id);
      if (problem == null) {
        _sentIds.add(user.id);
      } else {
        _message = problem;
      }
    });
  }

  Future<void> _copyInviteLink() async {
    final me = _me;
    if (me == null) return;
    await Clipboard.setData(ClipboardData(text: inviteLink(me.friendCode)));
    if (mounted) setState(() => _message = 'Invite link copied 📋');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final family = widget.familyName;
    final results = _results;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Invite people', style: text.titleLarge),
                const SizedBox(height: 2),
                Text(
                  family == null
                      ? 'Who do you want to compete with?'
                      : 'Who should join you in $family?',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('invite-input'),
                  controller: _query,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Email, @username or friend code',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _onChanged,
                  onSubmitted: _search,
                ),
                if (_message case final message?) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    key: const ValueKey('invite-message'),
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (results != null)
                  ..._resultList(results)
                else
                  ..._suggestionList(),
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const ValueKey('copy-invite-link'),
                  onPressed: _me == null ? null : _copyInviteLink,
                  icon: const Icon(Icons.link_rounded),
                  label: Text(
                    _me == null
                        ? 'Copy my invite link'
                        : 'Copy my invite link · code ${_me!.friendCode}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _resultList(List<UserProfile> results) {
    final text = Theme.of(context).textTheme;
    if (results.isEmpty && !_searching) {
      return [
        Text(
          looksLikeEmail(_query.text.trim())
              ? "Nobody has signed up with that email yet. Send them your "
                    'invite link instead 👇'
              : 'No one found. Check the spelling, or send them your invite '
                    'link 👇',
          key: const ValueKey('invite-no-results'),
          style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
        ),
      ];
    }
    return [for (final user in results) _row(user)];
  }

  List<Widget> _suggestionList() {
    final text = Theme.of(context).textTheme;
    return [
      Text('Suggested for you', style: text.titleMedium),
      const SizedBox(height: 8),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_loadFailed)
        Text(
          "Couldn't load suggestions. You can still search above.",
          style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
        )
      else if (_suggestions.isEmpty)
        Text(
          "No suggestions yet: you've invited everyone here! 🎉",
          key: const ValueKey('invite-no-suggestions'),
          style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
        )
      else
        for (final user in _suggestions) _row(user),
    ];
  }

  Widget _row(UserProfile user) {
    final text = Theme.of(context).textTheme;
    return Padding(
      key: ValueKey('invite-row-${user.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          EmojiAvatar(emoji: user.avatarEmoji, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                Text(
                  '@${user.username}',
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _action(user),
        ],
      ),
    );
  }

  Widget _action(UserProfile user) {
    final label = switch (_relationTo(user)) {
      _Relation.friend => 'Friends ✓',
      _Relation.sent => 'Invited ✓',
      _Relation.received => 'Asked you',
      _Relation.none => null,
    };
    if (label != null) {
      return Text(
        label,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: AppColors.primaryText),
      );
    }
    final busy = _busy.contains(user.id);
    return FilledButton(
      key: ValueKey('invite-${user.id}'),
      onPressed: busy ? null : () => _invite(user),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(88, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Invite'),
    );
  }
}
