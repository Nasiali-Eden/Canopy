import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../Shared/theme/app_theme.dart';
import '../../../Shared/widgets/role_context_switcher.dart';
import '../../../Services/Authentication/auth.dart';
import '../../../Shared/Pages/login.dart';
import '../heritage_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CulturalOrgProfilePage
//
//  Displays the cultural archive profile for the logged-in org:
//    1. Org header (gradient banner, logo, name, heritage status, location)
//    2. Stats row (total entries, communities documented, public entries)
//    3. Recent entries section
//    4. Archive settings
//    5. Sign out
//
//  Data sources:
//    - organizations/{orgId}
//    - cultural_entries (aggregated)
// ─────────────────────────────────────────────────────────────────────────────

class CulturalOrgProfilePage extends StatefulWidget {
  final String orgId;
  final WidgetBuilder? orgContextBuilder;
  final WidgetBuilder? memberContextBuilder;
  final WidgetBuilder? envOpsContextBuilder;
  final bool hasEnvOps;

  const CulturalOrgProfilePage({
    required this.orgId,
    this.orgContextBuilder,
    this.memberContextBuilder,
    this.envOpsContextBuilder,
    this.hasEnvOps = false,
    super.key,
  });

  @override
  State<CulturalOrgProfilePage> createState() =>
      _CulturalOrgProfilePageState();
}

class _CulturalOrgProfilePageState extends State<CulturalOrgProfilePage> {
  final _auth = AuthService();

  // ── Warm parchment palette local tokens ──────────────────────────────────
  static const _gold = Color(0xFFC4A961);
  static const _goldDim = Color(0x22C4A961);
  static const _surface = Color(0xFFFDF7F0);
  static const _border = Color(0x1FC4A961);

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .snapshots(),
      builder: (context, orgSnap) {
        final orgData =
            orgSnap.data?.data() as Map<String, dynamic>? ?? {};
        final orgName =
            orgData['organisationName'] as String? ?? 'Cultural Archive';
        final logoUrl = orgData['logoUrl'] as String?;
        final city = orgData['city'] as String? ?? '';
        final area = orgData['area'] as String? ?? '';
        final bio = orgData['background'] as String? ?? '';
        final culturalStatus =
            orgData['culturalStatus'] as String? ?? 'pending';

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cultural_entries')
              .where('org_id', isEqualTo: widget.orgId)
              .snapshots(),
          builder: (context, entriesSnap) {
            final docs = entriesSnap.data?.docs ?? [];
            final totalEntries = docs.length;
            final publicEntries = docs
                .where((d) =>
                    (d.data() as Map<String, dynamic>)['visibility'] ==
                    'public')
                .length;

            // Count distinct communities documented
            final communityIds = docs
                .map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final loc = data['locality'] as Map<String, dynamic>?;
                  return loc?['community_id'] as String?;
                })
                .where((id) => id != null && id.isNotEmpty)
                .toSet();
            final communitiesCount = communityIds.length;

            // Recent 3 entries for preview
            final recentDocs = docs.take(3).toList();

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Context switcher
                  if (widget.orgContextBuilder != null ||
                      widget.memberContextBuilder != null) ...[
                    const SizedBox(height: 12),
                    RoleContextSwitcher(
                      activeContext: 'cultural',
                      hasMarketplace: false,
                      hasEnvOps: widget.hasEnvOps,
                      hasCultural: true,
                      onOrgTap: () {
                        if (widget.orgContextBuilder != null) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: widget.orgContextBuilder!),
                            (_) => false,
                          );
                        }
                      },
                      onMemberTap: () {
                        if (widget.memberContextBuilder != null) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: widget.memberContextBuilder!),
                            (_) => false,
                          );
                        }
                      },
                      onEnvOpsTap: widget.envOpsContextBuilder != null
                          ? () => Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: widget.envOpsContextBuilder!),
                                (_) => false,
                              )
                          : null,
                      onCulturalTap: () {},
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Org Header
                  _buildOrgHeader(
                    orgName: orgName,
                    logoUrl: logoUrl,
                    city: city,
                    area: area,
                    bio: bio,
                    culturalStatus: culturalStatus,
                  ),

                  const SizedBox(height: 20),

                  // Stats
                  _buildStatsRow(
                    totalEntries: totalEntries,
                    communitiesCount: communitiesCount,
                    publicEntries: publicEntries,
                  ),

                  const SizedBox(height: 24),

                  // Recent entries
                  if (recentDocs.isNotEmpty)
                    _buildRecentSection(recentDocs),

                  if (recentDocs.isNotEmpty) const SizedBox(height: 24),

                  // Archive settings
                  _buildSettingsSection(),

                  const SizedBox(height: 24),

                  // Sign out
                  _buildSignOutButton(),

                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Org header card ──────────────────────────────────────────────────────

  Widget _buildOrgHeader({
    required String orgName,
    required String? logoUrl,
    required String city,
    required String area,
    required String bio,
    required String culturalStatus,
  }) {
    final locationText =
        [area, city].where((s) => s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2E0D),
            const Color(0xFF2D5A1E),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo / initials
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withOpacity(0.35)),
                ),
                child: logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _InitialsBox(
                            name: orgName,
                          ),
                        ),
                      )
                    : _InitialsBox(name: orgName),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orgName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Cormorant Garamond',
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusBadge(status: culturalStatus),
                  ],
                ),
              ),
            ],
          ),
          if (locationText.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.location_on,
                    size: 13, color: _gold.withOpacity(0.75)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    locationText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────

  Widget _buildStatsRow({
    required int totalEntries,
    required int communitiesCount,
    required int publicEntries,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Entries',
              value: totalEntries.toString(),
              icon: Icons.archive_outlined,
              color: AppTheme.tertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: 'Communities',
              value: communitiesCount.toString(),
              icon: Icons.people_outline,
              color: _gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: 'Public',
              value: publicEntries.toString(),
              icon: Icons.public_outlined,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent entries ───────────────────────────────────────────────────────

  Widget _buildRecentSection(List<QueryDocumentSnapshot> docs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_outlined, color: _gold, size: 16),
              const SizedBox(width: 8),
              Text(
                'Recent Entries',
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [HeritageTheme.heritageCardShadow],
            ),
            child: Column(
              children: docs.asMap().entries.map((e) {
                final index = e.key;
                final doc = e.value;
                final data = doc.data() as Map<String, dynamic>;
                final isLast = index == docs.length - 1;
                final title = data['title'] as String? ?? 'Untitled';
                final contentType =
                    data['content_type'] as String? ?? '';
                final loc = data['locality'] as Map<String, dynamic>?;
                final community =
                    loc?['community_name'] as String? ?? '';
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _goldDim,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _gold.withOpacity(0.25)),
                            ),
                            child: Center(
                              child: Text(
                                _typeEmoji(contentType),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkGreen,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (community.isNotEmpty)
                                  Text(
                                    community,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.darkGreen
                                          .withOpacity(0.55),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            contentType
                                .replaceAll('_', ' ')
                                .split(' ')
                                .map((w) => w.isEmpty
                                    ? ''
                                    : '${w[0].toUpperCase()}${w.substring(1)}')
                                .join(' '),
                            style: TextStyle(
                              fontSize: 10,
                              color: _gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 64),
                        child: Divider(height: 1, color: _border),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings section ─────────────────────────────────────────────────────

  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Archive Settings',
              style: TextStyle(
                color: AppTheme.darkGreen,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.edit_outlined,
                title: 'Edit Organisation Profile',
                onTap: () => _showComingSoon('Edit org profile'),
              ),
              _SettingsItem(
                icon: Icons.visibility_outlined,
                title: 'Default Entry Visibility',
                onTap: () => _showComingSoon('Default visibility'),
              ),
              _SettingsItem(
                icon: Icons.people_outline,
                title: 'Manage Archive Team',
                onTap: () => _showComingSoon('Archive team'),
              ),
              _SettingsItem(
                icon: Icons.language_outlined,
                title: 'Language Preferences',
                onTap: () => _showComingSoon('Language preferences'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sign out ─────────────────────────────────────────────────────────────

  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OutlinedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Sign out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red[700],
          side: BorderSide(color: Colors.red.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _typeEmoji(String type) {
    const map = {
      'oral_tradition': '📖',
      'food_tradition': '🍳',
      'ingredient': '🌿',
      'music_tradition': '🎵',
      'instrument': '🥁',
      'ceremony': '🕯️',
      'craft_technique': '🛠️',
      'clothing_tradition': '👘',
      'language_entry': '🗣️',
      'place_knowledge': '📍',
      'medicine_knowledge': '🌱',
      'person': '👤',
    };
    return map[type] ?? '📝';
  }
}

// ─── Initials box ─────────────────────────────────────────────────────────────

class _InitialsBox extends StatelessWidget {
  final String name;

  const _InitialsBox({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? 'CA'
        : name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontFamily: 'Cormorant Garamond',
        ),
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'approved':
        bg = const Color(0xFF2D7A4F).withOpacity(0.25);
        fg = const Color(0xFF86E8B0);
        label = 'Verified Archive';
        icon = Icons.verified_outlined;
        break;
      case 'pending':
        bg = const Color(0xFFC4A961).withOpacity(0.2);
        fg = const Color(0xFFC4A961);
        label = 'Pending Review';
        icon = Icons.hourglass_empty_outlined;
        break;
      case 'rejected':
        bg = Colors.red.withOpacity(0.2);
        fg = Colors.red[300]!;
        label = 'Review Required';
        icon = Icons.error_outline;
        break;
      default:
        bg = Colors.white.withOpacity(0.1);
        fg = Colors.white54;
        label = 'Cultural Archive';
        icon = Icons.archive_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

// ─── Stat tile ────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGreen.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Settings card ────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;

  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1FC4A961)),
        boxShadow: [HeritageTheme.heritageCardShadow],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: index == 0
                        ? const Radius.circular(16)
                        : Radius.zero,
                    bottom: isLast
                        ? const Radius.circular(16)
                        : Radius.zero,
                  ),
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC4A961).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon,
                              color: const Color(0xFF8B6914), size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.darkGreen,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: const Color(0xFFC4A961).withOpacity(0.6)),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 62),
                  child: Divider(
                    height: 1,
                    color: const Color(0x1FC4A961),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
