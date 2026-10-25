// lib/Organization/Access/org_picker.dart
//
// "Your organisations": shown in the workspace switcher when a person can run
// more than one organisation (they registered one, or accepted invites to
// others). Choosing one runs a server function that points their account at it,
// then reopens the organisation workspace.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Services/storage/user_persistence.dart';
import '../../theme/canopy_components.dart';
import '../Home/org_home.dart';

class _OrgChoice {
  final String id;
  final String name;
  final String? logo;
  final String role;
  const _OrgChoice(this.id, this.name, this.logo, this.role);
}

Future<(List<_OrgChoice>, String?)> _load() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return (<_OrgChoice>[], null);
  final db = FirebaseFirestore.instance;
  final found = <String, _OrgChoice>{};

  final owned = await db.collection('organizations').where('org_rep_uid', isEqualTo: uid).get();
  for (final d in owned.docs) {
    final m = d.data();
    found[d.id] = _OrgChoice(d.id, '${m['org_name'] ?? m['name'] ?? 'Organisation'}', (m['logoUrl'] ?? m['profilePhoto']) as String?, 'Owner');
  }
  final access = await db
      .collection('OrgMembers')
      .where('userId', isEqualTo: uid)
      .where('grantsAccess', isEqualTo: true)
      .where('status', isEqualTo: 'active')
      .get();
  for (final a in access.docs) {
    final orgId = '${a.data()['orgId']}';
    if (found.containsKey(orgId)) continue;
    final m = (await db.collection('organizations').doc(orgId).get()).data();
    if (m == null) continue;
    found[orgId] = _OrgChoice(orgId, '${m['org_name'] ?? m['name'] ?? 'Organisation'}', (m['logoUrl'] ?? m['profilePhoto']) as String?,
        a.data()['accessRole'] == 'admin' ? 'Admin' : 'Editor');
  }
  final current = ((await db.collection('Users').doc(uid).get()).data()?['orgId']) as String?;
  final list = found.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return (list, current);
}

class OrgPickerGroup extends StatefulWidget {
  /// Closes the sheet this is shown in.
  final VoidCallback onClose;
  const OrgPickerGroup({super.key, required this.onClose});

  @override
  State<OrgPickerGroup> createState() => _OrgPickerGroupState();
}

class _OrgPickerGroupState extends State<OrgPickerGroup> {
  late final Future<(List<_OrgChoice>, String?)> _future = _load();
  String? _switching;

  Future<void> _switch(_OrgChoice c) async {
    setState(() => _switching = c.id);
    try {
      await FirebaseFunctions.instance.httpsCallable('switchActiveOrg').call({'orgId': c.id});
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await UserPersistence.refreshUserProfile(uid);
      if (!mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      widget.onClose();
      nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const OrganizationHome()), (_) => false);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) showCanopySnack(context, e.message ?? "Couldn't switch. Try again.", error: true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't switch. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _switching = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<_OrgChoice>, String?)>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null || data.$1.length < 2) return const SizedBox.shrink();
        final p = context.canopy;
        return Padding(
          padding: const EdgeInsets.only(top: CanopySpace.s16),
          child: CanopyListGroup(header: 'Your organisations', children: [
            for (final c in data.$1)
              CanopyListRow(
                leading: CanopyAvatar(url: c.logo, name: c.name, size: 36, org: true),
                title: c.name,
                subtitle: c.role,
                chevron: c.id != data.$2,
                trailing: c.id == data.$2
                    ? StatusLabel('Current', color: p.success)
                    : (_switching == c.id ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null),
                onTap: c.id == data.$2 || _switching != null ? null : () => _switch(c),
              ),
          ]),
        );
      },
    );
  }
}
