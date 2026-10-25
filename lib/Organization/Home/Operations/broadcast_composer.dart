// lib/Organization/Home/Operations/broadcast_composer.dart
//
// BroadcastComposer (ORG_HANDOFF §2): audience segmented (All members / A
// team / Partners), title + message, Urgent switch ("Pins to the top of
// members' Home"), optional expiry, primary "Send to N members".
//
// Writes announcements/{id} in the shape the member Home + Announcements
// screens read: orgId, orgName, orgLogoUrl, title, body, isUrgent, audience,
// expiresAt, createdAt (the old broadcast wrote only body/sentAt, so it never
// appeared on Home — and the rules refused it on create; both fixed).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../theme/canopy_components.dart';

enum BroadcastAudience { all, team, partners }

class BroadcastComposerScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  final String? orgLogoUrl;
  const BroadcastComposerScreen(
      {super.key, required this.orgId, required this.orgName, this.orgLogoUrl});

  @override
  State<BroadcastComposerScreen> createState() => _BroadcastComposerScreenState();
}

class _BroadcastComposerScreenState extends State<BroadcastComposerScreen> {
  final _db = FirebaseFirestore.instance;
  final _title = TextEditingController();
  final _body = TextEditingController();
  BroadcastAudience _audience = BroadcastAudience.all;
  String? _teamId;
  String? _teamName;
  int? _teamSize;
  bool _urgent = false;
  int _expiryDays = 14;
  bool _sending = false;
  bool _showErrors = false;

  late final Future<int> _memberCount = _db
      .collection('OrgMembers')
      .where('orgId', isEqualTo: widget.orgId)
      .count()
      .get()
      .then((a) => a.count ?? 0)
      .catchError((_) => 0);
  late final Future<int> _partnerCount = _db
      .collection('orgPartners')
      .where('orgId', isEqualTo: widget.orgId)
      .get()
      .then((s) => s.docs.where((d) => d.data()['status'] == 'active').length)
      .catchError((_) => 0);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickTeam() async {
    final snap = await _db.collection('Teams').where('orgId', isEqualTo: widget.orgId).get();
    if (!mounted) return;
    final picked = await showCanopySheet<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context,
      builder: (ctx) => CanopySheetBody(
        title: 'Which team?',
        children: [
          if (snap.docs.isEmpty)
            const CanopyEmptyState(
                boxed: true, icon: Icons.groups_outlined, title: 'No teams yet',
                line: 'Create teams in People → Teams.')
          else
            CanopyListGroup(children: [
              for (final d in snap.docs)
                CanopyListRow(
                  icon: Icons.groups_outlined,
                  title: (d.data()['name'] as String?) ?? 'Team',
                  subtitle: '${(d.data()['memberIds'] as List?)?.length ?? 0} people',
                  onTap: () => Navigator.pop(ctx, d),
                ),
            ]),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _teamId = picked.id;
        _teamName = picked.data()['name'] as String?;
        _teamSize = (picked.data()['memberIds'] as List?)?.length ?? 0;
      });
    }
  }

  Future<void> _send(int reach) async {
    setState(() => _showErrors = true);
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    if (_audience == BroadcastAudience.team && _teamId == null) return;
    setState(() => _sending = true);
    try {
      await _db.collection('announcements').add({
        'orgId': widget.orgId,
        'orgName': widget.orgName,
        'orgLogoUrl': widget.orgLogoUrl,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'type': 'update',
        'isUrgent': _urgent,
        'audience': _audience.name,
        if (_teamId != null) 'teamId': _teamId,
        'recipientCount': reach,
        'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(days: _expiryDays))),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'sentAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      showCanopySnack(context, 'Announcement sent.');
    } catch (_) {
      if (mounted) showCanopySnack(context, "Your announcement didn't send.", error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return FutureBuilder<List<int>>(
      future: Future.wait([_memberCount, _partnerCount]),
      builder: (context, counts) {
        final members = counts.data?[0] ?? 0;
        final partners = counts.data?[1] ?? 0;
        final reach = switch (_audience) {
          BroadcastAudience.all => members,
          BroadcastAudience.team => _teamSize ?? 0,
          BroadcastAudience.partners => partners,
        };
        final noun = _audience == BroadcastAudience.partners
            ? (reach == 1 ? 'partner' : 'partners')
            : (reach == 1 ? 'member' : 'members');
        return CanopyScaffold(
          appBar: canopyAppBar(context, title: 'New announcement'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
                CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
            children: [
              Text('Who is it for?', style: CanopyType.label.copyWith(color: p.ink)),
              const SizedBox(height: CanopySpace.s4 + 2),
              CanopySegmented<BroadcastAudience>(
                options: const [
                  (BroadcastAudience.all, 'All members'),
                  (BroadcastAudience.team, 'A team'),
                  (BroadcastAudience.partners, 'Partners'),
                ],
                value: _audience,
                onChanged: (v) {
                  setState(() => _audience = v);
                  if (v == BroadcastAudience.team && _teamId == null) _pickTeam();
                },
              ),
              if (_audience == BroadcastAudience.team) ...[
                const SizedBox(height: CanopySpace.s12),
                CanopyPickerField(
                  label: 'Team',
                  value: _teamName,
                  placeholder: 'Choose a team',
                  error: _showErrors && _teamId == null ? 'Choose which team.' : null,
                  onTap: _pickTeam,
                ),
              ],
              const SizedBox(height: CanopySpace.s16),
              CanopyTextField(
                label: 'Title',
                hint: 'Clean-up moved to Sunday',
                controller: _title,
                maxLength: 80,
                error: _showErrors && _title.text.trim().isEmpty ? 'Add a short title.' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: CanopySpace.s16),
              CanopyTextField(
                label: 'Message',
                controller: _body,
                minLines: 4,
                maxLines: 10,
                maxLength: 1000,
                error: _showErrors && _body.text.trim().isEmpty ? 'Write the message.' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: CanopySpace.s8),
              CanopySwitchRow(
                title: 'Urgent',
                caption: "Pins to the top of members' Home",
                value: _urgent,
                onChanged: (v) => setState(() => _urgent = v),
              ),
              const SizedBox(height: CanopySpace.s8),
              Text('Show for', style: CanopyType.label.copyWith(color: p.ink)),
              Wrap(spacing: CanopySpace.s8, children: [
                for (final d in const [3, 7, 14, 30])
                  CanopyFilterChip(
                    label: '$d days',
                    selected: _expiryDays == d,
                    onTap: () => setState(() => _expiryDays = d),
                  ),
              ]),
            ],
          ),
          sticky: StickyActionBar(children: [
            CanopyButton(
              label: counts.hasData ? 'Send to $reach $noun' : 'Send',
              expand: true,
              loading: _sending,
              onPressed: () => _send(reach),
            ),
          ]),
        );
      },
    );
  }
}
