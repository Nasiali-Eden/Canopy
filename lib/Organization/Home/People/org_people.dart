import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum MemberRole { admin, coordinator, member, observer }

enum MemberStatus { active, inactive, pending }

extension MemberRoleX on MemberRole {
  String get label {
    switch (this) {
      case MemberRole.admin:
        return 'Admin';
      case MemberRole.coordinator:
        return 'Coordinator';
      case MemberRole.member:
        return 'Member';
      case MemberRole.observer:
        return 'Observer';
    }
  }

  Color get color {
    switch (this) {
      case MemberRole.admin:
        return AppTheme.darkGreen;
      case MemberRole.coordinator:
        return AppTheme.primary;
      case MemberRole.member:
        return AppTheme.accent;
      case MemberRole.observer:
        return AppTheme.lightGreen;
    }
  }

  IconData get icon {
    switch (this) {
      case MemberRole.admin:
        return Icons.shield_outlined;
      case MemberRole.coordinator:
        return Icons.manage_accounts_outlined;
      case MemberRole.member:
        return Icons.person_outlined;
      case MemberRole.observer:
        return Icons.visibility_outlined;
    }
  }
}

extension MemberStatusX on MemberStatus {
  String get label {
    switch (this) {
      case MemberStatus.active:
        return 'Active';
      case MemberStatus.inactive:
        return 'Inactive';
      case MemberStatus.pending:
        return 'Pending';
    }
  }

  Color get color {
    switch (this) {
      case MemberStatus.active:
        return const Color(0xFF2E7D32);
      case MemberStatus.inactive:
        return Colors.grey;
      case MemberStatus.pending:
        return const Color(0xFFE65100);
    }
  }
}

MemberRole _roleFromString(String? s) {
  switch (s) {
    case 'admin':
      return MemberRole.admin;
    case 'coordinator':
      return MemberRole.coordinator;
    case 'observer':
      return MemberRole.observer;
    default:
      return MemberRole.member;
  }
}

MemberStatus _statusFromString(String? s) {
  switch (s) {
    case 'inactive':
      return MemberStatus.inactive;
    case 'pending':
      return MemberStatus.pending;
    default:
      return MemberStatus.active;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class OrgPeopleScreen extends StatefulWidget {
  const OrgPeopleScreen({super.key});

  @override
  State<OrgPeopleScreen> createState() => _OrgPeopleScreenState();
}

class _OrgPeopleScreenState extends State<OrgPeopleScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _orgId;
  bool _orgIdLoaded = false;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrgId();
  }

  Future<void> _loadOrgId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _orgIdLoaded = true);
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final orgId = doc.exists
          ? (doc.data() as Map<String, dynamic>)['orgId'] as String?
          : null;
      setState(() {
        _orgId = orgId;
        _orgIdLoaded = true;
      });
    } catch (e) {
      debugPrint('OrgPeople._loadOrgId error: $e');
      if (mounted) setState(() => _orgIdLoaded = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_orgIdLoaded) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_orgId == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('No organisation linked to this account.')),
      );
    }
    final orgId = _orgId!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 68,
        centerTitle: true,
        title: Text(
          'Canopy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_outlined, color: AppTheme.primary),
            tooltip: 'Invite member',
            onPressed: () => _showInviteMemberSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(context),
          _buildCapacityCard(context, orgId),
          const SizedBox(height: 16),
          _buildTabBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TeamsTab(orgId: orgId, firestore: _firestore),
                _MembersTab(orgId: orgId, firestore: _firestore),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final isTeamsTab = _tabController.index == 0;
            return FloatingActionButton.extended(
              onPressed: isTeamsTab
                  ? () => _showCreateTeamSheet(context)
                  : () => _showInviteMemberSheet(context),
              backgroundColor: AppTheme.primary,
              icon: Icon(
                isTeamsTab ? Icons.add : Icons.person_add_outlined,
                color: Colors.white,
              ),
              label: Text(
                isTeamsTab ? 'New Team' : 'Invite',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Page header ──────────────────────────────

  Widget _buildPageHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'People',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your teams, members, and roles',
            style: TextStyle(
              color: AppTheme.darkGreen.withOpacity(0.55),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Capacity card ────────────────────────────

  Widget _buildCapacityCard(BuildContext context, String orgId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('organizations').doc(orgId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final total = data['totalMembers'] as int? ?? 0;
        final active = data['activeMembers'] as int? ?? 0;
        final pending = data['pendingMembers'] as int? ?? 0;
        final inactive = (total - active - pending).clamp(0, total);
        final pct = total > 0 ? active / total : 0.0;

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.darkGreen, AppTheme.primary],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkGreen.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _CapacityStat(
                        icon: Icons.people_rounded,
                        value: total.toString(),
                        label: 'Total'),
                  ),
                  _vDivider(),
                  Expanded(
                    child: _CapacityStat(
                        icon: Icons.check_circle_outline,
                        value: active.toString(),
                        label: 'Active'),
                  ),
                  _vDivider(),
                  Expanded(
                    child: _CapacityStat(
                        icon: Icons.schedule_outlined,
                        value: pending.toString(),
                        label: 'Pending',
                        valueColor: AppTheme.tertiary),
                  ),
                  _vDivider(),
                  Expanded(
                    child: _CapacityStat(
                        icon: Icons.person_off_outlined,
                        value: inactive.toString(),
                        label: 'Inactive',
                        valueColor: Colors.white54),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showUpdateCapacityDialog(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.tertiary),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}% of capacity active',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.white.withOpacity(0.2),
      );

  // ── Custom tab bar ───────────────────────────

  Widget _buildTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.lightGreen.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.55),
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Teams'),
            Tab(text: 'Members'),
          ],
        ),
      ),
    );
  }

  // ── Dialogs / sheets ────────────────────────

  void _showCreateTeamSheet(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const SizedBox(height: 16),
            Text('Create Team',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _StyledTextField(
              controller: nameController,
              label: 'Team name',
              hint: 'e.g. Cleanup Crew North',
              icon: Icons.groups_outlined,
            ),
            const SizedBox(height: 14),
            _StyledTextField(
              controller: descController,
              label: 'Description (optional)',
              hint: 'What does this team do?',
              icon: Icons.notes_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    _firestore.collection('Teams').add({
                      'orgId': _orgId ?? '',
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                      'memberCount': 0,
                      'memberIds': [],
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(ctx);
                  }
                },
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Create Team',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteMemberSheet(BuildContext context) {
    final emailController = TextEditingController();
    MemberRole selectedRole = MemberRole.member;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              const SizedBox(height: 16),
              Text('Invite Member',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('They\'ll receive a Canopy app notification.',
                  style: TextStyle(
                      color: AppTheme.darkGreen.withOpacity(0.55),
                      fontSize: 13)),
              const SizedBox(height: 20),
              _StyledTextField(
                controller: emailController,
                label: 'Email or phone number',
                hint: '+254 7xx xxx xxx',
                icon: Icons.person_search_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              Text('Role',
                  style: TextStyle(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: MemberRole.values.map((role) {
                  final selected = role == selectedRole;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedRole = role),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? role.color.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? role.color
                              : AppTheme.lightGreen.withOpacity(0.4),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(role.icon,
                              size: 14,
                              color: selected
                                  ? role.color
                                  : AppTheme.darkGreen.withOpacity(0.5)),
                          const SizedBox(width: 5),
                          Text(role.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? role.color
                                    : AppTheme.darkGreen.withOpacity(0.6),
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // TODO: Send invite via Firebase + notification
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Invitation sent'),
                      backgroundColor: AppTheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Send Invitation',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateCapacityDialog(BuildContext context) {
    final totalController = TextEditingController();
    final activeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update Capacity',
            style: TextStyle(
                color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StyledTextField(
              controller: totalController,
              label: 'Total members',
              icon: Icons.people_outline,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            _StyledTextField(
              controller: activeController,
              label: 'Active members',
              icon: Icons.check_circle_outline,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.darkGreen)),
          ),
          FilledButton(
            onPressed: () {
              final total = int.tryParse(totalController.text) ?? 0;
              final active = int.tryParse(activeController.text) ?? 0;
              _firestore.collection('organizations').doc(_orgId ?? '').set(
                  {'totalMembers': total, 'activeMembers': active},
                  SetOptions(merge: true));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAMS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _TeamsTab extends StatelessWidget {
  final String orgId;
  final FirebaseFirestore firestore;

  const _TeamsTab({required this.orgId, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('Teams')
          .where('orgId', isEqualTo: orgId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final teams = snapshot.data?.docs ?? [];

        if (teams.isEmpty) {
          return _EmptyState(
            icon: Icons.groups_2_outlined,
            title: 'No teams yet',
            subtitle: 'Create teams to organise your members and assign roles.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          itemCount: teams.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final data = teams[i].data() as Map<String, dynamic>;
            return _TeamCard(
              teamId: teams[i].id,
              data: data,
              firestore: firestore,
            );
          },
        );
      },
    );
  }
}

class _TeamCard extends StatelessWidget {
  final String teamId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;

  const _TeamCard({
    required this.teamId,
    required this.data,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Team';
    final description = data['description'] as String? ?? '';
    final memberCount = data['memberCount'] as int? ?? 0;
    final memberIds = (data['memberIds'] as List?)?.cast<String>() ?? [];

    // Show up to 4 avatar slots
    final previewIds = memberIds.take(4).toList();
    final overflow = memberCount - previewIds.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTeamDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.groups_rounded,
                          color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                color: AppTheme.darkGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              )),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.darkGreen.withOpacity(0.5),
                                  fontSize: 12,
                                )),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: AppTheme.darkGreen.withOpacity(0.5)),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'edit')
                          _showEditTeamSheet(context);
                        else if (v == 'delete') _confirmDelete(context);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_outlined,
                                size: 16, color: AppTheme.primary),
                            const SizedBox(width: 10),
                            const Text('Edit team'),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            const Icon(Icons.delete_outline,
                                size: 16, color: Colors.red),
                            const SizedBox(width: 10),
                            const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
                if (memberCount > 0) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Stacked avatar previews
                      SizedBox(
                        width: previewIds.length * 22.0 +
                            (previewIds.isEmpty ? 0 : 10),
                        height: 28,
                        child: Stack(
                          children: [
                            for (int i = 0; i < previewIds.length; i++)
                              Positioned(
                                left: i * 22.0,
                                child: _MiniAvatar(userId: previewIds[i]),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        overflow > 0
                            ? '$memberCount members (+$overflow more)'
                            : '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                        style: TextStyle(
                          color: AppTheme.darkGreen.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showAddMemberToTeamSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_add_outlined,
                                  size: 13, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text('Add',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTeamDetail(BuildContext context) {
    // TODO: Navigate to team detail screen
  }

  void _showEditTeamSheet(BuildContext context) {
    final nameController =
        TextEditingController(text: data['name'] as String? ?? '');
    final descController =
        TextEditingController(text: data['description'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const SizedBox(height: 16),
            Text('Edit Team',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _StyledTextField(
              controller: nameController,
              label: 'Team name',
              icon: Icons.groups_outlined,
            ),
            const SizedBox(height: 14),
            _StyledTextField(
              controller: descController,
              label: 'Description',
              icon: Icons.notes_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  firestore.collection('Teams').doc(teamId).update({
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                  });
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Save Changes',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberToTeamSheet(BuildContext context) {
    // TODO: Show member picker to add to this team
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Team',
            style: TextStyle(
                color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
        content: Text('This will permanently delete "${data['name']}". '
            'Members won\'t be removed from the organisation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.darkGreen)),
          ),
          FilledButton(
            onPressed: () {
              firestore.collection('Teams').doc(teamId).delete();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEMBERS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _MembersTab extends StatefulWidget {
  final String orgId;
  final FirebaseFirestore firestore;

  const _MembersTab({required this.orgId, required this.firestore});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  MemberRole? _filterRole;

  @override
  Widget build(BuildContext context) {
    Query query = widget.firestore
        .collection('OrgMembers')
        .where('orgId', isEqualTo: widget.orgId);

    if (_filterRole != null) {
      query = query.where('role', isEqualTo: _filterRole!.name);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role filter chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            children: [
              _FilterChip(
                label: 'All',
                selected: _filterRole == null,
                onTap: () => setState(() => _filterRole = null),
              ),
              const SizedBox(width: 8),
              ...MemberRole.values.map((role) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: role.label,
                      selected: _filterRole == role,
                      color: role.color,
                      onTap: () => setState(() =>
                          _filterRole = _filterRole == role ? null : role),
                    ),
                  )),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child: CircularProgressIndicator(color: AppTheme.primary));
              }

              final members = snapshot.data?.docs ?? [];

              if (members.isEmpty) {
                return _EmptyState(
                  icon: Icons.person_outlined,
                  title: _filterRole != null
                      ? 'No ${_filterRole!.label.toLowerCase()}s yet'
                      : 'No members yet',
                  subtitle: 'Invite people to join your organisation.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final data = members[i].data() as Map<String, dynamic>;
                  return _MemberCard(
                    memberId: members[i].id,
                    data: data,
                    firestore: widget.firestore,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final String memberId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;

  const _MemberCard({
    required this.memberId,
    required this.data,
    required this.firestore,
  });

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final words = name.trim().split(' ');
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words[0][0] + words.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Unknown';
    final role = _roleFromString(data['role'] as String?);
    final status = _statusFromString(data['status'] as String?);
    final area = data['area'] as String? ?? '';
    final joinDate = data['joinedAt'] as Timestamp?;
    final avatarUrl = data['avatarUrl'] as String?;
    final eventsAttended = data['eventsAttended'] as int? ?? 0;

    final initials = _getInitials(name);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // TODO: Navigate to member profile
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: role.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: avatarUrl != null
                      ? ClipOval(
                          child: Image.network(avatarUrl, fit: BoxFit.cover))
                      : Center(
                          child: Text(initials,
                              style: TextStyle(
                                color: role.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                                style: TextStyle(
                                  color: AppTheme.darkGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                )),
                          ),
                          const SizedBox(width: 6),
                          _RoleBadge(role: role),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          // Status dot
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: status.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(status.label,
                              style: TextStyle(
                                color: status.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                          if (area.isNotEmpty) ...[
                            Text(' · ',
                                style: TextStyle(
                                    color:
                                        AppTheme.darkGreen.withOpacity(0.3))),
                            Text(area,
                                style: TextStyle(
                                  color: AppTheme.darkGreen.withOpacity(0.5),
                                  fontSize: 11,
                                )),
                          ],
                          if (eventsAttended > 0) ...[
                            const Spacer(),
                            Icon(Icons.event_available,
                                size: 12,
                                color: AppTheme.darkGreen.withOpacity(0.4)),
                            const SizedBox(width: 3),
                            Text('$eventsAttended events',
                                style: TextStyle(
                                  color: AppTheme.darkGreen.withOpacity(0.5),
                                  fontSize: 11,
                                )),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: AppTheme.darkGreen.withOpacity(0.4), size: 20),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'change_role')
                      _showChangeRoleSheet(context, role);
                    else if (v == 'remove') _confirmRemove(context, name);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'change_role',
                      child: Row(children: [
                        Icon(Icons.manage_accounts_outlined,
                            size: 16, color: AppTheme.primary),
                        const SizedBox(width: 10),
                        const Text('Change role'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(children: [
                        const Icon(Icons.person_remove_outlined,
                            size: 16, color: Colors.red),
                        const SizedBox(width: 10),
                        const Text('Remove',
                            style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangeRoleSheet(BuildContext context, MemberRole current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const SizedBox(height: 16),
            Text('Change Role',
                style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            const SizedBox(height: 16),
            ...MemberRole.values.map((role) {
              final isCurrent = role == current;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: role.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(role.icon, color: role.color, size: 20),
                ),
                title: Text(role.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGreen)),
                trailing: isCurrent
                    ? Icon(Icons.check_circle, color: AppTheme.primary)
                    : null,
                onTap: () {
                  firestore
                      .collection('OrgMembers')
                      .doc(memberId)
                      .update({'role': role.name});
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Member',
            style: TextStyle(
                color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
        content: Text(
            'Remove $name from your organisation? Their activity history will be preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.darkGreen)),
          ),
          FilledButton(
            onPressed: () {
              firestore.collection('OrgMembers').doc(memberId).delete();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _CapacityStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;

  const _CapacityStat({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 5),
        Text(value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            )),
        Text(label,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final MemberRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: role.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(role.label,
          style: TextStyle(
            color: role.color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String userId;
  const _MiniAvatar({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(Icons.person, size: 14, color: AppTheme.darkGreen),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : AppTheme.lightGreen.withOpacity(0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? c : AppTheme.darkGreen.withOpacity(0.55),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppTheme.lightGreen),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                )),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.darkGreen.withOpacity(0.55),
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.lightGreen.withOpacity(0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        labelStyle: TextStyle(color: AppTheme.darkGreen.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.lightGreen.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
