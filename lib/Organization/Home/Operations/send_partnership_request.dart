// lib/Organization/Home/Operations/send_partnership_request.dart
//
// Send partnership request (ORG_HANDOFF §3.5, T): pick a target organisation
// (search Canopy orgs, or name one that isn't on Canopy yet), choose
// collaboration chips, add a message. For a Canopy org two mirrored docs are
// written — ours 'invited', theirs 'pending' — sharing a pairId, so the
// request shows under "Awaiting your response" on their side.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../theme/canopy_components.dart';

class SendPartnershipRequestScreen extends StatefulWidget {
  final String orgId;
  const SendPartnershipRequestScreen({super.key, required this.orgId});

  @override
  State<SendPartnershipRequestScreen> createState() => _SendPartnershipRequestScreenState();
}

class _Target {
  final String? id;
  final String name;
  final String? logo;
  final String sector;
  const _Target({this.id, required this.name, this.logo, this.sector = ''});
}

class _SendPartnershipRequestScreenState extends State<SendPartnershipRequestScreen> {
  static const _goals = [
    'Co-host events',
    'Share resources',
    'Joint fundraising',
    'Knowledge exchange',
    'Volunteer sharing',
    'Advocacy',
  ];

  final _message = TextEditingController();
  _Target? _target;
  final Set<String> _picked = {};
  bool _saving = false, _showErrors = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickTarget() async {
    final t = await showCanopySheet<_Target>(context, tall: true, builder: (_) => _OrgSearchSheet(selfId: widget.orgId));
    if (t != null) setState(() => _target = t);
  }

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    final t = _target;
    if (t == null || _picked.isEmpty) return;
    setState(() => _saving = true);
    final db = FirebaseFirestore.instance;
    try {
      final me = (await db.collection('organizations').doc(widget.orgId).get()).data() ?? {};
      final myName = ((me['org_name'] ?? me['name']) as String?) ?? 'Organisation';
      final pair = db.collection('orgPartners').doc().id;
      final goals = _picked.toList();
      final msg = _message.text.trim();
      final batch = db.batch();
      batch.set(db.collection('orgPartners').doc(), {
        'orgId': widget.orgId,
        'partnerOrgId': t.id,
        'partnerName': t.name,
        'partnerLogoUrl': t.logo,
        'partnerSector': t.sector,
        'partnershipGoal': goals.join(', '),
        'goals': goals,
        'message': msg,
        'status': 'invited',
        'pairId': pair,
        'sharedEvents': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (t.id != null) {
        batch.set(db.collection('orgPartners').doc(), {
          'orgId': t.id,
          'partnerOrgId': widget.orgId,
          'partnerName': myName,
          'partnerLogoUrl': me['logoUrl'] ?? me['profilePhoto'],
          'partnerSector': (me['sector'] ?? me['orgDesignation'] ?? '') as String,
          'partnerEmail': me['email'],
          'partnerPhone': me['phone'],
          'partnershipGoal': goals.join(', '),
          'goals': goals,
          'message': msg,
          'status': 'pending',
          'pairId': pair,
          'sharedEvents': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (!mounted) return;
      showCanopySnack(context, 'Request sent to ${t.name}.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't send the request. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final t = _target;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Partnership request'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          Text('ORGANISATION', style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.s8),
          if (t == null)
            CanopyPickerField(
              label: 'Who do you want to work with?',
              value: null,
              placeholder: 'Search organisations',
              error: _showErrors ? 'Choose an organisation.' : null,
              onTap: _pickTarget,
            )
          else
            CanopyCard(
              padding: const EdgeInsets.all(CanopySpace.s12),
              onTap: _pickTarget,
              child: Row(children: [
                CanopyAvatar(url: t.logo, name: t.name, size: 40, org: true),
                const SizedBox(width: CanopySpace.s12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.name, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                    Text(t.id == null ? 'Not on Canopy yet — tracked on your side only' : (t.sector.isEmpty ? 'On Canopy' : t.sector),
                        style: CanopyType.caption.copyWith(color: p.inkMuted)),
                  ]),
                ),
                Text('Change', style: CanopyType.label.copyWith(color: p.primaryInk)),
              ]),
            ),
          const SizedBox(height: CanopySpace.section),
          Text('WORK TOGETHER ON', style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.s8),
          Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
            for (final g in _goals)
              CanopyFilterChip(
                label: g,
                selected: _picked.contains(g),
                onTap: () => setState(() => _picked.contains(g) ? _picked.remove(g) : _picked.add(g)),
              ),
          ]),
          if (_showErrors && _picked.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: CanopySpace.s8),
              child: Text('Pick at least one.', style: CanopyType.caption.copyWith(color: p.danger)),
            ),
          const SizedBox(height: CanopySpace.section),
          CanopyTextField(
            label: 'Message',
            hint: 'Say who you are and what you have in mind',
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: 600,
          ),
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(label: 'Send request', expand: true, loading: _saving, onPressed: _submit),
      ]),
    );
  }
}

class _OrgSearchSheet extends StatefulWidget {
  final String selfId;
  const _OrgSearchSheet({required this.selfId});

  @override
  State<_OrgSearchSheet> createState() => _OrgSearchSheetState();
}

class _OrgSearchSheetState extends State<_OrgSearchSheet> {
  String _q = '';
  late final Future<List<_Target>> _orgs = _load();

  Future<List<_Target>> _load() async {
    final s = await FirebaseFirestore.instance.collection('organizations').limit(300).get();
    return s.docs
        .where((d) => d.id != widget.selfId)
        .map((d) {
          final m = d.data();
          return _Target(
            id: d.id,
            name: ((m['org_name'] ?? m['name']) as String?)?.trim() ?? '',
            logo: (m['logoUrl'] ?? m['profilePhoto']) as String?,
            sector: [(m['orgDesignation'] ?? m['sector']) as String?, m['city'] as String?]
                .whereType<String>()
                .where((e) => e.trim().isNotEmpty)
                .join(' · '),
          );
        })
        .where((t) => t.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopySheetBody(
      title: 'Find an organisation',
      children: [
        CanopyTextField.search(
            hint: 'Organisation name', autofocus: true, onChanged: (v) => setState(() => _q = v.trim())),
        const SizedBox(height: CanopySpace.s12),
        FutureBuilder<List<_Target>>(
          future: _orgs,
          builder: (context, snap) {
            if (snap.hasError) return const CanopyErrorState(inline: true, title: "Couldn't load organisations.");
            if (!snap.hasData) return const CanopyListSkeleton(rows: 4);
            final q = _q.toLowerCase();
            final list = snap.data!.where((t) => q.isEmpty || t.name.toLowerCase().contains(q)).take(40).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (list.isNotEmpty)
                CanopyListGroup(children: [
                  for (final t in list)
                    CanopyListRow(
                      leading: CanopyAvatar(url: t.logo, name: t.name, size: 36, org: true),
                      title: t.name,
                      subtitle: t.sector.isEmpty ? null : t.sector,
                      chevron: false,
                      onTap: () => Navigator.pop(context, t),
                    ),
                ])
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: CanopySpace.s12),
                  child: Text('No organisations match.', style: CanopyType.body.copyWith(color: p.inkMuted)),
                ),
              if (_q.isNotEmpty) ...[
                const SizedBox(height: CanopySpace.s12),
                CanopyButton.secondary(
                  label: 'Add "$_q" — not on Canopy',
                  expand: true,
                  onPressed: () => Navigator.pop(context, _Target(name: _q)),
                ),
              ],
            ]);
          },
        ),
      ],
    );
  }
}
