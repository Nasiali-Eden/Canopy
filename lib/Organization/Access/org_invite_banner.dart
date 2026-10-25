// lib/Organization/Access/org_invite_banner.dart
//
// "SHIELD invited you to help run their organisation." Shown at the top of the
// member Home for a signed-in user whose email matches an open invite that
// grants access. Accepting runs the server function (it sets the protected
// orgId), then opens the organisation workspace.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Services/storage/user_persistence.dart';
import '../../theme/canopy_components.dart';
import '../Home/org_home.dart';

class OrgInviteBanner extends StatefulWidget {
  const OrgInviteBanner({super.key});

  @override
  State<OrgInviteBanner> createState() => _OrgInviteBannerState();
}

class _OrgInviteBannerState extends State<OrgInviteBanner> {
  bool _busy = false;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream() {
    final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('OrgMembers')
        .where('contact', isEqualTo: email)
        .where('status', isEqualTo: 'invited')
        .snapshots();
  }

  Future<String> _orgName(String orgId) async {
    try {
      final d = (await FirebaseFirestore.instance.collection('organizations').doc(orgId).get()).data();
      return '${d?['org_name'] ?? d?['name'] ?? 'An organisation'}';
    } catch (_) {
      return 'An organisation';
    }
  }

  Future<void> _accept(String inviteId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      // The server only accepts a verified email.
      await user.reload();
      final fresh = FirebaseAuth.instance.currentUser!;
      if (!fresh.emailVerified) {
        await fresh.sendEmailVerification();
        if (mounted) {
          showCanopySnack(context, 'We sent a verification link to ${fresh.email}. Open it, then tap Accept again.');
        }
        return;
      }
      await fresh.getIdToken(true); // pick up email_verified
      await FirebaseFunctions.instance.httpsCallable('acceptOrgInvite').call({'inviteId': inviteId});
      await UserPersistence.refreshUserProfile(fresh.uid);
      if (!mounted) return;
      showCanopySnack(context, 'You can now run this organisation.');
      Navigator.of(context, rootNavigator: true)
          .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const OrganizationHome()), (_) => false);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) showCanopySnack(context, e.message ?? "Couldn't accept. Try again.", error: true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't accept. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(String inviteId) async {
    try {
      await FirebaseFirestore.instance.collection('OrgMembers').doc(inviteId).update({'status': 'declined'});
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't decline. Try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream();
    if (stream == null) return const SizedBox.shrink();
    final p = context.canopy;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final invites = (snap.data?.docs ?? const []).where((d) => d.data()['grantsAccess'] == true).toList();
        if (invites.isEmpty) return const SizedBox.shrink();
        final d = invites.first;
        final role = d.data()['accessRole'] == 'admin' ? 'an admin' : 'an editor';
        return Padding(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s16),
          child: CanopyCard(
            padding: const EdgeInsets.all(CanopySpace.s16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FutureBuilder<String>(
                future: _orgName('${d.data()['orgId']}'),
                builder: (_, n) => Text('${n.data ?? 'An organisation'} invited you',
                    style: CanopyType.subhead.copyWith(color: p.ink)),
              ),
              const SizedBox(height: CanopySpace.s4),
              Text('Join as $role and help run their organisation workspace.',
                  style: CanopyType.body.copyWith(color: p.inkMuted)),
              const SizedBox(height: CanopySpace.s12),
              Row(children: [
                Expanded(child: CanopyButton(label: 'Accept', loading: _busy, onPressed: _busy ? null : () => _accept(d.id))),
                const SizedBox(width: CanopySpace.s8),
                CanopyButton.quiet(label: 'Not now', onPressed: _busy ? null : () => _decline(d.id)),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
