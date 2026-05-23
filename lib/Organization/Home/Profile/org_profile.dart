import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../MarketPlace/market_home.dart';
import '../../../Community/Home/community_home.dart';
import '../../../Services/Authentication/auth.dart';
import '../../../Services/Authentication/community_auth.dart';
import '../../../Shared/Pages/login.dart';
import '../../../Shared/theme/app_theme.dart';
import '../../../Shared/widgets/role_context_switcher.dart';

class OrgProfile extends StatefulWidget {
  const OrgProfile({super.key});

  @override
  State<OrgProfile> createState() => _OrgProfileState();
}

class _OrgProfileState extends State<OrgProfile> {
  final AuthService _authService = AuthService();
  final CommunityAuthService _communityAuthService = CommunityAuthService();
  late Future<Map<String, dynamic>?> _orgDataFuture;
  String? _selectedSellerRole;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _orgDataFuture = _fetchOrgData();
  }

  Future<Map<String, dynamic>?> _fetchOrgData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final firestore = FirebaseFirestore.instance;

      // Get user's organization data from Users collection
      final userDoc =
          await firestore.collection('Users').doc(currentUser.uid).get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final orgId = userData['orgId'] as String?;

      if (orgId == null) return null;

      // Get organization details from organizations collection
      final orgDoc =
          await firestore.collection('organizations').doc(orgId).get();

      if (!orgDoc.exists) return null;

      return orgDoc.data() as Map<String, dynamic>;
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
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _orgDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading organization data',
                style: TextStyle(color: AppTheme.darkGreen),
              ),
            );
          }

          final orgData = snapshot.data;
          final currentUser = FirebaseAuth.instance.currentUser;
          final isOrgRep = currentUser != null &&
              orgData != null &&
              orgData['org_rep_uid'] == currentUser.uid;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(context, orgData),
                const SizedBox(height: 24),
                // ── Role Context Switcher (only for org rep) ────
                if (isOrgRep) ...[
                  _buildRoleContextSwitcher(context, orgData),
                  const SizedBox(height: 24),
                ],
                // ── Marketplace Application Section ────────────
                if (isOrgRep)
                  _buildMarketplaceApplicationSection(context, orgData),
                const SizedBox(height: 24),
                _buildOrganizationInfo(context),
                const SizedBox(height: 24),
                _buildAccountSection(context),
                const SizedBox(height: 16),
                _buildNotificationsSection(context),
                const SizedBox(height: 16),
                _buildSupportSection(context),
                const SizedBox(height: 24),
                _buildSignOutButton(context),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic>? orgData) {
    final orgName = orgData?['org_name'] as String? ?? 'Organization';
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
            child: const Icon(
              Icons.business,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            orgName,
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
                Icon(Icons.verified, color: AppTheme.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Active Organization',
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

  Widget _buildRoleContextSwitcher(
      BuildContext context, Map<String, dynamic>? orgData) {
    final hasMarketplace = orgData?['marketplaceStatus'] == 'approved';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RoleContextSwitcher(
        activeContext: 'org',
        hasMarketplace: hasMarketplace,
        onOrgTap: () {
          // Already on org context, no-op
        },
        onMemberTap: () {
          // Switch to Community context (full shell)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const CommunityHomeScreen(),
            ),
            (route) => false,
          );
        },
        onMarketplaceTap: () {
          // Switch to Marketplace context (full shell)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const SellerHomeScreen(),
            ),
            (route) => false,
          );
        },
      ),
    );
  }

  Widget _buildMarketplaceApplicationSection(
      BuildContext context, Map<String, dynamic>? orgData) {
    final marketplaceStatus =
        orgData?['marketplaceStatus'] as String? ?? 'none';
    final sellerRole = orgData?['sellerRole'] as String?;

    if (marketplaceStatus == 'approved') {
      // Don't show anything for approved
      return const SizedBox.shrink();
    }

    if (marketplaceStatus == 'pending') {
      // Show "under review" status
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Marketplace application under review',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkGreen.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show application card for 'none' or 'rejected'
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.tertiary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.tertiary.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Join the Marketplace',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            // Show rejection banner if needed
            if (marketplaceStatus == 'rejected') ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Previous application was not approved. You may reapply.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Organisations can apply to list materials, processed goods, or artisan products on the Canopy Marketplace. Your verified org identity backs every listing.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.darkGreen.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 16),
            // Role selection chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildRoleChip(
                  label: 'Collector',
                  isSelected: _selectedSellerRole == 'collector',
                  color: AppTheme.primary,
                  onTap: () =>
                      setState(() => _selectedSellerRole = 'collector'),
                ),
                _buildRoleChip(
                  label: 'Processor',
                  isSelected: _selectedSellerRole == 'processor',
                  color: AppTheme.accent,
                  onTap: () =>
                      setState(() => _selectedSellerRole = 'processor'),
                ),
                _buildRoleChip(
                  label: 'Maker / Artisan',
                  isSelected: _selectedSellerRole == 'maker',
                  color: AppTheme.tertiary,
                  onTap: () => setState(() => _selectedSellerRole = 'maker'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Apply button
            FilledButton(
              onPressed: _selectedSellerRole != null && !_isApplying
                  ? () => _applyForMarketplace(orgData)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.tertiary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                disabledBackgroundColor: AppTheme.tertiary.withOpacity(0.5),
              ),
              child: _isApplying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Apply to Sell'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Future<void> _applyForMarketplace(Map<String, dynamic>? orgData) async {
    if (_selectedSellerRole == null || orgData == null) return;

    final orgId = orgData['orgId'] as String?;
    if (orgId == null) return;

    setState(() => _isApplying = true);

    try {
      await _communityAuthService.applyForMarketplaceSeller(
        orgId: orgId,
        sellerRole: _selectedSellerRole!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Application submitted. You\'ll be notified when approved.'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        // Reset the selection
        setState(() => _selectedSellerRole = null);
      }
    } catch (e) {
      debugPrint('Error applying for marketplace: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Error submitting application. Please try again.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Widget _buildOrganizationInfo(BuildContext context) {
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
                  'Organization Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                IconButton(
                  onPressed: () {
                    // TODO: Navigate to edit organization details
                  },
                  icon: Icon(Icons.edit, color: AppTheme.primary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.category,
              label: 'Type',
              value: 'Environmental NGO',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on,
              label: 'Operating Area',
              value: 'Nairobi, Kenya',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Established',
              value: 'January 2020',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.people,
              label: 'Team Size',
              value: '24 Members',
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
                  // TODO: Navigate to account details
                },
              ),
              _SettingsItem(
                icon: Icons.lock,
                title: 'Password and Security',
                onTap: () {
                  // TODO: Navigate to security settings
                },
              ),
              _SettingsItem(
                icon: Icons.location_city,
                title: 'Organization Address',
                onTap: () {
                  // TODO: Navigate to address settings
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
              'Notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.email,
                title: 'Email Notifications',
                onTap: () {
                  // TODO: Navigate to email notification settings
                },
              ),
              _SettingsItem(
                icon: Icons.notifications,
                title: 'Push Notifications',
                onTap: () {
                  // TODO: Navigate to push notification settings
                },
              ),
              _SettingsItem(
                icon: Icons.notifications_off,
                title: 'Manage Preferences',
                onTap: () {
                  // TODO: Navigate to notification preferences
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
                  // TODO: Navigate to help center
                },
              ),
              _SettingsItem(
                icon: Icons.info_outline,
                title: 'About Canopy',
                onTap: () {
                  // TODO: Navigate to about page
                },
              ),
              _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  // TODO: Navigate to privacy policy
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
                  MaterialPageRoute(builder: (context) => LoginPage()),
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    top: index == 0 ? const Radius.circular(16) : Radius.zero,
                    bottom: isLast ? const Radius.circular(16) : Radius.zero,
                  ),
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon,
                              color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.darkGreen,
                                ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppTheme.primary),
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
                    color: AppTheme.lightGreen.withOpacity(0.2),
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
