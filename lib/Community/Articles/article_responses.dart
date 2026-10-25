// lib/Community/Articles/article_responses.dart
//
// Article engagement (Reddit-style):
//   • UpvoteButton — arrow + count, toggles; primaryInk when on (not gold —
//     gold is for recognition only).
//   • ArticleEngagementBar — the article's upvote + response count.
//   • ArticleResponsesSection — Top / New, composer, responses with one level
//     of replies; authors edit/remove their own; the publishing organisation
//     can remove any response on its article. Removed = "[removed]" slot.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Services/Article/article_engagement_service.dart';
import '../../theme/canopy_components.dart';

final _svc = ArticleEngagementService.instance;

String _ago(DateTime? d) {
  if (d == null) return 'Just now';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat('d MMM').format(d);
}

bool _signedIn(BuildContext context, String action) {
  if (FirebaseAuth.instance.currentUser != null) return true;
  showCanopySnack(context, 'Sign in to $action.');
  return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// UPVOTE
// ─────────────────────────────────────────────────────────────────────────────

class UpvoteButton extends StatelessWidget {
  final int count;
  final bool voted;
  final VoidCallback? onTap;
  final bool compact;
  const UpvoteButton({super.key, required this.count, required this.voted, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final fg = voted ? p.primaryInk : p.inkMuted;
    return Semantics(
      button: true,
      toggled: voted,
      label: '${voted ? 'Remove upvote' : 'Upvote'}. $count upvote${count == 1 ? '' : 's'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CanopyRadius.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CanopySpace.minTouch, minWidth: CanopySpace.minTouch),
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: compact ? CanopySpace.s8 : CanopySpace.s12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? CanopySpace.s4 : CanopySpace.s12, vertical: compact ? 2 : CanopySpace.s8),
              decoration: compact
                  ? null
                  : BoxDecoration(
                      color: voted ? p.surfaceBrand : p.surface,
                      borderRadius: BorderRadius.circular(CanopyRadius.pill),
                      border: Border.all(color: voted ? p.primaryInk : p.outlineStrong),
                    ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(voted ? Icons.arrow_upward : Icons.arrow_upward_outlined, size: compact ? 18 : 20, color: fg),
                const SizedBox(width: CanopySpace.s4),
                Text('$count', style: CanopyType.label.copyWith(color: fg)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The article's own upvote, live, with an optimistic toggle.
class ArticleUpvote extends StatefulWidget {
  final String articleId;
  final int upvotes;
  const ArticleUpvote({super.key, required this.articleId, required this.upvotes});

  @override
  State<ArticleUpvote> createState() => _ArticleUpvoteState();
}

class _ArticleUpvoteState extends State<ArticleUpvote> {
  late final _mine = _svc.watchMyVote(widget.articleId);
  bool? _optimistic;
  bool _busy = false;

  Future<void> _toggle(bool voted) async {
    if (_busy || !_signedIn(context, 'upvote')) return;
    setState(() {
      _busy = true;
      _optimistic = !voted;
    });
    try {
      await _svc.setVote(widget.articleId, vote: !voted);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save your upvote. Try again.", error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _optimistic = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _mine,
      builder: (context, snap) {
        final server = snap.data ?? false;
        final voted = _optimistic ?? server;
        // The doc's count may lag the optimistic state by one round-trip.
        final count = widget.upvotes + (_optimistic == null ? 0 : (voted ? 1 : 0) - (server ? 1 : 0));
        return UpvoteButton(count: count < 0 ? 0 : count, voted: voted, onTap: () => _toggle(voted));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSES
// ─────────────────────────────────────────────────────────────────────────────

class ArticleResponsesSection extends StatefulWidget {
  final String articleId;
  final String? orgId;
  final int articleUpvotes;
  const ArticleResponsesSection({super.key, required this.articleId, required this.orgId, required this.articleUpvotes});

  @override
  State<ArticleResponsesSection> createState() => _ArticleResponsesSectionState();
}

class _ArticleResponsesSectionState extends State<ArticleResponsesSection> {
  late Stream<List<ArticleResponse>> _stream = _svc.watchResponses(widget.articleId);
  bool _top = true;
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _isModerator = false;

  Set<String> _myVotes = {};
  final Map<String, bool> _pending = {}; // optimistic vote state by response id
  Set<String> _loadedFor = {};

  @override
  void initState() {
    super.initState();
    _loadModerator();
  }

  Future<void> _loadModerator() async {
    final orgId = widget.orgId;
    if (_uid == null || orgId == null || orgId.isEmpty) return;
    try {
      final d = await FirebaseFirestore.instance.collection('Users').doc(_uid).get();
      if (mounted && d.data()?['orgId'] == orgId) setState(() => _isModerator = true);
    } catch (_) {}
  }

  void _syncVotes(List<ArticleResponse> list) {
    final ids = list.map((r) => r.id).toSet();
    final missing = ids.difference(_loadedFor);
    if (missing.isEmpty || _uid == null) return;
    _loadedFor = {..._loadedFor, ...missing};
    _svc.myResponseVotes(widget.articleId, missing).then((v) {
      if (mounted) setState(() => _myVotes = {..._myVotes, ...v});
    }).catchError((_) {});
  }

  Future<void> _vote(ArticleResponse r) async {
    if (_pending.containsKey(r.id) || !_signedIn(context, 'upvote')) return;
    final now = !_myVotes.contains(r.id);
    setState(() => _pending[r.id] = now);
    try {
      await _svc.setVote(widget.articleId, responseId: r.id, vote: now);
      if (mounted) setState(() => now ? _myVotes.add(r.id) : _myVotes.remove(r.id));
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save your upvote. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _pending.remove(r.id));
    }
  }

  Future<void> _compose({ArticleResponse? replyTo, ArticleResponse? editing}) async {
    if (!_signedIn(context, 'respond')) return;
    final text = await showCanopySheet<String>(
      context,
      builder: (_) => _Composer(replyTo: replyTo, initial: editing?.body),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    try {
      if (editing != null) {
        await _svc.edit(widget.articleId, editing.id, text);
      } else {
        await _svc.respond(widget.articleId, text, parentId: replyTo?.id);
        if (mounted) showCanopySnack(context, replyTo == null ? 'Response posted.' : 'Reply posted.');
      }
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't post. Try again.", error: true);
    }
  }

  Future<void> _more(ArticleResponse r) async {
    final mine = r.authorUid == _uid;
    final action = await showCanopySheet<String>(
      context,
      builder: (ctx) => CanopySheetBody(
        title: mine ? 'Your response' : 'Moderate response',
        children: [
          CanopyListGroup(children: [
            if (mine) CanopyListRow(icon: Icons.edit_outlined, title: 'Edit', onTap: () => Navigator.pop(ctx, 'edit')),
            CanopyListRow(
              icon: Icons.delete_outline,
              title: mine ? 'Remove' : 'Remove from this article',
              titleColor: ctx.canopy.danger,
              chevron: false,
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ]),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') return _compose(editing: r);
    final ok = await showCanopyConfirm(
      context,
      title: 'Remove this response?',
      message: mine
          ? 'Its text is deleted. Replies stay, under a "[removed]" note.'
          : 'Its text is deleted for everyone. Replies stay, under a "[removed by the organisation]" note.',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (!ok) return;
    try {
      await _svc.remove(widget.articleId, r.id, asOrganisation: !mine);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't remove it. Try again.", error: true);
    }
  }

  int _cmp(ArticleResponse a, ArticleResponse b) {
    final ta = a.createdAt ?? DateTime(9999), tb = b.createdAt ?? DateTime(9999);
    if (_top && a.upvotes != b.upvotes) return b.upvotes.compareTo(a.upvotes);
    return tb.compareTo(ta);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<List<ArticleResponse>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <ArticleResponse>[];
        if (snap.hasData) _syncVotes(all);
        final visible = all.where((r) => !r.deleted || all.any((c) => c.parentId == r.id && !c.deleted)).toList();
        final ids = all.map((r) => r.id).toSet();
        final top = visible.where((r) => r.parentId == null || !ids.contains(r.parentId)).toList()..sort(_cmp);
        final count = all.where((r) => !r.deleted).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ArticleUpvote(articleId: widget.articleId, upvotes: widget.articleUpvotes),
            const SizedBox(width: CanopySpace.s8),
            Text('$count response${count == 1 ? '' : 's'}', style: CanopyType.label.copyWith(color: p.inkMuted)),
          ]),
          const SizedBox(height: CanopySpace.s16),
          Divider(height: 1, color: p.outline),
          const SizedBox(height: CanopySpace.s16),
          Row(children: [
            Expanded(child: Text('Responses', style: CanopyType.title.copyWith(color: p.ink))),
            if (count > 1)
              SizedBox(
                width: 150,
                child: CanopySegmented<bool>(
                  options: const [(true, 'Top'), (false, 'New')],
                  value: _top,
                  onChanged: (v) => setState(() => _top = v),
                ),
              ),
          ]),
          const SizedBox(height: CanopySpace.s12),
          Semantics(
            button: true,
            label: 'Add a response',
            child: InkWell(
              onTap: () => _compose(),
              borderRadius: BorderRadius.circular(CanopyRadius.sm),
              child: Container(
                constraints: const BoxConstraints(minHeight: CanopySpace.minTouch),
                padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s12, vertical: CanopySpace.s12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(CanopyRadius.sm),
                  border: Border.all(color: p.outlineStrong),
                ),
                child: Text('What do you think?', style: CanopyType.body.copyWith(color: p.inkFaint)),
              ),
            ),
          ),
          const SizedBox(height: CanopySpace.s8),
          if (snap.hasError)
            CanopyErrorState(
              title: "Couldn't load responses",
              onRetry: () => setState(() => _stream = _svc.watchResponses(widget.articleId)),
            )
          else if (!snap.hasData)
            const Padding(padding: EdgeInsets.all(CanopySpace.s24), child: Center(child: CircularProgressIndicator()))
          else if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CanopySpace.s24),
              child: Text('No responses yet. Be the first to share what you think.',
                  textAlign: TextAlign.center, style: CanopyType.body.copyWith(color: p.inkMuted)),
            )
          else
            for (final r in top) ...[
              _tile(r, reply: false),
              for (final c in (visible.where((x) => x.parentId == r.id).toList()
                ..sort((a, b) => (a.createdAt ?? DateTime(9999)).compareTo(b.createdAt ?? DateTime(9999)))))
                _tile(c, reply: true),
            ],
        ]);
      },
    );
  }

  Widget _tile(ArticleResponse r, {required bool reply}) {
    final p = context.canopy;
    final voted = _pending[r.id] ?? _myVotes.contains(r.id);
    final serverVoted = _myVotes.contains(r.id);
    final count = r.upvotes + (_pending.containsKey(r.id) ? (voted ? 1 : 0) - (serverVoted ? 1 : 0) : 0);
    final canMore = !r.deleted && (r.authorUid == _uid || _isModerator);
    return Container(
      margin: EdgeInsets.only(left: reply ? CanopySpace.s24 : 0, top: CanopySpace.s12),
      padding: EdgeInsets.only(left: reply ? CanopySpace.s12 : 0),
      decoration: reply ? BoxDecoration(border: Border(left: BorderSide(color: p.outline, width: 2))) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (!r.deleted) ...[
            CanopyAvatar(url: r.authorPhotoUrl, name: r.authorName, size: 28),
            const SizedBox(width: CanopySpace.s8),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: r.deleted ? '' : r.authorName, style: CanopyType.label.copyWith(color: p.ink)),
                TextSpan(
                  text: '${r.deleted ? '' : ' · '}${_ago(r.createdAt)}${r.editedAt != null && !r.deleted ? ' · edited' : ''}',
                  style: CanopyType.caption.copyWith(color: p.inkMuted),
                ),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canMore) CanopyIconButton(icon: Icons.more_horiz, tooltip: 'More', onPressed: () => _more(r)),
        ]),
        const SizedBox(height: CanopySpace.s4),
        Text(
          r.deleted ? (r.removedBy == 'organisation' ? '[removed by the organisation]' : '[removed]') : r.body,
          style: r.deleted
              ? CanopyType.body.copyWith(color: p.inkMuted, fontStyle: FontStyle.italic)
              : CanopyType.body.copyWith(color: p.ink),
        ),
        if (!r.deleted)
          Row(children: [
            UpvoteButton(count: count < 0 ? 0 : count, voted: voted, compact: true, onTap: () => _vote(r)),
            if (!reply)
              TextButton.icon(
                onPressed: () => _compose(replyTo: r),
                icon: const Icon(Icons.reply, size: 18),
                label: const Text('Reply'),
              ),
          ]),
      ]),
    );
  }
}

class _Composer extends StatefulWidget {
  final ArticleResponse? replyTo;
  final String? initial;
  const _Composer({this.replyTo, this.initial});

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late final _ctrl = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    final empty = _ctrl.text.trim().isEmpty;
    return CanopySheetBody(
      title: editing ? 'Edit response' : (widget.replyTo == null ? 'Your response' : 'Reply to ${widget.replyTo!.authorName}'),
      caption: editing ? null : 'Shown with your name and photo. Be respectful — see the community guidelines.',
      children: [
        CanopyTextField(
          controller: _ctrl,
          hint: 'Write here',
          minLines: 4,
          maxLines: 10,
          maxLength: ArticleEngagementService.maxLength,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
      ],
      actions: [
        CanopyButton(
          label: editing ? 'Save' : 'Post',
          expand: true,
          onPressed: empty ? null : () => Navigator.pop(context, _ctrl.text.trim()),
        ),
      ],
    );
  }
}
