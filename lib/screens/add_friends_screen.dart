import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/friends_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky.dart';
import '../widgets/friend_widgets.dart';

// ---------------------------------------------------------------------------
// FRIENDS — your code, add people, answer requests, manage your list
// ---------------------------------------------------------------------------

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key, required this.friends});

  final FriendsRepository friends;

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

/// Where someone stands with you, which decides their button.
enum _Relation { none, friend, sent, received }

class _Request {
  const _Request(this.friendship, this.user);

  final Friendship friendship;
  final UserProfile user;
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  FriendsRepository get _repo => widget.friends;

  UserProfile? _me;
  List<UserProfile> _friends = const [];
  List<_Request> _incoming = const [];
  List<_Request> _outgoing = const [];
  bool _loaded = false;
  bool _loadFailed = false;

  final _query = TextEditingController();
  List<UserProfile> _results = const [];
  int _searchToken = 0;

  /// Users with an action in flight, so buttons can't be double-tapped.
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final me = await _repo.currentUser();
      final friends = await _repo.friends();
      final incoming = await _withUsers(await _repo.incomingRequests(), me);
      final outgoing = await _withUsers(await _repo.outgoingRequests(), me);
      if (!mounted) return;
      setState(() {
        _me = me;
        _friends = friends;
        _incoming = incoming;
        _outgoing = outgoing;
        _loaded = true;
        _loadFailed = false;
      });
    } on Exception {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<List<_Request>> _withUsers(
    List<Friendship> list,
    UserProfile me,
  ) async {
    final out = <_Request>[];
    for (final f in list) {
      final user = await _repo.userById(f.otherUserId(me.id));
      if (user != null) out.add(_Request(f, user));
    }
    return out;
  }

  /// A friend code or invite link finds that one person; anything else
  /// searches usernames and names.
  Future<void> _search(String input) async {
    final token = ++_searchToken;
    final code = friendCodeFrom(input);
    final byCode = code == null ? null : await _repo.findByFriendCode(code);
    final byName = await _repo.searchUsers(input);
    if (!mounted || token != _searchToken) return;
    final me = _me?.id;
    setState(() {
      _results = [
        if (byCode != null && byCode.id != me) byCode,
        ...byName.where((u) => u.id != byCode?.id),
      ];
    });
  }

  _Relation _relationTo(UserProfile user) {
    if (_friends.any((f) => f.id == user.id)) return _Relation.friend;
    if (_outgoing.any((r) => r.user.id == user.id)) return _Relation.sent;
    if (_incoming.any((r) => r.user.id == user.id)) return _Relation.received;
    return _Relation.none;
  }

  /// Runs [action] for [user], then refreshes and says how it went.
  Future<void> _act(
    UserProfile user,
    Future<void> Function() action,
    String done,
  ) async {
    if (_busy.contains(user.id)) return;
    setState(() => _busy.add(user.id));
    String message = done;
    try {
      await action();
    } on FriendRequestException catch (e) {
      message = e.message;
    }
    await _reload();
    if (!mounted) return;
    setState(() => _busy.remove(user.id));
    if (_query.text.isNotEmpty) await _search(_query.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _add(UserProfile u) => _act(
    u,
    () => _repo.sendRequest(u.id),
    'Request sent to ${u.displayName} 👋',
  );

  void _respond(_Request r, {required bool accept}) => _act(
    r.user,
    () => _repo.respondToRequest(r.friendship.id, accept: accept),
    accept
        ? 'You and ${r.user.displayName} are friends now 🎉'
        : 'Request from ${r.user.displayName} declined',
  );

  void _cancel(_Request r) => _act(
    r.user,
    () => _repo.cancelRequest(r.friendship.id),
    'Request to ${r.user.displayName} canceled',
  );

  Future<void> _remove(UserProfile u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${u.displayName}?'),
        content: Text(
          "You'll stop seeing each other's stats. "
          "${u.displayName} won't be notified.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _act(
      u,
      () => _repo.removeFriend(u.id),
      '${u.displayName} removed from your friends',
    );
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what copied 📋')));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final me = _me;

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: SafeArea(
        top: false,
        child: _loadFailed && !_loaded
            ? Center(
                child: ChunkyButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  expand: false,
                  onPressed: _reload,
                ),
              )
            : me == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  // YOUR CODE
                  _MyCode(
                    me: me,
                    onCopyCode: () => _copy(me.friendCode, 'Friend code'),
                    onCopyLink: () =>
                        _copy(inviteLink(me.friendCode), 'Invite link'),
                  ),
                  const SizedBox(height: 24),

                  // ADD
                  Text('Add a friend', style: text.titleLarge),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('friend-search'),
                    controller: _query,
                    onChanged: _search,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: 'Code, @username or invite link',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceSunken,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  if (_query.text.trim().length >= 2) ...[
                    const SizedBox(height: 10),
                    if (_results.isEmpty)
                      Text(
                        'No one found. Check the code and try again 🔍',
                        style: text.bodySmall,
                      )
                    else
                      for (final u in _results) ...[
                        _PersonRow(
                          key: ValueKey('result-${u.id}'),
                          user: u,
                          trailing: _resultAction(u),
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                  const SizedBox(height: 24),

                  // REQUESTS
                  if (_incoming.isNotEmpty) ...[
                    Text('Requests', style: text.titleLarge),
                    const SizedBox(height: 10),
                    for (final r in _incoming) ...[
                      _PersonRow(
                        key: ValueKey('incoming-${r.user.id}'),
                        user: r.user,
                        subtitle: 'wants to add you',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SmallButton(
                              label: 'Decline',
                              secondary: true,
                              onTap: () => _respond(r, accept: false),
                            ),
                            const SizedBox(width: 8),
                            _SmallButton(
                              label: 'Accept',
                              onTap: () => _respond(r, accept: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                  ],
                  if (_outgoing.isNotEmpty) ...[
                    Text('Sent', style: text.titleLarge),
                    const SizedBox(height: 10),
                    for (final r in _outgoing) ...[
                      _PersonRow(
                        key: ValueKey('outgoing-${r.user.id}'),
                        user: r.user,
                        subtitle: 'waiting on them',
                        trailing: _SmallButton(
                          label: 'Cancel',
                          secondary: true,
                          onTap: () => _cancel(r),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // FRIENDS
                  Text(
                    'Your friends (${_friends.length})',
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  if (_friends.isEmpty)
                    Text(
                      'No friends yet. Share your code to get started 🚀',
                      style: text.bodySmall,
                    ),
                  for (final f in _friends) ...[
                    _PersonRow(
                      key: ValueKey('friend-row-${f.id}'),
                      user: f,
                      trailing: _SmallButton(
                        label: 'Remove',
                        secondary: true,
                        onTap: () => _remove(f),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _resultAction(UserProfile u) {
    final busy = _busy.contains(u.id);
    return switch (_relationTo(u)) {
      _Relation.friend => const _Tag('Friends ✓'),
      _Relation.sent => const _Tag('Requested'),
      _Relation.received => _SmallButton(
        label: 'Accept',
        onTap: busy
            ? null
            : () => _respond(
                _incoming.firstWhere((r) => r.user.id == u.id),
                accept: true,
              ),
      ),
      _Relation.none => _SmallButton(
        label: 'Add',
        onTap: busy ? null : () => _add(u),
      ),
    };
  }
}

class _MyCode extends StatelessWidget {
  const _MyCode({
    required this.me,
    required this.onCopyCode,
    required this.onCopyLink,
  });

  final UserProfile me;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ChunkyCard(
      color: AppColors.primaryTint,
      borderColor: AppColors.primary,
      edgeColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your friend code', style: text.labelMedium),
          const SizedBox(height: 4),
          Text(
            me.friendCode,
            key: const ValueKey('my-code'),
            style: text.displayLarge?.copyWith(
              color: AppColors.primaryText,
              letterSpacing: 4,
            ),
          ),
          Text('or find me as @${me.username}', style: text.bodySmall),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ChunkyButton.secondary(
                  label: 'Copy code',
                  icon: Icons.copy_rounded,
                  onPressed: onCopyCode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChunkyButton(
                  label: 'Invite link',
                  icon: Icons.link_rounded,
                  onPressed: onCopyLink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    super.key,
    required this.user,
    required this.trailing,
    this.subtitle,
  });

  final UserProfile user;
  final Widget trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ChunkyCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          EmojiAvatar(emoji: user.avatarEmoji, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                Text(
                  subtitle ?? '@${user.username}',
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

/// A compact chunky button for rows.
class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.onTap,
    this.secondary = false,
  });

  final String label;

  /// Null disables it.
  final VoidCallback? onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: ChunkySurface(
        color: !enabled
            ? AppColors.border
            : (secondary ? AppColors.surface : AppColors.primary),
        edgeColor: !enabled
            ? AppColors.borderDark
            : (secondary ? AppColors.border : AppColors.primaryDark),
        borderColor: secondary && enabled ? AppColors.border : null,
        depth: 3,
        radius: AppRadius.chip,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: onTap,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: !enabled
                ? AppColors.muted
                : (secondary ? AppColors.inkSoft : Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: AppColors.inkSoft),
      ),
    );
  }
}
