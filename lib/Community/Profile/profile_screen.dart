import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Culture/culture_home.dart';
import '../../EnvironmentalOps/env_ops_shell.dart';
import '../../Features/marketplace/marketplace_seller_stub.dart';
import '../../MarketPlace/market_home.dart';
import '../../Organization/Home/org_home.dart';
import '../../Models/user.dart';
import '../../Organization/Home/Profile/org_profile.dart';
import '../../Services/Authentication/auth.dart';
import '../../Services/Authentication/community_auth.dart';
import '../../Services/Impact/impact_service.dart';
import '../../Services/Profile/profile_service.dart';
import '../../Shared/Pages/login.dart';
import '../../Shared/theme/app_theme.dart';
import '../../Shared/widgets/role_context_switcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  late Future<Map<String, dynamic>?> _userDataFuture;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userDataFuture = _fetchUserData(currentUser.uid);
    }
  }

  Future<Map<String, dynamic>?> _fetchUserData(String uid) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('Users').doc(uid).get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchOrgData(String orgId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final orgDoc =
          await firestore.collection('organizations').doc(orgId).get();
      if (orgDoc.exists) {
        return orgDoc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching org data: $e');
      return null;
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final trimmed = name.trim();
    final words = trimmed.split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    return (words[0][0] + words[words.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);

    // Guard against null user during sign-out (auth stream fires null
    // before the Navigator.pushReplacement completes).
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _userDataFuture,
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data;
        final userRole = userData?['role'] as String?;
        final isOrgRep = userRole == 'Org Rep';
        final orgId = userData?['orgId'] as String?;

        return StreamBuilder<ProfileData>(
          stream: ProfileService().watchProfile(userId: user.uid),
          builder: (context, snapshot) {
            final profile = snapshot.data;

            return Scaffold(
              backgroundColor: Colors.white,
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(context, profile),
                    const SizedBox(height: 24),
                    // ── Role Context Switcher (only for org rep) ────
                    if (isOrgRep && orgId != null)
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _fetchOrgData(orgId),
                        builder: (context, orgSnapshot) {
                          final orgData = orgSnapshot.data;
                          final hasMarketplace =
                              orgData?['marketplaceStatus'] == 'approved';
                          final hasEnvOps =
                              orgData?['envOpsStatus'] == 'approved';
                          final hasCultural =
                              orgData?['culturalStatus'] == 'approved';

                          return Column(
                            children: [
                              _buildMemberRoleContextSwitcher(
                                context,
                                hasMarketplace: hasMarketplace,
                                hasEnvOps: hasEnvOps,
                                hasCultural: hasCultural,
                                orgId: orgId,
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),
                    _buildImpactStats(context, user.uid),
                    const SizedBox(height: 24),
                    _buildPersonalInfo(context, profile),
                    const SizedBox(height: 24),
                    _buildAccountSection(context),
                    const SizedBox(height: 16),
                    _buildNotificationsSection(context),
                    const SizedBox(height: 16),
                    _buildImpactSection(context, user.uid),
                    const SizedBox(height: 16),
                    _buildRecognitionSection(context),
                    const SizedBox(height: 16),
                    _buildSupportSection(context),
                    const SizedBox(height: 24),
                    _buildSignOutButton(context),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMemberRoleContextSwitcher(
    BuildContext context, {
    required bool hasMarketplace,
    required bool hasEnvOps,
    required bool hasCultural,
    required String orgId,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RoleContextSwitcher(
        activeContext: 'member',
        hasMarketplace: hasMarketplace,
        hasEnvOps: hasEnvOps,
        hasCultural: hasCultural,
        onOrgTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const OrganizationHome()),
            (route) => false,
          );
        },
        onMemberTap: () {},
        onMarketplaceTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SellerHomeScreen()),
            (route) => false,
          );
        },
        onEnvOpsTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const EnvOpsShell()),
            (route) => false,
          );
        },
        onCulturalTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => CultureHomeScreen(orgId: orgId)),
            (route) => false,
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProfileData? profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primary, AppTheme.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child:
                (profile?.photoUrl == null || (profile?.photoUrl ?? '').isEmpty)
                    ? Center(
                        child: Text(
                          _getInitials(profile?.name),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: CachedNetworkImage(
                          imageUrl: profile!.photoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 16),
          Text(
            (profile?.name ?? '').isEmpty ? 'Community Member' : profile!.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, color: AppTheme.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Active Member',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactStats(BuildContext context, String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final points = (d['totalPoints'] ?? 0).toString();
        final contributions = (d['contributions'] ?? 0).toString();
        final rank = (d['rank'] ?? '-').toString();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _ImpactTile(
                  label: 'Impact Points',
                  value: points,
                  icon: Icons.bolt_outlined,
                  color: AppTheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ImpactTile(
                  label: 'Contributions',
                  value: contributions,
                  icon: Icons.volunteer_activism_outlined,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ImpactTile(
                  label: 'Rank',
                  value: rank == '-' ? '-' : '#$rank',
                  icon: Icons.emoji_events_outlined,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalInfo(BuildContext context, ProfileData? profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Personal Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                  icon: Icon(Icons.edit, color: AppTheme.primary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.person,
              label: 'Name',
              value: (profile?.name ?? '').isEmpty ? 'Not set' : profile!.name,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on,
              label: 'Location',
              value: (profile?.location ?? '').isEmpty
                  ? 'Location not set'
                  : profile!.location,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Account Management',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.account_circle,
                title: 'Account Details',
                onTap: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              _SettingsItem(
                icon: Icons.lock,
                title: 'Password and Security',
                onTap: () {
                  Navigator.pushNamed(context, '/security');
                },
              ),
              _SettingsItem(
                icon: Icons.notifications,
                title: 'Notification Settings',
                onTap: () {
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Stay Updated',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.campaign_outlined,
                title: 'Announcements',
                onTap: () {
                  Navigator.pushNamed(context, '/announcements');
                },
              ),
              _SettingsItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () {
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactSection(BuildContext context, String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Your Impact',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.bolt_outlined,
                title: 'Impact Points',
                onTap: () {
                  Navigator.pushNamed(context, '/impact');
                },
              ),
              _SettingsItem(
                icon: Icons.emoji_events_outlined,
                title: 'Badges',
                onTap: () {
                  Navigator.pushNamed(context, '/recognition/badges');
                },
              ),
              _SettingsItem(
                icon: Icons.favorite_outline,
                title: 'Acknowledgements',
                onTap: () {
                  Navigator.pushNamed(context, '/recognition/acknowledgements');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Recognition',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.star_outline,
                title: 'My Achievements',
                onTap: () {
                  Navigator.pushNamed(context, '/achievements');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Support & Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () {
                  Navigator.pushNamed(context, '/help');
                },
              ),
              _SettingsItem(
                icon: Icons.info_outline,
                title: 'About Canopy',
                onTap: () {
                  Navigator.pushNamed(context, '/about');
                },
              ),
              _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  Navigator.pushNamed(context, '/privacy');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final shouldSignOut = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  content: Text(
                    'Are you sure you want to sign out?',
                    style: TextStyle(color: AppTheme.darkGreen),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppTheme.darkGreen),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (shouldSignOut == true) {
                await _authService.signOut();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.logout, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Sign Out',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.red),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGreen,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;

  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          return Column(
            children: [
              if (entry.key > 0)
                Divider(
                  height: 1,
                  indent: 56,
                  color: AppTheme.darkGreen.withOpacity(0.08),
                ),
              _SettingsItemContent(item: entry.value),
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

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class _SettingsItemContent extends StatelessWidget {
  final _SettingsItem item;

  const _SettingsItemContent({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGreen,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.darkGreen.withOpacity(0.4),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImpactTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ImpactTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGreen.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }
}
