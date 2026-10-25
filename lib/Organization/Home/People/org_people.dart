// lib/Organization/Home/People/org_people.dart
//
// People (ORG_HANDOFF §3.4). Underline tabs Members / Teams.
//   Members: counts (total · active · pending/invited), role filter chips,
//     dense rows (avatar · name + role/team · membership label · ⋯), sticky
//     "Invite people" → invite sheet (Phone / Email, contact chips, role,
//     team, "Send N invites"). Invites are real OrgMembers docs with status
//     'invited' (the old sheet was a TODO that only showed a snackbar).
//   Teams: capacity bar (ink), lead, Manage (name, description, capacity,
//     lead, members; delete confirmed).
// Empty: "Invite people to join your organisation".

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../theme/canopy_components.dart';
import '../../org_ui.dart';
import '../org_home.dart';

enum MemberRole { admin, coordinator, member, observer }

extension MemberRoleX on MemberRole {
  String get label => switch (this) {
        MemberRole.admin => 'Admin',
        MemberRole.coordinator => 'Coordinator',
        MemberRole.member => 'Member',
        MemberRole.observer => 'Observer',
      };
  String get caption => switch (this) {
        MemberRole.admin => 'Manages the organisation and its people',
        MemberRole.coordinator => 'Runs events and teams',
        MemberRole.member => 'Takes part in activities',
        MemberRole.observer => 'Can view, not edit',
      };
}

MemberRole _role(String? s) =>
    MemberRole.values.firstWhere((r) => r.name == s, orElse: () => MemberRole.member);

MembershipStatus _membership(String? s) => switch (s) {
      'inactive' => MembershipStatus.inactive,
      'pending' => MembershipStatus.pending,
      'invited' => MembershipStatus.invited,
      _ => MembershipStatus.active,
    };

class OrgPeopleScreen extends StatefulWidget {
  const OrgPeopleScreen({super.key});

  @override
  State<OrgPeopleScreen> createState() => _OrgPeopleScreenState();
}

class _OrgPeopleScreenState extends State<OrgPeopleScreen> {
  final _db = FirebaseFirestore.instance;
  String? _orgId;
  bool _loaded = false;
  int _tab = 0;
  MemberRole? _roleFilter;
  ValueNotifier<String?>? _sub;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sub = OrgShellScope.of(context)?.subTab;
    if (sub != _sub) {
      _sub?.removeListener(_onSub);
      _sub = sub?..addListener(_onSub);
    }
  }

  void _onSub() {
    final v = _sub?.value;
    if (v == 'teams') setState(() => _tab = 1);
    if (v == 'members') setState(() => _tab = 0);
  }

  @override
  void dispose() {
    _sub?.removeListener(_onSub);
    super.dispose();
  }

  Future<void> _loadOrg() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final d = await _db.collection('Users').doc(uid).get();
        _orgId = d.data()?['orgId'] as String?;
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return CanopyScaffold(appBar: canopyAppBar(context, title: 'People', showBack: false),
          body: const Center(child: CircularProgressIndicator()));
    }
    final orgId = _orgId;
    if (orgId == null) {
      return CanopyScaffold(
          appBar: canopyAppBar(context, title: 'People', showBack: false),
          body: const CanopyEmptyState(
              icon: Icons.apartment_outlined, title: 'No organisation is linked to this account'));
    }
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'People', showBack: false),
      body: Column(children: [
        CanopyUnderlineTabs(
            tabs: const ['Members', 'Teams'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        Expanded(
          child: _tab == 0
              ? _members(orgId)
              : _Teams(orgId: orgId),
        ),
      ]),
      sticky: StickyActionBar(children: [
        _tab == 0
            ? CanopyButton(
                label: 'Invite people',
                expand: true,
                onPressed: () => showCanopySheet(context, tall: true, builder: (_) => _InviteSheet(orgId: orgId)))
            : CanopyButton(
                label: 'New team',
                expand: true,
                onPressed: () => showCanopySheet(context, builder: (_) => _TeamSheet(orgId: orgId))),
      ]),
    );
  }

  Widget _members(String orgId) {
    final p = context.canopy;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('OrgMembers').where('orgId', isEqualTo: orgId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const CanopyErrorState(title: "Couldn't load members");
        if (!snap.hasData) {
          return ListView(
              padding: const EdgeInsets.all(CanopySpace.gutter),
              children: const [CanopyListSkeleton(rows: 5)]);
        }
        final all = snap.data!.docs.where((d) => d.data()['status'] != 'removed').toList();
        final active = all.where((d) => _membership(d.data()['status'] as String?) == MembershipStatus.active).length;
        final waiting = all.where((d) {
          final s = _membership(d.data()['status'] as String?);
          return s == MembershipStatus.pending || s == MembershipStatus.invited;
        }).length;
        final shown = _roleFilter == null ? all : all.where((d) => _role(d.data()['role'] as String?) == _roleFilter).toList()
          ..sort((a, b) => ((a.data()['name'] ?? a.data()['contact'] ?? '') as String)
              .toLowerCase()
              .compareTo(((b.data()['name'] ?? b.data()['contact'] ?? '') as String).toLowerCase()));

        if (all.isEmpty) {
          return const CanopyEmptyState(
            icon: Icons.group_add_outlined,
            title: 'Invite people to join your organisation',
            line: 'Add the people who run things with you, then organise them into teams.',
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: CanopySpace.s32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, 0),
              child: Row(children: [
                Expanded(child: MetricTile(value: '${all.length}', label: 'Total')),
                const SizedBox(width: CanopySpace.s16),
                Expanded(child: MetricTile(value: '$active', label: 'Active')),
                const SizedBox(width: CanopySpace.s16),
                Expanded(child: MetricTile(value: '$waiting', label: 'Pending')),
              ]),
            ),
            const SizedBox(height: CanopySpace.s8),
            CanopyChipRail(chips: [
              CanopyFilterChip(label: 'All', selected: _roleFilter == null, onTap: () => setState(() => _roleFilter = null)),
              for (final r in MemberRole.values)
                CanopyFilterChip(
                  label: r.label,
                  count: all.where((d) => _role(d.data()['role'] as String?) == r).length,
                  selected: _roleFilter == r,
                  onTap: () => setState(() => _roleFilter = _roleFilter == r ? null : r),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
              child: shown.isEmpty
                  ? CanopyEmptyState(boxed: true, icon: Icons.person_outline, title: 'No ${_roleFilter!.label.toLowerCase()}s yet')
                  : CanopyListGroup(children: [
                      for (final d in shown) _MemberRow(id: d.id, data: d.data()),
                    ]),
            ),
            if (waiting > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, 0),
                child: Text('Invited people appear as Active once they join.',
                    style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ),
          ],
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const _MemberRow({required this.id, required this.data});

  Future<void> _approve(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('OrgMembers')
          .doc(id)
          .update({'status': 'active', 'joinedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      if (context.mounted) showCanopySnack(context, "Couldn't approve. Try again.", error: true);
    }
  }

  Future<void> _actions(BuildContext context) async {
    final db = FirebaseFirestore.instance;
    final status = _membership(data['status'] as String?);
    final name = (data['name'] ?? data['contact'] ?? 'this person') as String;
    final action = await showCanopySheet<String>(
      context,
      builder: (ctx) => CanopySheetBody(
        title: name,
        children: [
          CanopyListGroup(header: 'Role', children: [
            for (final r in MemberRole.values)
              CanopyListRow(
                title: r.label,
                subtitle: r.caption,
                chevron: false,
                trailing: _role(data['role'] as String?) == r ? Icon(Icons.check, color: ctx.canopy.ink) : null,
                onTap: () => Navigator.pop(ctx, 'role:${r.name}'),
              ),
          ]),
          const SizedBox(height: CanopySpace.s16),
          CanopyListGroup(children: [
            if (status == MembershipStatus.pending)
              CanopyListRow(icon: Icons.how_to_reg_outlined, title: 'Approve request', onTap: () => Navigator.pop(ctx, 'active')),
            if (status == MembershipStatus.active)
              CanopyListRow(icon: Icons.pause_circle_outline, title: 'Mark inactive', onTap: () => Navigator.pop(ctx, 'inactive')),
            if (status == MembershipStatus.inactive)
              CanopyListRow(icon: Icons.play_circle_outline, title: 'Mark active', onTap: () => Navigator.pop(ctx, 'active')),
            CanopyListRow(
              icon: Icons.person_remove_outlined,
              title: switch (status) {
                MembershipStatus.invited => 'Cancel invite',
                MembershipStatus.pending => 'Decline request',
                _ => 'Remove from organisation',
              },
              titleColor: ctx.canopy.danger,
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ]),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    try {
      if (action.startsWith('role:')) {
        await db.collection('OrgMembers').doc(id).update({'role': action.substring(5)});
      } else if (action == 'remove') {
        final ok = await showCanopyConfirm(context,
            title: status == MembershipStatus.invited ? 'Cancel this invite?' : 'Remove $name?',
            message: status == MembershipStatus.invited
                ? 'The invite is withdrawn.'
                : "They lose access to your organisation's workspace.",
            confirmLabel: status == MembershipStatus.invited ? 'Cancel invite' : 'Remove',
            danger: true);
        if (ok) {
          if (data['grantsAccess'] == true) {
            // Access lives on their account, so only the server can take it away.
            await FirebaseFunctions.instance.httpsCallable('removeOrgAccess').call({'memberId': id});
          } else {
            await db.collection('OrgMembers').doc(id).delete();
          }
        }
      } else {
        await db.collection('OrgMembers').doc(id).update({'status': action});
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) showCanopySnack(context, e.message ?? "Couldn't update. Try again.", error: true);
    } catch (_) {
      if (context.mounted) showCanopySnack(context, "Couldn't update. Try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? data['contact'] ?? 'Unknown') as String;
    final role = _role(data['role'] as String?);
    final status = _membership(data['status'] as String?);
    final sub = [
      if (data['grantsAccess'] == true) (data['accessRole'] == 'admin' ? 'Admin access' : 'Editor access') else role.label,
      if ((data['teamName'] as String?)?.isNotEmpty ?? false) data['teamName'] as String,
      if ((data['area'] as String?)?.isNotEmpty ?? false) data['area'] as String,
    ].join(' · ');
    return DenseRow(
      leading: CanopyAvatar(url: data['avatarUrl'] as String?, name: name, size: 40),
      title: name,
      subtitle: sub,
      status: MembershipLabel(status),
      trailing: status == MembershipStatus.pending
          ? CanopyButton.secondary(label: 'Approve', size: CanopyButtonSize.compact, onPressed: () => _approve(context))
          : CanopyIconButton(icon: Icons.more_horiz, tooltip: 'Manage $name', onPressed: () => _actions(context)),
      onTap: () => _actions(context),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INVITE
// ─────────────────────────────────────────────────────────────────────────────

class _InviteSheet extends StatefulWidget {
  final String orgId;
  const _InviteSheet({required this.orgId});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  bool _byPhone = true;
  final _input = TextEditingController();
  final List<String> _contacts = [];
  MemberRole _role = MemberRole.member;
  bool _access = false; // email only: can run the organisation
  String _accessRole = 'editor';
  String? _teamId, _teamName;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String? _normalise(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (_byPhone) {
      var d = t.replaceAll(RegExp(r'\D'), '');
      if (d.startsWith('254')) d = d.substring(3);
      if (d.startsWith('0')) d = d.substring(1);
      return d.length == 9 ? '+254$d' : null;
    }
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? t.toLowerCase() : null;
  }

  void _add() {
    final n = _normalise(_input.text);
    if (n == null) {
      setState(() => _error = _byPhone ? 'Enter a Kenyan mobile number.' : 'Enter a valid email.');
      return;
    }
    setState(() {
      if (!_contacts.contains(n)) _contacts.add(n);
      _input.clear();
      _error = null;
    });
  }

  Future<void> _pickTeam() async {
    final snap = await FirebaseFirestore.instance.collection('Teams').where('orgId', isEqualTo: widget.orgId).get();
    if (!mounted) return;
    final picked = await showCanopySheet<(String?, String?)>(
      context,
      builder: (ctx) => CanopySheetBody(title: 'Team', children: [
        CanopyListGroup(children: [
          CanopyListRow(title: 'No team', chevron: false, onTap: () => Navigator.pop(ctx, (null, null))),
          for (final d in snap.docs)
            CanopyListRow(
                title: (d.data()['name'] as String?) ?? 'Team',
                chevron: false,
                onTap: () => Navigator.pop(ctx, (d.id, d.data()['name'] as String?))),
        ]),
      ]),
    );
    if (picked != null) {
      setState(() {
        _teamId = picked.$1;
        _teamName = picked.$2;
      });
    }
  }

  Future<void> _send() async {
    if (_input.text.trim().isNotEmpty) _add();
    if (_contacts.isEmpty) {
      setState(() => _error ??= 'Add at least one ${_byPhone ? 'number' : 'email'}.');
      return;
    }
    setState(() => _sending = true);
    try {
      if (!_byPhone && _access) {
        // Giving someone access to run the organisation is done on the server.
        final call = FirebaseFunctions.instance.httpsCallable('inviteOrgRep');
        for (final c in _contacts) {
          await call.call({'email': c, 'accessRole': _accessRole, 'teamId': _teamId, 'teamName': _teamName});
        }
        if (!mounted) return;
        Navigator.pop(context);
        showCanopySnack(context, '${_contacts.length} invite${_contacts.length == 1 ? '' : 's'} sent. They accept it when they sign in with that email.');
        return;
      }
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      for (final c in _contacts) {
        batch.set(db.collection('OrgMembers').doc(), {
          'orgId': widget.orgId,
          'contact': c,
          'contactType': _byPhone ? 'phone' : 'email',
          'name': null,
          'role': _role.name,
          'status': 'invited',
          if (_teamId != null) 'teamId': _teamId,
          if (_teamName != null) 'teamName': _teamName,
          'invitedBy': FirebaseAuth.instance.currentUser?.uid,
          'invitedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (!mounted) return;
      Navigator.pop(context);
      showCanopySnack(context, '${_contacts.length} invite${_contacts.length == 1 ? '' : 's'} added to your members.');
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? "Invites didn't save. Try again.");
    } catch (_) {
      if (mounted) setState(() => _error = "Invites didn't save. Try again.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopySheetBody(
      title: 'Invite people',
      caption: 'They appear in your members as Invited until they join.',
      children: [
        CanopySegmented<bool>(
          options: const [(true, 'Phone'), (false, 'Email')],
          value: _byPhone,
          onChanged: (v) => setState(() {
            _byPhone = v;
            _error = null;
          }),
        ),
        const SizedBox(height: CanopySpace.s12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _byPhone
                ? CanopyTextField.phone(
                    label: 'Mobile number', controller: _input, error: _error, onSubmitted: (_) => _add())
                : CanopyTextField(
                    label: 'Email',
                    controller: _input,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                    error: _error,
                    onSubmitted: (_) => _add()),
          ),
          const SizedBox(width: CanopySpace.s8),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: CanopyButton.secondary(label: 'Add', size: CanopyButtonSize.compact, onPressed: _add),
          ),
        ]),
        if (_contacts.isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s8),
          Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s4, children: [
            for (final c in _contacts) CanopyRemovableChip(label: c, onRemove: () => setState(() => _contacts.remove(c))),
          ]),
        ],
        const SizedBox(height: CanopySpace.s16),
        if (!_byPhone) ...[
          CanopyListRow(
            title: 'Can run the organisation',
            subtitle: 'They sign in with this email and get your organisation workspace.',
            chevron: false,
            trailing: Switch(value: _access, onChanged: (v) => setState(() => _access = v)),
          ),
          const SizedBox(height: CanopySpace.s8),
        ],
        if (!_byPhone && _access) ...[
          Text('Access', style: CanopyType.label.copyWith(color: p.ink)),
          Wrap(spacing: CanopySpace.s8, children: [
            CanopyFilterChip(label: 'Admin', selected: _accessRole == 'admin', onTap: () => setState(() => _accessRole = 'admin')),
            CanopyFilterChip(label: 'Editor', selected: _accessRole == 'editor', onTap: () => setState(() => _accessRole = 'editor')),
          ]),
          Text(
              _accessRole == 'admin'
                  ? 'Everything an editor can do, and can invite or remove people.'
                  : 'Runs events, articles and the archive. Cannot manage who has access.',
              style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ] else ...[
          Text('Role', style: CanopyType.label.copyWith(color: p.ink)),
          Wrap(spacing: CanopySpace.s8, children: [
            for (final r in MemberRole.values)
              CanopyFilterChip(label: r.label, selected: _role == r, onTap: () => setState(() => _role = r)),
          ]),
          Text(_role.caption, style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ],
        const SizedBox(height: CanopySpace.s12),
        CanopyPickerField(label: 'Team (optional)', value: _teamName, placeholder: 'No team', onTap: _pickTeam),
      ],
      actions: [
        CanopyButton(
          label: _contacts.isEmpty ? 'Send invites' : 'Send ${_contacts.length} invite${_contacts.length == 1 ? '' : 's'}',
          expand: true,
          loading: _sending,
          onPressed: _send,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAMS
// ─────────────────────────────────────────────────────────────────────────────

class _Teams extends StatelessWidget {
  final String orgId;
  const _Teams({required this.orgId});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('Teams').where('orgId', isEqualTo: orgId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const CanopyErrorState(title: "Couldn't load teams");
        if (!snap.hasData) {
          return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [CanopyListSkeleton(rows: 3)]);
        }
        final teams = snap.data!.docs;
        if (teams.isEmpty) {
          return const CanopyEmptyState(
            icon: Icons.groups_2_outlined,
            title: 'No teams yet',
            line: 'Group people into teams to give them a lead and a size.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
          itemCount: teams.length,
          separatorBuilder: (_, __) => const SizedBox(height: CanopySpace.s12),
          itemBuilder: (_, i) {
            final d = teams[i].data();
            final members = (d['memberIds'] as List?)?.length ?? (d['memberCount'] as int? ?? 0);
            final capacity = (d['capacity'] as num?)?.toInt();
            return CanopyCard(
              padding: const EdgeInsets.all(CanopyWorkspace.cardPadding),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text((d['name'] as String?) ?? 'Team', style: CanopyType.subhead.copyWith(color: p.ink))),
                  CanopyButton.quiet(
                    label: 'Manage',
                    size: CanopyButtonSize.compact,
                    onPressed: () => showCanopySheet(context,
                        tall: true, builder: (_) => _TeamSheet(orgId: orgId, teamId: teams[i].id, data: d)),
                  ),
                ]),
                if ((d['description'] as String?)?.isNotEmpty ?? false)
                  Text(d['description'] as String, style: CanopyType.caption.copyWith(color: p.inkMuted)),
                const SizedBox(height: CanopySpace.s8),
                if (capacity != null && capacity > 0) ...[
                  CanopyProgressBar(value: members / capacity, ink: true),
                  const SizedBox(height: CanopySpace.s4),
                ],
                Text(
                  [
                    capacity != null && capacity > 0 ? '$members of $capacity people' : '$members ${members == 1 ? 'person' : 'people'}',
                    if ((d['leadName'] as String?)?.isNotEmpty ?? false) 'Lead: ${d['leadName']}',
                  ].join(' · '),
                  style: CanopyType.caption.copyWith(color: p.inkMuted),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

class _TeamSheet extends StatefulWidget {
  final String orgId;
  final String? teamId;
  final Map<String, dynamic>? data;
  const _TeamSheet({required this.orgId, this.teamId, this.data});

  @override
  State<_TeamSheet> createState() => _TeamSheetState();
}

class _TeamSheetState extends State<_TeamSheet> {
  late final _name = TextEditingController(text: widget.data?['name'] as String?);
  late final _desc = TextEditingController(text: widget.data?['description'] as String?);
  late final _cap = TextEditingController(text: (widget.data?['capacity'] as num?)?.toString());
  late final Set<String> _memberIds = {...?(widget.data?['memberIds'] as List?)?.cast<String>()};
  late String? _leadId = widget.data?['leadId'] as String?;
  late String? _leadName = widget.data?['leadName'] as String?;
  bool _saving = false;
  bool _showErrors = false;

  late final Future<QuerySnapshot<Map<String, dynamic>>> _members =
      FirebaseFirestore.instance.collection('OrgMembers').where('orgId', isEqualTo: widget.orgId).get();

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _cap.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final db = FirebaseFirestore.instance;
    final data = {
      'orgId': widget.orgId,
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'capacity': int.tryParse(_cap.text.trim()),
      'memberIds': _memberIds.toList(),
      'memberCount': _memberIds.length,
      'leadId': _leadId,
      'leadName': _leadName,
    };
    try {
      if (widget.teamId == null) {
        await db.collection('Teams').add({...data, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await db.collection('Teams').doc(widget.teamId).update(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save the team.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showCanopyConfirm(context,
        title: 'Delete ${widget.data?['name'] ?? 'this team'}?',
        message: 'People stay in your organisation; only the team goes.',
        confirmLabel: 'Delete team',
        danger: true);
    if (!ok) return;
    try {
      await FirebaseFirestore.instance.collection('Teams').doc(widget.teamId).delete();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't delete the team.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopySheetBody(
      title: widget.teamId == null ? 'New team' : 'Manage team',
      children: [
        CanopyTextField(
            label: 'Name',
            hint: 'Clean-up crew North',
            controller: _name,
            error: _showErrors && _name.text.trim().isEmpty ? 'Name the team.' : null,
            onChanged: (_) => setState(() {})),
        const SizedBox(height: CanopySpace.s12),
        CanopyTextField(label: 'What does it do? (optional)', controller: _desc, minLines: 2, maxLines: 4),
        const SizedBox(height: CanopySpace.s12),
        CanopyTextField(label: 'Size limit (optional)', hint: 'No limit', controller: _cap, keyboardType: TextInputType.number),
        const SizedBox(height: CanopySpace.s16),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: _members,
          builder: (context, snap) {
            if (!snap.hasData) return const CanopyListSkeleton(rows: 2);
            final people = snap.data!.docs
                .where((d) => _membership(d.data()['status'] as String?) != MembershipStatus.invited)
                .toList();
            if (people.isEmpty) {
              return Text('Invite people first, then add them to teams.',
                  style: CanopyType.caption.copyWith(color: p.inkMuted));
            }
            return CanopyListGroup(header: 'People', children: [
              for (final d in people)
                CanopyListRow(
                  leading: CanopyAvatar(name: (d.data()['name'] as String?) ?? '', size: 32),
                  title: (d.data()['name'] as String?) ?? 'Member',
                  subtitle: _leadId == d.id ? 'Lead' : null,
                  chevron: false,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_memberIds.contains(d.id))
                      CanopyButton.quiet(
                        label: _leadId == d.id ? 'Lead' : 'Make lead',
                        size: CanopyButtonSize.compact,
                        onPressed: () => setState(() {
                          _leadId = d.id;
                          _leadName = d.data()['name'] as String?;
                        }),
                      ),
                    Checkbox(
                      value: _memberIds.contains(d.id),
                      activeColor: p.ink,
                      checkColor: p.canvas,
                      onChanged: (v) => setState(() {
                        v == true ? _memberIds.add(d.id) : _memberIds.remove(d.id);
                        if (v != true && _leadId == d.id) {
                          _leadId = null;
                          _leadName = null;
                        }
                      }),
                    ),
                  ]),
                ),
            ]);
          },
        ),
      ],
      actions: [
        CanopyButton(label: widget.teamId == null ? 'Create team' : 'Save team', expand: true, loading: _saving, onPressed: _save),
        if (widget.teamId != null) CanopyButton.quietDanger(label: 'Delete team', expand: true, onPressed: _delete),
      ],
    );
  }
}
