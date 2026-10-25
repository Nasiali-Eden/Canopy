// lib/Organization/Home/Profile/org_profile.dart
//
// Org profile (ORG_HANDOFF §3.7, F). Gradient identity header (logo, name,
// verified line, est. · members · events) → "See your public page" →
// Tools for your organisation (capability cards: Marketplace · Environmental
// Ops · Cultural Archive — Not applied / Under review / Enabled) → role
// switcher card → groups Organisation / Account / Help → Sign out.
// Every row goes somewhere real; unbuilt settings aren't listed.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../Community/Profile/security_screen.dart';
import '../../../Community/Profile/support_sheet.dart';
import '../../../Culture/Heritage/Create/heritage_backgrounds_screen.dart';
import '../../../Services/Authentication/auth.dart';
import '../../../Services/Authentication/community_auth.dart';
import '../../../Shared/Pages/login.dart';
import '../../../Shared/widgets/workspace_switch.dart';
import '../../../theme/canopy_components.dart';
import '../../Explorer/org_view_screen.dart';
import '../../org_ui.dart';
import '../Articles/org_articles.dart';
import '../Dashboard/edit_org_details_screen.dart';
import '../org_home.dart';

String _normalizeStatus(dynamic raw) {
  final s = (raw ?? '').toString().trim().toLowerCase();
  if (const {'approved', 'active', 'enabled', 'yes'}.contains(s)) return 'approved';
  if (const {'pending', 'under review', 'review'}.contains(s)) return 'pending';
  if (const {'rejected', 'denied', 'declined'}.contains(s)) return 'rejected';
  return 'none';
}

CapabilityState _capState(String s) => switch (s) {
      'approved' => CapabilityState.enabled,
      'pending' => CapabilityState.underReview,
      _ => CapabilityState.notApplied,
    };

class OrgProfile extends StatefulWidget {
  /// Kept for call-site compatibility; workspace switching lives in
  /// workspace_switch.dart now.
  final WidgetBuilder? orgHomeBuilder;

  const OrgProfile({super.key, this.orgHomeBuilder});

  @override
  State<OrgProfile> createState() => _OrgProfileState();
}

class _OrgProfileState extends State<OrgProfile> {
  final _db = FirebaseFirestore.instance;
  String? _orgId;
  Map<String, dynamic> _org = const {};
  int? _events;
  bool _loading = true, _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('signed out');
      final u = await _db.collection('Users').doc(uid).get();
      final id = u.data()?['orgId'] as String?;
      if (id == null) throw StateError('no org');
      final o = await _db.collection('organizations').doc(id).get();
      final data = Map<String, dynamic>.from(o.data() ?? {});
      for (final k in ['marketplaceStatus', 'envOpsStatus', 'culturalStatus']) {
        data[k] = _normalizeStatus(data[k]);
      }
      int? events;
      try {
        events = (await _db.collection('activities').where('orgId', isEqualTo: id).count().get()).count;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _orgId = id;
        _org = data;
        _events = events;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _push(Widget w) => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _signOut() async {
    final ok = await showCanopyConfirm(context,
        title: 'Sign out?', message: "You'll need to sign in again to manage your organisation.", confirmLabel: 'Sign out');
    if (!ok) return;
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginPage()), (_) => false);
  }

  Future<void> _apply(String kind) async {
    final applied = await showCanopySheet<bool>(context, builder: (_) => _ApplySheet(kind: kind, orgId: _orgId!));
    if (applied == true) {
      await _load();
      if (mounted) {
        showCanopySnack(context,
            kind == 'envOps' ? 'Environmental Ops is on. Open it below.' : "Application sent — you'll hear back after review.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (_loading) return const CanopyScaffold(body: Center(child: CircularProgressIndicator()));
    if (_failed) {
      return CanopyScaffold(
        appBar: canopyAppBar(context, title: 'Profile', showBack: false),
        body: CanopyErrorState(title: "Couldn't load your organisation", onRetry: _load),
      );
    }
    final orgId = _orgId!;
    final o = _org;
    final name = ((o['org_name'] ?? o['name']) as String?) ?? 'Your organisation';
    final logo = (o['logoUrl'] ?? o['profilePhoto']) as String?;
    final verified = o['verified'] == true;
    final designation = ((o['orgDesignation'] ?? o['designation']) as String?)?.trim() ?? '';
    final city = (o['city'] as String?)?.trim() ?? '';
    final founded = (o['foundedAt'] ?? o['createdAt']);
    final members = (o['memberCount'] as num?)?.toInt();
    final switcher = workspaceSwitcher(context, activeContext: 'org', orgId: orgId, org: o);
    final shell = OrgShellScope.of(context);

    final facts = [
      if (founded is Timestamp) 'Est. ${DateFormat('yyyy').format(founded.toDate())}',
      if (members != null) '$members member${members == 1 ? '' : 's'}',
      if (_events != null) '$_events event${_events == 1 ? '' : 's'}',
    ];

    Widget cap(String key, IconData icon, String title, String line, VoidCallback onOpen) {
      final status = o['${key}Status'] as String? ?? 'none';
      final applied = o[key == 'marketplace' ? 'marketplaceAppliedAt' : '${key}RegisteredAt'];
      return Padding(
        padding: const EdgeInsets.only(bottom: CanopySpace.s12),
        child: CapabilityCard(
          icon: icon,
          title: title,
          description: status == 'rejected' ? 'Not approved last time. You can apply again.' : line,
          state: _capState(status),
          reviewNote: applied is Timestamp ? 'Applied ${DateFormat('d MMM yyyy').format(applied.toDate())}' : null,
          onApply: () => _apply(key),
          onOpen: onOpen,
        ),
      );
    }

    return CanopyScaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Gradient identity header ──────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.surfaceBrand, p.canvas],
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                  CanopySpace.gutter, MediaQuery.paddingOf(context).top + CanopySpace.s24, CanopySpace.gutter, CanopySpace.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CanopyAvatar(url: logo, name: name, size: 72, org: true),
                const SizedBox(height: CanopySpace.s12),
                Text(name, style: CanopyType.display.copyWith(color: p.ink)),
                const SizedBox(height: CanopySpace.s4),
                Row(children: [
                  if (verified) ...[
                    Icon(Icons.verified, size: 16, color: p.primary),
                    const SizedBox(width: CanopySpace.s4),
                  ],
                  Flexible(
                    child: Text(
                      [
                        verified ? 'Verified${designation.isEmpty ? '' : ' $designation'}' : designation,
                        city,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: CanopyType.label.copyWith(color: p.inkMuted),
                    ),
                  ),
                ]),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: CanopySpace.s4),
                  Text(facts.join(' · '), style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ],
                const SizedBox(height: CanopySpace.s16),
                CanopyButton.secondary(
                  label: 'See your public page',
                  expand: true,
                  onPressed: () => _push(OrgViewScreen(orgId: orgId, orgData: o)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const CanopySectionHeader(title: 'Tools for your organisation', padding: EdgeInsets.only(top: CanopySpace.s16)),
                cap('marketplace', Icons.storefront_outlined, 'Marketplace',
                    'Sell recycled material and products to buyers on Canopy.', () => switcher.onMarketplaceTap?.call()),
                cap('envOps', Icons.recycling_outlined, 'Environmental Ops',
                    'Run collection territory, a material market, tree monitoring and a fleet.', () => switcher.onEnvOpsTap?.call()),
                cap('cultural', Icons.account_balance_outlined, 'Cultural Archive',
                    "Document and look after a community's heritage.", () => switcher.onCulturalTap?.call()),
                const SizedBox(height: CanopySpace.s8),
                switcher,
                const CanopySectionHeader(title: 'Organisation', padding: EdgeInsets.only(top: CanopySpace.section)),
                CanopyListGroup(children: [
                  CanopyListRow(
                    icon: Icons.edit_outlined,
                    title: 'Organisation details',
                    subtitle: 'Name, logo, cover, about, contact',
                    onTap: () async {
                      final saved = await Navigator.of(context, rootNavigator: true)
                          .push<bool>(MaterialPageRoute(builder: (_) => EditOrgDetailsScreen(orgId: orgId)));
                      if (saved == true) _load();
                    },
                  ),
                  if (shell != null)
                    CanopyListRow(icon: Icons.people_outline, title: 'People & teams', onTap: () => shell.goTo(OrgTab.people)),
                  CanopyListRow(icon: Icons.article_outlined, title: 'Articles', onTap: () => _push(OrgArticlesScreen(orgId: orgId))),
                  if (shell != null)
                    CanopyListRow(
                      icon: Icons.handshake_outlined,
                      title: 'Partners',
                      onTap: () => shell.goTo(OrgTab.operations, sub: 'partners'),
                    ),
                  CanopyListRow(
                    icon: Icons.landscape_outlined,
                    title: 'Heritage backgrounds',
                    onTap: () => _push(HeritageBackgroundsScreen(orgId: orgId)),
                  ),
                ]),
                const CanopySectionHeader(title: 'Account', padding: EdgeInsets.only(top: CanopySpace.section)),
                CanopyListGroup(children: [
                  CanopyListRow(
                    icon: Icons.lock_outline,
                    title: 'Password & security',
                    subtitle: FirebaseAuth.instance.currentUser?.email,
                    onTap: () => _push(const SecurityScreen()),
                  ),
                  CanopyListRow(
                    icon: Icons.notifications_none,
                    title: 'Notifications',
                    onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/notifications'),
                  ),
                ]),
                const CanopySectionHeader(title: 'Help', padding: EdgeInsets.only(top: CanopySpace.section)),
                CanopyListGroup(children: [
                  CanopyListRow(
                    icon: Icons.help_outline,
                    title: 'Get help',
                    subtitle: 'Send a question to the Canopy team',
                    onTap: () => showSupportSheet(context),
                  ),
                ]),
                const SizedBox(height: CanopySpace.section),
                Center(child: CanopyButton.quietDanger(label: 'Sign out', onPressed: _signOut)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APPLY SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ApplySheet extends StatefulWidget {
  final String kind; // marketplace · envOps · cultural
  final String orgId;
  const _ApplySheet({required this.kind, required this.orgId});

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  static const _sellerRoles = [
    ('collector', 'Collector', 'You gather recyclable material'),
    ('processor', 'Processor', 'You turn material into feedstock'),
    ('maker', 'Maker', 'You sell finished products'),
  ];
  static const _envActivities = [
    ('market', 'Material market'),
    ('territory', 'Territory'),
    ('trees', 'Tree monitoring'),
    ('fleet', 'Collector fleet'),
  ];
  static const _culturalRoles = [
    ('documentation', 'Heritage documentation', 'Documenting and archiving community knowledge'),
    ('council', 'Community voice', "Representing a community's heritage interests"),
    ('research', 'Research & education', 'Academic, archival or educational work'),
  ];

  String? _role;
  final Set<String> _acts = {};
  bool _busy = false, _showErrors = false;

  bool get _valid => widget.kind == 'envOps' ? _acts.isNotEmpty : _role != null;

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    if (!_valid) return;
    setState(() => _busy = true);
    final ref = FirebaseFirestore.instance.collection('organizations').doc(widget.orgId);
    try {
      switch (widget.kind) {
        case 'marketplace':
          await CommunityAuthService().applyForMarketplaceSeller(orgId: widget.orgId, sellerRole: _role!);
        case 'envOps':
          // Existing behaviour: Environmental Ops is self-serve.
          await ref.update({
            'envOpsStatus': 'approved',
            'envOpsActivities': _acts.toList(),
            'envOpsRegisteredAt': FieldValue.serverTimestamp(),
          });
        default:
          await ref.update({
            'culturalStatus': 'pending',
            'culturalRole': _role,
            'culturalRegisteredAt': FieldValue.serverTimestamp(),
          });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showCanopySnack(context, "Couldn't send that. Try again.", error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final (title, caption) = switch (widget.kind) {
      'marketplace' => ('Apply for Marketplace', 'The Canopy team reviews applications.'),
      'envOps' => ('Turn on Environmental Ops', 'Pick what you run. You can change this later.'),
      _ => ('Apply for Cultural Archive', 'The Canopy team reviews applications.'),
    };
    return CanopySheetBody(
      title: title,
      caption: caption,
      children: [
        if (widget.kind == 'envOps')
          for (final a in _envActivities)
            CanopyCheckRow(
              label: a.$2,
              value: _acts.contains(a.$1),
              onChanged: (v) => setState(() => v ? _acts.add(a.$1) : _acts.remove(a.$1)),
            )
        else
          for (final r in widget.kind == 'marketplace' ? _sellerRoles : _culturalRoles) ...[
            CanopyOptionCard(
              selected: _role == r.$1,
              title: r.$2,
              caption: r.$3,
              onTap: () => setState(() => _role = r.$1),
            ),
            const SizedBox(height: CanopySpace.s8),
          ],
        if (_showErrors && !_valid)
          Padding(
            padding: const EdgeInsets.only(top: CanopySpace.s8),
            child: Text(widget.kind == 'envOps' ? 'Pick at least one.' : 'Pick one.',
                style: CanopyType.caption.copyWith(color: p.danger)),
          ),
      ],
      actions: [
        CanopyButton(
          label: widget.kind == 'envOps' ? 'Turn on' : 'Send application',
          expand: true,
          loading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}
